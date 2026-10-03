## 4장·영지 API 결합 검사. 이전 장 상태·경과시간·피해량·재료는 fixture이며 입력 완주 증거가 아니다.
extends SceneTree
const ENV_PATH := "res://scripts/world/game_product.gd"
const RegionsM7 = preload("res://scripts/content/game_content.gd")
const DIRECTORY := "user://product_territory_probe"
var world: Node
var failed := false
var finished := false
var chapter := 4


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print(label, ": ", value)
	failed = failed or not value


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() not in [1, 2] or args[0] not in ["cleanup", "seed", "reload", "reload_mid"]:
		quit(2)
		return
	if args.size() == 2:
		if args[1] not in ["5", "6"]:
			quit(2)
			return
		chapter = int(args[1])
	print("CHAPTER_CONTENT_API: ", chapter)
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
		world.get_node("Player").set_physics_process(false)
		await process_frame
		await process_frame
		if args[0] in ["reload", "reload_mid"]:
			check(
				world.get_node("SaveSession").load_slot(2 if args[0] == "reload_mid" else 1).ok,
				"별도 프로세스 제품 V7 로드"
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
	print("PRODUCT_TERRITORY_FAIL" if failed else "PRODUCT_TERRITORY_PASS")
	quit(1 if failed else 0)


func refresh() -> void:
	await process_frame
	for child in root.get_children():
		if child.has_node("SaveSession") and not child.is_queued_for_deletion():
			world = child
			current_scene = world
			# API 위치 fixture가 OS 키 입력으로 움직이지 않게 한다. 도보 증거가 아니다.
			world.get_node("Player").set_physics_process(false)
	await process_frame


func snapshot() -> Dictionary:
	var session = world.get_node("SaveSession")
	var data: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	# 저장 시 갱신되는 ID/시각은 제외하고 게임 상태 전체를 비교한다.
	data.world.erase("elapsed_real_sec_in_day")  # 복원 뒤 실제 프레임만큼 흐르는 시계는 동일성 비교 제외.
	data.progress.territory.erase("elapsed_ms")
	data.progress.territory.erase("day_ms")
	data.progress.travel.erase("return_ms")
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
	if world.get_node("Player").position.distance_to(edge[3]) >= 1:
		print("도착 위치 진단 기대=", edge[3], " 실제=", world.get_node("Player").position)
	check(world.get_node("SaveSession").store.root == DIRECTORY, "교체 후 저장 격리")
	check(world.get_node("SaveSession").codec.character_version() == 7, "제품 형식7 유지")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			"res://../docs/qa/screenshots/chapter" + str(chapter) + "-" + destination + ".png"
		)


func seed_session() -> void:
	var journal: QuestJournal = world.get_node("QuestController").journal
	var states := {}
	for id in journal.catalog.ordered_ids():
		if RegionsM7.QUEST_REVISIONS[id] < chapter - 1:
			states[id] = {
				"state": "completed",
				"counts": Array(journal.catalog.definitions[id].objective_counts)
			}
	check(journal.restore_state(states) == "", "이전 장 완료 준비 fixture")
	world.get_node("Player/PlayerProgression").add_exp({4: 79291, 5: 283297, 6: 704457}[chapter])
	world.get_node("Player/Inventory").add_gold(40000)
	var ids := []
	for id in journal.catalog.ordered_ids():
		if RegionsM7.QUEST_REVISIONS[id] == chapter - 1:
			ids.append(id)
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
				await go_region(RegionsM7.HABITATS[source][0])
				var victims := world.get_node("MonsterSpawner").get_children()
				var killed := 0
				for monster in victims:
					if (
						monster.has_method("is_dead")
						and not monster.is_dead()
						and monster.get_meta("spawn_source_id", "") == source
					):
						# API 결합 검사 전용 피해 fixture. 정상 공격·회피 입력 증거가 아니다.
						monster.take_damage(100000.0, "강", world.get_node("Player"))
						killed += 1
				check(killed == definition.objective_counts[index], "생성 수와 실제 사망 신호")
				await process_frame
				await process_frame
				if id in ["MQ-04-02", "MQ-05-03", "MQ-06-03"] and index == 0:
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
							if "investigation" in node and node.investigation != null:
								# API 결합 검사: 안내 확인 후 실제 단서 상호작용을 거친다.
								# 위치 준비는 fixture이며 사람의 길찾기 검증은 아니다.
								world.get_node("QuestDialog").close_dialog()
								var field = node.investigation
								var clue = field.clues[field.correct_index]
								world.get_node("Player").global_position = clue.global_position
								check(clue.interact(), "현장 단서 대조 " + target)
								world.get_node("QuestDialog").close_dialog()
				check(found, "실제 표식 존재 " + target)
				if RegionsM7.SITE_NOTICES.has(target):
					check(world.get_node("QuestDialog").panel.visible, "공개 장면 안내")
					await capture("shadow")
					world.get_node("QuestDialog").close_dialog()
			else:
				await go_npc(target)
				check(world.get_node("QuestDialog").open_dialog(target), "NPC 대화 " + target)
				world.get_node("QuestDialog").close_dialog()
			journal = world.get_node("QuestController").journal
			check(
				journal.export_state()[id].counts[index] == definition.objective_counts[index],
				"목표 진행 " + id + "/" + str(index)
			)
		await go_npc(definition.npc_id)
		var controller = world.get_node("QuestController")
		var gold: int = world.get_node("Player/Inventory").gold
		check(controller.report(id, definition.npc_id) == "", "보고 " + id)
		check(controller.report(id, definition.npc_id) != "", "중복 보고 거부")
		check(world.get_node("Player/Inventory").gold == gold + definition.reward_gold, "보상 단회 지급")
	check(
		(
			world.get_node("QuestController").journal.reputation()
			== {4: 1950, 5: 3100, 6: 4600}[chapter]
		),
		"장 기준 공훈 합계"
	)
	await territory_session()
	await save_snapshot(1, "expected.json")
	finished = true


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	check(
		(
			root.get_texture().get_image().save_png(
				"res://../docs/qa/screenshots/chapter" + str(chapter) + "-" + label + ".png"
			)
			== OK
		),
		"화면 기록 " + label
	)


