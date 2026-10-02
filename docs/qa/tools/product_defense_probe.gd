## 3장 API 결합 검사. 2장 완료·좌표·피해량은 fixture이며 정상 조작/전투 체감 증거가 아니다.
extends SceneTree
const ENV_PATH := "res://scripts/world/game_product.gd"
const RegionsM7 = preload("res://scripts/content/game_content.gd")
const DIRECTORY := "user://product_defense_probe"
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
		world = load(ENV_PATH).instantiate_world("novera_commons")
		world.set_meta("save_directory", DIRECTORY)
		root.add_child(world)
		current_scene = world
		await process_frame
		await process_frame
		if args[0] in ["reload", "reload_mid"]:
			check(
				world.get_node("SaveSession").load_slot(2 if args[0] == "reload_mid" else 1).ok,
				"별도 프로세스 제품 V6 로드"
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
	print("PRODUCT_DEFENSE_FAIL" if failed else "PRODUCT_DEFENSE_PASS")
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
		"character_save_version": data.character_save_version,
		"content_revision": data.content_revision,
		"player": data.player,
		"inventory": data.inventory,
		"world": data.world,
		"progress": data.progress
	}


func travel(destination: String) -> void:
	var selected: String = world.get_node("QuestController").journal.get_meta(
		"selected_quest_id", ""
	)
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
			world.get_node("QuestController").journal.get_meta("selected_quest_id", "") == selected,
			"지역 교체 후 선택 의뢰 유지"
		)
	check(world.get_node("Player").position.distance_to(edge[3]) < 1, "출입구별 도착 위치")
	check(world.get_node("SaveSession").store.root == DIRECTORY, "교체 후 저장 격리")
	check(world.get_node("SaveSession").codec.character_version() == 6, "제품 형식6 유지")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			"res://../docs/qa/screenshots/m7-closure-" + destination + ".png"
		)


func seed_session() -> void:
	var journal: QuestJournal = world.get_node("QuestController").journal
	var bootstrap = load("res://scripts/world/game_bootstrap.gd").new()
	var prepared: Dictionary = bootstrap.preparation(journal.catalog, 3)
	bootstrap.free()
	check(journal.restore_state(prepared.quests) == "", "2장 완료 준비 fixture")
	world.get_node("Player/PlayerProgression").add_exp(prepared.exp)
	world.get_node("Player/Inventory").add_gold(prepared.gold)
	var ids := ["MQ-03-01", "MQ-03-02", "MQ-03-03", "MQ-03-04", "MQ-03-05", "SQ-YEO-001", "SQ-YEO-002", "SQ-YEO-003"]
	for id in ids:
		journal = world.get_node("QuestController").journal
		var definition: QuestData = journal.catalog.definitions[id]
		await go_npc(definition.giver_id())
		journal = world.get_node("QuestController").journal
		check(journal.accept(id) == "", "API 순차 수락 " + id)
		for index in definition.objective_counts.size():
			var target: String = definition.objective_targets[index]
			var source: String = definition.objective_sources[index]
			var kind: String = definition.objective_kinds[index]
			if kind == "KILL":
				await go_region(RegionsM7.DEFENSE_WAVES[source].region)
				var manager = world.get_node("DefenseSpawner")
				check(manager.resume(), "방어 무리 명시 재개 " + source)
				check(not manager.resume(), "같은 무리 중복 재개 거부")
				var victims := world.get_node("MonsterSpawner").get_children()
				var killed := 0
				for monster in victims:
					if monster.has_method("is_dead") and not monster.is_dead() and monster.get_meta("spawn_source_id", "") == source:
						# API 결합 검사 전용 피해 fixture. 정상 공격·회피 입력 증거가 아니다.
						monster.take_damage(100000.0, "강", world.get_node("Player"))
						killed += 1
				check(killed == definition.objective_counts[index], "생성 수와 실제 사망 신호")
				await process_frame
				await process_frame
				if id == "MQ-03-03" and index == 0:
					await save_snapshot(2, "middle.json")
			elif RegionsM7.SITES.has(target):
				var site: Array = RegionsM7.SITES[target]
				await go_region(site[4])
				world.get_node("Player").position = site[0] + Vector2(0, 20)
				var found := false
				for node in world.get_node("WorldInteraction").candidates:
					if "npc_id" in node and node.npc_id == target:
						found = true
						if kind == "REACH":
							node.update_target()
						else:
							check(node.interact(), "표식 상호작용 " + target)
				check(found, "실제 표식 존재 " + target)
				if RegionsM7.SITE_NOTICES.has(target):
					check(world.get_node("QuestDialog").panel.visible, "말하는 그림자 목격 안내")
					world.get_node("QuestDialog").close_dialog()
			else:
				await go_npc(target)
				check(world.get_node("QuestDialog").open_dialog(target), "NPC 대화 " + target)
				world.get_node("QuestDialog").close_dialog()
			journal = world.get_node("QuestController").journal
			check(journal.export_state()[id].counts[index] == definition.objective_counts[index], "목표 진행 " + id + "/" + str(index))
		await go_npc(definition.npc_id)
		var controller = world.get_node("QuestController")
		var gold: int = world.get_node("Player/Inventory").gold
		check(controller.report(id, definition.npc_id) == "", "보고 " + id)
		check(controller.report(id, definition.npc_id) != "", "중복 보고 거부")
		check(world.get_node("Player/Inventory").gold == gold + definition.reward_gold, "보상 단회 지급")
		if id == "MQ-03-05":
			check(controller.journal.reputation() == 1000, "서브 없이 하사 공훈1000")
			check("향사" in controller.journal.catalog.honors(controller.journal.export_state()), "완료 기반 향사·복구권")
	journal = world.get_node("QuestController").journal
	check(journal.reputation() == 1200, "기준 서브 포함 공훈1200")
	var data: Dictionary = snapshot()
	check(data.progress.territory == {} and data.progress.story_flags == {}, "예약 영지 필드는 비워 둠")
	print("3장 API 완료 상태: ", JSON.stringify(data.player))
	await save_snapshot(1, "expected.json")
	finished = true


func go_region(destination: String) -> void:
	var hops := 0
	while world.map_id != destination and hops < 8:
		var gate := RegionsM7.next_gate(world.map_id, destination)
		if gate == "":
			check(false, "지역 연결 없음 " + destination)
			return
		await travel(RegionsM7.EDGES[gate][1])
		hops += 1
	check(world.map_id == destination, "목적 지역 접근 " + destination)


func go_npc(id: String) -> void:
	var data: Array = RegionsM7.NPCS[id] if RegionsM7.NPCS.has(id) else RegionsM7.EDGES[id]
	await go_region(data[0])
	world.get_node("Player").position = (data[1] if RegionsM7.NPCS.has(id) else data[2]) + Vector2(0, 20)


func save_snapshot(slot: int, name: String) -> void:
	await create_timer(6).timeout
	var saved: Dictionary = world.get_node("SaveSession").save_slot(slot)
	check(saved.ok, "실제 제품 V6 파일 저장 / " + saved.code)
	if not saved.ok:
		var store = world.get_node("SaveSession").store
		print("저장 임시 파일 진단: ", store._read(DIRECTORY.path_join("character_%02d.json.tmp" % slot), "character"))
	var file := FileAccess.open(DIRECTORY.path_join(name), FileAccess.WRITE)
	if file == null:
		check(false, "스냅샷 파일 열기")
		return
	file.store_string(JSON.stringify(snapshot(), "", false, true))
	file.close()
