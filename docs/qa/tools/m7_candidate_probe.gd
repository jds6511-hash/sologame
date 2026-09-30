## 지역/저장 통합 검사. 준비 의뢰/레벨과 목표 이벤트는 fixture이며 실제 처치 증거가 아니다.
extends SceneTree
const ENV_PATH := "res://scripts/chapter_two/m7_environment.gd"
const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")
const DIRECTORY := "user://m7_candidate_process"
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
	if args.size() != 1 or args[0] not in ["cleanup", "seed", "reload"]:
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
		if args[0] == "reload":
			check(world.get_node("SaveSession").load_slot(1).ok, "별도 프로세스 V6 로드")
			await refresh()
			var expected = JSON.parse_string(
				FileAccess.get_file_as_string(DIRECTORY.path_join("expected.json"))
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
	print("M7_CANDIDATE_FAIL" if failed else "M7_CANDIDATE_PASS")
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
	var edge := RegionsM7.edge(world.map_id, destination)
	world.get_node("Player").position = edge[2]  # 관문 API 검사 준비 위치. 도보 증거 아님.
	var result: Dictionary = world.get_node("SaveSession").travel(destination)
	check(result.ok, "관문 교체 " + destination + " / " + result.code)
	await refresh()
	check(world.map_id == destination, "도착 지역")
	check(world.get_node("Player").position.distance_to(edge[3]) < 1, "출입구별 도착 위치")
	check(world.get_node("SaveSession").store.root == DIRECTORY, "교체 후 저장 격리")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			"res://../docs/qa/screenshots/m7-" + destination + ".png"
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
	await travel("novera_outskirts")
	await travel("novera_commons")
	await travel("novera_gate")
	await travel("eastern_frontier_start")
	await create_timer(0.5).timeout
	await travel("novera_gate")
	await travel("novera_commons")
	var controller = world.get_node("QuestController")
	journal = controller.journal
	var token := 0
	for id in journal.catalog.NEW_IDS:
		check(journal.accept(id) == "", "순차 수락 " + id)
		var definition: QuestData = journal.catalog.definitions[id]
		for index in definition.objective_counts.size():
			for count in definition.objective_counts[index]:
				token += 1
				journal.record_event(
					definition.objective_kinds[index],
					definition.objective_targets[index],
					definition.objective_sources[index],
					token
				)
		check(controller.report(id, "novera_receptionist") == "", "보고/보상 " + id)
	check(world.get_node("Player/PlayerProgression").current_level == 10, "보고 하한 Lv10")
	var player = world.get_node("Player")
	player.position = Vector2(416, 416)
	var economy = player.get_meta("economy_candidate")
	check(economy.act("buy", "POT-HP-1", "", 2) == "", "새 거점 실제 상인 복수 구매")
	await create_timer(6).timeout
	var saved: Dictionary = world.get_node("SaveSession").save_slot(1)
	check(saved.ok, "실제 V6 파일 저장 / " + saved.code)
	var file := FileAccess.open(DIRECTORY.path_join("expected.json"), FileAccess.WRITE)
	if file == null:
		check(false, "스냅샷 파일 열기")
		return
	file.store_string(JSON.stringify(snapshot(), "", false, true))
	file.close()
	finished = true
