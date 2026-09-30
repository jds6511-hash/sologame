## 지역/저장 통합 검사. 준비 의뢰/레벨과 목표 이벤트는 fixture이며 실제 처치 증거가 아니다.
extends SceneTree
const ENV_PATH := "res://scripts/chapter_two_closure/closure_environment.gd"
const RegionsM7 = preload("res://scripts/chapter_two_closure/closure_regions.gd")
const DIRECTORY := "user://m7_closure_candidate_process"
var world: Node
var failed := false
var finished := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print(label, ": ", value)
	failed = failed or not value


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "seed", "reload", "reload_mid"]:
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(DIRECTORY):
			for file in DirAccess.get_files_at(DIRECTORY):
				check(DirAccess.remove_absolute(DIRECTORY.path_join(file)) == OK, "격리 파일 정리")
		finished = true
	else:
		world = load(ENV_PATH).instantiate_world("novera_gate")
		world.set_meta("save_directory", DIRECTORY)
		root.add_child(world)
		current_scene = world
		await process_frame
		await process_frame
		if args[0] in ["reload", "reload_mid"]:
			check(
				world.get_node("SaveSession").load_slot(2 if args[0] == "reload_mid" else 1).ok,
				"별도 프로세스 V7 로드"
			)
			await refresh()
			var expected = JSON.parse_string(
				FileAccess.get_file_as_string(
					DIRECTORY.path_join(
						"middle.json" if args[0] == "reload_mid" else "expected.json"
					)
				)
			)
			check(
				expected == JSON.parse_string(JSON.stringify(snapshot(), "", false, true)),
				"지역·좌표·가방·장비·의뢰 전체 스냅샷 일치"
			)
			if failed:
				print("기대: ", expected, " 실제: ", snapshot())
			finished = true
		else:
			await seed_session()
	check(finished, "최종 검사 도달")
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("M7_CLOSURE_CANDIDATE_FAIL" if failed else "M7_CLOSURE_CANDIDATE_PASS")
	quit(1 if failed else 0)


func refresh() -> void:
	await process_frame
	await process_frame
	for child in root.get_children():
		if child.has_node("SaveSession") and not child.is_queued_for_deletion():
			world = child
			current_scene = world


func snapshot() -> Dictionary:
	var session = world.get_node("SaveSession")
	var data: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	# 저장 시 갱신되는 ID/시각은 제외하고 게임 상태 전체를 비교한다.
	data.world.erase("elapsed_real_sec_in_day")  # 복원 뒤 실제 프레임만큼 흐르는 시계는 동일성 비교 제외.
	return {
		"player": data.player,
		"inventory": data.inventory,
		"world": data.world,
		"progress": data.progress
	}


func travel(destination: String) -> void:
	var selected: String = world.get_node("QuestController").journal.catalog.selected_quest_id
	var journal = world.get_node("QuestController").journal
	if selected not in journal.catalog.available_ids(journal.export_state()):
		selected = ""
	var edge := RegionsM7.edge(world.map_id, destination)
	world.get_node("Player").position = edge[2]  # 관문 API 검사 준비 위치. 도보 증거 아님.
	var result: Dictionary = world.get_node("SaveSession").travel(destination)
	check(result.ok, "관문 교체 " + destination + " / " + result.code)
	await refresh()
	check(world.map_id == destination, "도착 지역")
	if selected != "":
		check(
			world.get_node("QuestController").journal.catalog.selected_quest_id == selected,
			"지역 교체 후 선택 의뢰 유지"
		)
	check(world.get_node("Player").position.distance_to(edge[3]) < 1, "출입구별 도착 위치")
	check(world.get_node("SaveSession").store.root == DIRECTORY, "교체 후 저장 격리")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			"res://../docs/qa/screenshots/m7-closure-" + destination + ".png"
		)


func seed_session() -> void:
	var journal = world.get_node("QuestController").journal
	var preparation := {}
	for id in QuestCatalog.ORDER:
		preparation[id] = {
			"state": "completed", "counts": Array(journal.catalog.definitions[id].objective_counts)
		}
	check(journal.restore_state(preparation) == "", "1장 완료 준비 fixture")
	world.get_node("Player/PlayerProgression").add_exp(3820)
	await travel("novera_commons")
	var token := 0
	for id in journal.catalog.ordered_ids():
		if id in QuestCatalog.ORDER:
			continue
		var controller = world.get_node("QuestController")
		journal = controller.journal
		check(journal.accept(id) == "", "순차 수락 fixture " + id)
		var definition: QuestData = journal.catalog.definitions[id]
		if id == "MQ-02-05":
			check(journal.catalog.select_quest(id, journal.export_state()), "지역 이동 전 의뢰 선택")
			await travel("novera_outskirts")
			await travel("novera_rift")
			controller = world.get_node("QuestController")
			journal = controller.journal
		for index in definition.objective_counts.size():
			for count in definition.objective_counts[index]:
				token += 1
				journal.record_event(
					definition.objective_kinds[index],
					definition.objective_targets[index],
					definition.objective_sources[index],
					token
				)
			if id == "MQ-02-05" and index == 0:
				# 던전 안전 입구에서 부분 진행을 저장. 이벤트는 명시적 API fixture다.
				await save_snapshot(2, "middle.json")
		if world.map_id == "novera_rift":
			await travel("novera_outskirts")
			await travel("novera_commons")
			controller = world.get_node("QuestController")
			journal = controller.journal
		var gold: int = world.get_node("Player/Inventory").gold
		check(controller.report(id, definition.npc_id) == "", "보고/보상 " + id)
		check(world.get_node("Player/Inventory").gold == gold + definition.reward_gold, "골드 단회 지급")
		check(controller.report(id, definition.npc_id) != "", "중복 보고 거부")
		check(world.get_node("Player/Inventory").gold == gold + definition.reward_gold, "중복 보상 없음")
	check(journal.reputation() == 600, "누적 공훈600")
	# 새 지역의 완료 상태도 별도 프로세스에서 복원한다.
	await travel("novera_outskirts")
	await travel("novera_rift")
	await save_snapshot(1, "expected.json")
	finished = true


func save_snapshot(slot: int, name: String) -> void:
	await create_timer(6).timeout
	var saved: Dictionary = world.get_node("SaveSession").save_slot(slot)
	check(saved.ok, "실제 V7 파일 저장 / " + saved.code)
	var file := FileAccess.open(DIRECTORY.path_join(name), FileAccess.WRITE)
	if file == null:
		check(false, "스냅샷 파일 열기")
		return
	file.store_string(JSON.stringify(snapshot(), "", false, true))
	file.close()
