## 완료 fixture 없이 의뢰 UI→실제 공격→처치 신호→보고→지역 이동→저장 경로를 검증.
## 액션/마우스 이벤트와 버튼 pressed 신호를 주입한다. OS 입력·사람 체감 검증은 아니다.
# gdlint: disable=max-returns
extends "res://../docs/qa/tools/yeoulmok_journey_probe.gd"

const SAVE_ROOT := "user://yeoulmok_onboarding_probe"
var completed_flow := false


func _initialize() -> void:
	create_timer(240.0).timeout.connect(_timeout)
	_run.call_deferred()


func _timeout() -> void:
	_release()
	Input.action_release("attack")
	print("YEOULMOK_ONBOARDING_FAIL: 전체 경로 시간 초과")
	quit(1)


func _run() -> void:
	seed(20260929)  # 이 자동 조작 시나리오의 재현용. 사람 난이도 표본이 아니다.
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "play", "reload", "blocked"]:
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(SAVE_ROOT):
			for file in DirAccess.get_files_at(SAVE_ROOT):
				_check(DirAccess.remove_absolute(SAVE_ROOT.path_join(file)) == OK, "격리 파일 정리")
		completed_flow = true
	else:
		await _play(args[0])
	_check(completed_flow, "전체 흐름 마지막 검사 도달")
	_release()
	Input.action_release("attack")
	paused = false
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	print("YEOULMOK_ONBOARDING_FAIL" if failed else "YEOULMOK_ONBOARDING_PASS")
	quit(1 if failed else 0)


func _play(phase: String) -> void:
	if DisplayServer.get_name() == "headless" and phase in ["play", "blocked"]:
		_check(false, "조준 포인터가 필요한 play/blocked는 렌더링 실행 필요")
		return
	root.size = Vector2i(1920, 1080)
	world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", SAVE_ROOT)
	root.add_child(world)
	current_scene = world
	await _refresh_world()
	if phase == "reload":
		var result: Dictionary = world.get_node("SaveSession").load_slot(1)
		_check(result.ok, "별도 프로세스 로드")
		if not result.ok:
			if not FileAccess.file_exists(SAVE_ROOT.path_join("character_01.json")):
				print("ONBOARDING_MISSING_SAVE_CONFIRMED")
			return
		await _refresh_world()
		_check(world.map_id == "novera_gate", "노베라 복원")
		for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04", "MQ-01-05"]:
			_check(_state(id) == "completed", "완주 상태 복원: " + id)
		var expected = JSON.parse_string(
			FileAccess.get_file_as_string(SAVE_ROOT.path_join("expected.json"))
		)
		# JSON 숫자는 float로 읽히므로 양쪽을 같은 직렬화 경계로 정규화한다.
		var actual = JSON.parse_string(JSON.stringify(_snapshot()))
		_check(expected is Dictionary and expected == actual, "레벨·경험치·골드·공훈·의뢰 복원")
		if expected != actual:
			print("기대: ", expected, " 실제: ", actual)
		completed_flow = true
		return
	if FileAccess.file_exists(SAVE_ROOT.path_join("character_01.json")):
		_check(false, "기존 저장 존재: cleanup 먼저 실행")
		return
	if not await _choose("모험가 패 받기"):
		return
	_check(_state("MQ-01-01") == "completed", "MQ01 실제 대화 보고")
	if not await _choose("토끼몰이 수락"):
		return
	for point in [Vector2(200, 504), Vector2(200, 456), Vector2(304, 456)]:
		if not await _walk(point):
			return
	if not await _hunt("MQ-01-02", "yeoulmok_rabbit_habitat", phase == "blocked"):
		return
	if not await _home_report():
		return
	if not await _choose("무리들의 그림자 수락"):
		return
	for point in [Vector2(200, 504), Vector2(200, 456), Vector2(456, 456)]:
		if not await _walk(point):
			return
	if not await _hunt("MQ-01-03", "yeoulmok_dog_habitat", false):
		return
	if not await _home_report():
		return
	if not await _choose("옛 균열의 숨소리 수락"):
		return
	for point in [Vector2(152, 440), Vector2(152, 216), Vector2(168, 216)]:
		if not await _walk(point):
			return
	await _input_action("interact")
	_check(_state("MQ-01-04") == "ready", "MQ04 실제 도보·조사")
	for point in [Vector2(152, 216), Vector2(152, 440), Vector2(152, 504)]:
		if not await _walk(point):
			return
	if not await _choose("보고하고 보상 받기"):
		return
	# MQ05 제목은 카탈로그에서 읽고 실제 표시된 수락 버튼을 누른다.
	var journal = world.get_node("QuestController").journal
	if not await _choose(journal.catalog.definitions["MQ-01-05"].title + " 수락"):
		return
	for point in [Vector2(200, 504), Vector2(200, 456), Vector2(248, 456)]:
		if not await _walk(point):
			return
	await create_timer(5.1).timeout
	if not await _choose("보고하고 보상 받기"):
		return
	await _refresh_world()
	_check(world.map_id == "novera_gate", "완주 후 실제 지역 이동")
	if world.map_id != "novera_gate" or not await _save(1):
		return
	for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04", "MQ-01-05"]:
		_check(_state(id) == "completed", "fixture 없는 완주: " + id)
	var file := FileAccess.open(SAVE_ROOT.path_join("expected.json"), FileAccess.WRITE)
	if file == null:
		_check(false, "실제 진행 스냅샷 기록")
		return
	file.store_string(JSON.stringify(_snapshot()))
	file.close()
	completed_flow = true


