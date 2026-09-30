## 1장 완료/EXP3820만 fixture. 2장8의뢰는 실제 이동·전투·상호작용·표시 버튼 입력.
# gdlint: disable=max-returns
extends "res://../docs/qa/tools/m7_combat_probe.gd"
const RegionsClosure = preload("res://scripts/chapter_two_closure/closure_regions.gd")
const LayoutClosure = preload("res://scripts/chapter_two_closure/closure_layout.gd")
var started_msec := 0


func _initialize() -> void:
	save_root = "user://m7_closure_candidate_combat"
	node_added.connect(_observe_death_sequence)
	create_timer(900).timeout.connect(_timeout)
	_run.call_deferred()


func _instantiate_onboarding_world() -> Node:
	return load("res://scripts/chapter_two_closure/closure_environment.gd").instantiate_world("novera_commons")


func _run() -> void:
	seed(20260929)
	started_msec = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "play", "reload", "reload_mid"]:
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(save_root):
			for file in DirAccess.get_files_at(save_root):
				_check(DirAccess.remove_absolute(save_root.path_join(file)) == OK, "격리 파일 정리")
		completed_flow = true
	else:
		defense_enabled = args[0] == "play"
		await _play(args[0])
	_check(completed_flow, "확장 흐름 마지막 검사 도달")
	print("경로 재탐색: ", repaths, " / 소요초: ", (Time.get_ticks_msec() - started_msec) / 1000.0)
	_release()
	paused = false
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	print("M7_CLOSURE_COMBAT_FAIL" if failed else "M7_CLOSURE_COMBAT_PASS")
	quit(1 if failed else 0)


func _play(phase: String) -> void:
	if phase in ["reload", "reload_mid"]:
		world = _instantiate_onboarding_world()
		world.set_meta("save_directory", save_root)
		root.add_child(world)
		current_scene = world
		await _refresh_world()
		var middle := phase == "reload_mid"
		_check(world.get_node("SaveSession").load_slot(2 if middle else 1).ok, "별도 프로세스 V7 복원")
		await _refresh_world()
		var expected = JSON.parse_string(FileAccess.get_file_as_string(save_root.path_join("middle.json" if middle else "expected.json")))
		_check(expected == JSON.parse_string(JSON.stringify(_snapshot())), "전투 진행 스냅샷 복원")
		completed_flow = true
		return
	if DisplayServer.get_name() == "headless":
		_check(false, "정상 조준 입력 검사는 렌더링 필요")
		return
	await super._play("play")
	if failed or not completed_flow:
		return
	completed_flow = false
	# 첫4개 완료 후 새3개를 실제 대화에서 선택·수락한다.
	for id in ["MQ-02-05", "SQ-NOV-001", "SQ-NOV-002"]:
		if not await _quest_action(id, false):
			return
	if not await _gate("novera_outskirts"):
		return
	for id in ["novera_return_record_a", "novera_return_record_b"]:
		if not await _site(id):
			return
	if not await _gate("novera_rift"):
		return
	if not await _site("novera_rift_record_a") or not await _site("novera_rift_chamber"):
		return
	# 안전 입구까지 정상 걸어서 돌아가 부분 진행 저장. 후속은 현재 세션에서 계속.
	if not await _walk(Vector2(144, 320)) or not await _save(2):
		return
	_write_snapshot("middle.json")
	if not await _kills("MQ-02-05", "novera_dungeon_habitat", 1):
		return
	for id in ["novera_rift_record_b", "novera_rift_relic"]:
		if not await _site(id):
			return
	if not await _gate("novera_outskirts") or not await _gate("novera_commons"):
		return
	for id in ["MQ-02-05", "SQ-NOV-001", "SQ-NOV-002"]:
		if not await _quest_action(id, true):
			return
	if not await _quest_action("MQ-02-06", false):
		return
	if not await _walk(LayoutClosure.GARETH + Vector2(0, 32)):
		return
	# TALK는 근접 대화를 여는 제품 경로에서 기록된다.
	if not await _choose("보고하고 보상 받기"):
		return
	for id in world.get_node("QuestController").journal.catalog.ordered_ids():
		_check(_state(id) == "completed", "완료 상태 " + id)
	# 재방문이 완료 상태와 보상을 되돌리지 않는지 실제 왕복으로 확인.
	var before := _snapshot()
	if not await _gate("novera_outskirts") or not await _gate("novera_rift"):
		return
	if not await _gate("novera_outskirts") or not await _gate("novera_commons"):
		return
	_check(before.quests == _snapshot().quests, "완료 후 재방문 의뢰 유지")
	if not await _save(1):
		return
	_write_snapshot("expected.json")
	print("M7_CLOSURE_EXP: fixture=3820 reports=36628 combat=", _total_exp() - 3820 - 36628, " total=", _total_exp(), " gold=", player.get_node("Inventory").gold, " level=", player.get_node("PlayerProgression").current_level)
	completed_flow = true


func _gate(destination: String) -> bool:
	var edge := RegionsClosure.edge(world.map_id, destination)
	if not await _walk(edge[2] + Vector2(0, 24)):
		return false
	if not await _choose(RegionsClosure.NAMES[destination] + "로 이동"):
		return false
	await _refresh_world()
	_check(world.map_id == destination, "입력 지역 이동 " + destination)
	return world.map_id == destination


func _site(id: String) -> bool:
	var site: Array = LayoutClosure.SITES[id]
	if not await _walk(site[0]):
		return false
	if site[2] == "INTERACT":
		await _input_action("interact")
	return not failed


func _quest_action(id: String, report: bool) -> bool:
	if not await _walk(Vector2(480, 352)):
		return false
	var title: String = world.get_node("QuestController").journal.catalog.definitions[id].title
	_release()
	await physics_frame
	await _input_action("interact")
	var dialog = world.get_node("QuestDialog")
	if not dialog.panel.visible:
		_check(false, "의뢰 선택 대화 열기")
		return false
	for node in dialog.find_children("*", "Button", true, false):
		if node.text == "의뢰 선택: " + title and node.is_visible_in_tree():
			node.pressed.emit()
			await process_frame
			break
	return await _press_visible("보고하고 보상 받기" if report else title + " 수락")


func _press_visible(text: String) -> bool:
	for node in world.get_node("QuestDialog").find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree() and not node.disabled:
			var before := _total_exp()
			var gold: int = player.get_node("Inventory").gold
			node.pressed.emit()
			await process_frame
			print("입력 선택 ", text, " EXP ", before, " → ", _total_exp(), " gold ", gold, " → ", player.get_node("Inventory").gold)
			return true
	_check(false, "선택 버튼 없음: " + text)
	return false


func _choose(text: String) -> bool:
	var before := _total_exp()
	var gold: int = player.get_node("Inventory").gold
	var ok: bool = await super._choose(text)
	if is_instance_valid(player):
		print("입력 선택 ", text, " EXP ", before, " → ", _total_exp(), " gold ", gold, " → ", player.get_node("Inventory").gold)
	return ok


func _total_exp() -> int:
	var progression = player.get_node("PlayerProgression")
	var total: int = progression.current_exp
	for level in range(1, progression.current_level):
		total += progression.level_curve.req(level)
	return total


func _write_snapshot(name: String) -> void:
	var file := FileAccess.open(save_root.path_join(name), FileAccess.WRITE)
	if file == null:
		_check(false, "스냅샷 기록")
		return
	file.store_string(JSON.stringify(_snapshot()))
	file.close()


func _snapshot() -> Dictionary:
	var data := super._snapshot()
	data["map_id"] = world.map_id
	data["position"] = [player.position.x, player.position.y]
	return data