func go_region(destination: String) -> void:
	var hops := 0
	while world.map_id != destination and hops < RegionsM7.REGION_REVISIONS.size():
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
	world.get_node("Player").position = (
		(data[1] if RegionsM7.NPCS.has(id) else data[2]) + Vector2(0, 20)
	)


func save_snapshot(slot: int, name: String) -> void:
	await create_timer(6).timeout
	var saved: Dictionary = world.get_node("SaveSession").save_slot(slot)
	check(saved.ok, "실제 제품 V7 파일 저장 / " + saved.code)
	if not saved.ok:
		var store = world.get_node("SaveSession").store
		print(
			"저장 임시 파일 진단: ",
			store._read(DIRECTORY.path_join("character_%02d.json.tmp" % slot), "character")
		)
	var file := FileAccess.open(DIRECTORY.path_join(name), FileAccess.WRITE)
	if file == null:
		check(false, "스냅샷 파일 열기")
		return
	file.store_string(JSON.stringify(snapshot(), "", false, true))
	file.close()


func territory_session() -> void:
	await go_region({4: "brantel", 5: "arsel", 6: "misran"}[chapter])
	world.get_node("Player").position = RegionsM7.WARP_ARRIVALS[world.map_id]
	var session = world.get_node("SaveSession")
	check(session.warp("novera").ok, "방문 도시 유료 워프")
	await refresh()
	check(world.map_id == "novera_commons", "노베라 워프 도착")
	check(world.get_node("SaveSession").warp("yeoulmok", true).ok, "무료 영지 귀환")
	await refresh()
	check(world.map_id == "eastern_frontier_start", "소유 영지 귀환 도착")
	var runtime = world.get_node("TerritoryRuntime")
	world.get_node("Player").position = runtime.DESK
	var model = load("res://scripts/territory/territory_model.gd")
	model.advance(runtime.state(), model.DAY_MS)
	var before: int = world.get_node("Player/Inventory").gold
	check(runtime.act("collect") == "", "현장 금고 수령")
	check(world.get_node("Player/Inventory").gold == before + 189, "수입189 단회 지급")
	check(runtime.act("market") == "", "현장 시장 건설")
	check(runtime.act("market") != "", "시장 중복 건설 거부")
	var economy: Node = world.get_node("Player").get_meta("economy_candidate")
	var inventory: Dictionary = economy.state()
	inventory.bag.append({"item_id": "MAT-DOG-FANG", "quantity": 3})
	economy.apply_state(inventory)
	check(runtime.act("deliver") == "", "재료 납품과 보상")
	check(runtime.act("deliver") != "", "중복 납품 거부")
	check(runtime.act("develop") == "", "영지 복구 단계 투자")
	check(world.get_node("SaveSession").warp("brantel").ok, "영지에서 수도 워프")
	await refresh()
	check(world.map_id == "brantel", "수도 재도착")
	var rejected: Dictionary = world.get_node("SaveSession").warp("yeoulmok", true)
	check(not rejected.ok and rejected.code == "cooldown", "귀환 재사용 대기 유지")
	check(
		world.get_meta("territory_state").holdings.yeoulmok.facilities == ["market"],
		"월드 교체 후 시설 보존"
	)