func _snapshot() -> Dictionary:
	var progression = player.get_node("PlayerProgression")
	var journal = world.get_node("QuestController").journal
	return {
		"level": progression.current_level,
		"exp": progression.current_exp,
		"gold": player.get_node("Inventory").gold,
		"reputation": journal.reputation(),
		"quests": journal.export_state(),
	}


func _state(id: String) -> String:
	return world.get_node("QuestController").journal.export_state().get(id, {}).get("state", "")


func _walk(target: Vector2) -> bool:
	# QA 조작기의 경로 탐색. 제품 Ground/충돌은 읽기만 하고 이동은 기존 액션으로 수행한다.
	var ground: TileMapLayer = world.get_node("Ground")
	var grid := AStarGrid2D.new()
	grid.region = ground.get_used_rect()
	grid.cell_size = Vector2(16, 16)
	grid.offset = Vector2(8, 8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.collision_mask = player.collision_mask
	var space := world.get_world_2d().direct_space_state
	for y in range(grid.region.position.y, grid.region.end.y):
		for x in range(grid.region.position.x, grid.region.end.x):
			var cell := Vector2i(x, y)
			query.transform = Transform2D(0, grid.get_point_position(cell))
			grid.set_point_solid(cell, not space.intersect_shape(query, 1).is_empty())
	var start := Vector2i((player.position / 16.0).floor())
	var end := Vector2i((target / 16.0).floor())
	if not grid.region.has_point(start) or not grid.region.has_point(end):
		_check(false, "맵 밖 조작기 경로: " + str(player.position))
		return false
	grid.set_point_solid(start, false)
	var path := grid.get_point_path(start, end)
	if path.is_empty():
		_check(false, "충돌을 피하는 경로 없음: " + str(target))
		return false
	for i in range(1, path.size()):
		if (
			i + 1 < path.size()
			and (path[i] - path[i - 1]).normalized() == (path[i + 1] - path[i]).normalized()
		):
			continue
		if not await super._walk(path[i]):
			return false
	return await super._walk(target)


func _input_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	Input.parse_input_event(event)
	await process_frame


func _choose(text: String) -> bool:
	_release()
	await physics_frame
	await process_frame
	await _input_action("interact")
	var dialog = world.get_node("QuestDialog")
	_check(dialog.panel.visible and paused, "근접 상호작용 대화 열기")
	if not dialog.panel.visible:
		return false
	for node in dialog.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree() and not node.disabled:
			print("실제 표시 버튼 선택: ", text)
			node.pressed.emit()
			await process_frame
			return true
	_check(false, "선택 버튼 없음: " + text)
	return false


func _home_report() -> bool:
	for point in [Vector2(304, 456), Vector2(200, 456), Vector2(200, 504), Vector2(152, 504)]:
		if not await _walk(point):
			return false
	return await _choose("보고하고 보상 받기")


func _hunt(id: String, source: String, blocked: bool) -> bool:
	var limit := 180 if blocked else 5400
	for tick in range(limit):
		_release()
		Input.action_release("attack")
		if _state(id) == "ready":
			print("실제 처치 목표 달성: ", id)
			return true
		if player.get_node("PlayerStats").is_dead():
			_check(false, "사냥 중 사망: " + id)
			return false
		var nearest: Node2D = null
		var distance := INF
		for enemy in world.get_node("MonsterSpawner").get_children():
			if not enemy is Node2D or not enemy.has_method("is_dead") or enemy.is_dead():
				continue
			if enemy.get_meta("spawn_source_id", "") != source:
				continue
			var gap: float = player.position.distance_to(enemy.position)
			if gap < distance:
				distance = gap
				nearest = enemy
		if nearest != null:
			if tick % 120 == 0:
				print(
					"추격 표본: ",
					tick,
					" 거리 ",
					distance,
					" HP ",
					player.get_node("PlayerStats").current_hp,
					" 조준 ",
					player.get_global_mouse_position(),
					" 적 ",
					nearest.position,
					" 공격 ",
					player.attack_state
				)
			var mouse := InputEventMouseMotion.new()
			mouse.position = (
				player.get_global_transform_with_canvas()
				* (nearest.global_position - player.global_position)
			)
			Input.parse_input_event(mouse)
			root.warp_mouse(mouse.position)
			if distance > 16.0:
				var delta: Vector2 = nearest.position - player.position
				if absf(delta.x) > 2.0:
					Input.action_press("move_right" if delta.x > 0 else "move_left")
				if absf(delta.y) > 2.0:
					Input.action_press("move_down" if delta.y > 0 else "move_up")
			if distance < 32.0 and not blocked:
				Input.action_press("attack")
		await physics_frame
		await process_frame
	_release()
	Input.action_release("attack")
	_check(false, "실제 처치 시간 초과: " + id)
	if blocked and _state(id) == "active":
		var counts = world.get_node("QuestController").journal.export_state()[id].counts
		if counts == [0]:
			print("ONBOARDING_ATTACK_DISABLED_CONFIRMED")
	return false
