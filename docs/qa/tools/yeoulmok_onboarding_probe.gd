## 완료 fixture 없이 의뢰 UI→실제 공격→처치 신호→보고→지역 이동→저장 경로를 검증.
## 액션/마우스 이벤트와 버튼 pressed 신호를 주입한다. OS 입력·사람 체감 검증은 아니다.
# gdlint: disable=max-returns
extends "res://../docs/qa/tools/yeoulmok_journey_probe.gd"

const SAVE_ROOT := "user://yeoulmok_onboarding_probe"
var save_root := SAVE_ROOT
var completed_flow := false
var navigation_disabled := false
var defense_enabled := true
var repaths := 0
var defense_frames := 0


func _initialize() -> void:
	node_added.connect(_observe_death_sequence)
	create_timer(240.0).timeout.connect(_timeout)
	_run.call_deferred()


func _observe_death_sequence(node: Node) -> void:
	if (
		node.get_script() != null
		and node.get_script().resource_path == "res://scripts/player/player_death_sequence.gd"
	):
		node.connect("death_sequence_started", _on_observed_death)


func _on_observed_death() -> void:
	_check(false, "대기 포함 전체 세션 사망 감지")


func _timeout() -> void:
	_release()
	Input.action_release("attack")
	print("YEOULMOK_ONBOARDING_FAIL: 전체 경로 시간 초과")
	quit(1)


func _run() -> void:
	seed(20260929)  # 이 자동 조작 시나리오의 재현용. 사람 난이도 표본이 아니다.
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "play", "reload", "blocked", "walk_blocked"]:
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(save_root):
			for file in DirAccess.get_files_at(save_root):
				_check(DirAccess.remove_absolute(save_root.path_join(file)) == OK, "격리 파일 정리")
		completed_flow = true
	else:
		navigation_disabled = args[0] == "walk_blocked"
		defense_enabled = args[0] == "play"
		await _play(args[0])
	_check(completed_flow, "전체 흐름 마지막 검사 도달")
	print("도보 재탐색: ", repaths, " / 방어 입력 프레임: ", defense_frames)
	_release()
	Input.action_release("attack")
	paused = false
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	print("YEOULMOK_ONBOARDING_FAIL" if failed else "YEOULMOK_ONBOARDING_PASS")
	quit(1 if failed else 0)


func _play(phase: String) -> void:
	if DisplayServer.get_name() == "headless" and phase in ["play", "blocked", "walk_blocked"]:
		_check(false, "조준 포인터가 필요한 play/blocked는 렌더링 실행 필요")
		return
	root.size = Vector2i(1920, 1080)
	world = _instantiate_onboarding_world()
	world.set_meta("save_directory", save_root)
	root.add_child(world)
	current_scene = world
	await _refresh_world()
	if phase == "reload":
		var prior := failed
		var result: Dictionary = world.get_node("SaveSession").load_slot(1)
		_check(result.ok, "별도 프로세스 로드")
		if not result.ok:
			if not prior and not FileAccess.file_exists(save_root.path_join("character_01.json")):
				print("ONBOARDING_MISSING_SAVE_CONFIRMED")
			return
		await _refresh_world()
		_check(world.map_id == "novera_gate", "노베라 복원")
		for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04", "MQ-01-05"]:
			_check(_state(id) == "completed", "완주 상태 복원: " + id)
		var expected = JSON.parse_string(
			FileAccess.get_file_as_string(save_root.path_join("expected.json"))
		)
		# JSON 숫자는 float로 읽히므로 양쪽을 같은 직렬화 경계로 정규화한다.
		var actual = JSON.parse_string(JSON.stringify(_snapshot()))
		_check(expected is Dictionary and expected == actual, "레벨·경험치·골드·공훈·의뢰 복원")
		if expected != actual:
			print("기대: ", expected, " 실제: ", actual)
		completed_flow = true
		return
	if FileAccess.file_exists(save_root.path_join("character_01.json")):
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
	if not await _pickup_drop():
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
	var file := FileAccess.open(save_root.path_join("expected.json"), FileAccess.WRITE)
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
		"bag": _bag_counts(),
	}


func _state(id: String) -> String:
	return world.get_node("QuestController").journal.export_state().get(id, {}).get("state", "")


func _walk(target: Vector2) -> bool:
	var start := player.position
	var path := PackedVector2Array()
	var index := 0
	var rebuild := true
	var limit := 120 if navigation_disabled else 2400
	for tick in range(limit):
		_release()
		Input.action_release("attack")
		if player.get_node("PlayerStats").is_dead():
			_check(false, "이동 중 사망")
			return false
		if player.position.distance_to(target) <= 1.5:
			print("동적 도보 도착: ", start, " → ", player.position)
			return true
		var enemy := _nearest_enemy(48.0) if defense_enabled else null
		if enemy != null:
			_combat_step(enemy, true)
			defense_frames += 1
			rebuild = true
		else:
			if rebuild or tick % 30 == 0:
				path = _route(target)
				index = 0
				rebuild = false
				repaths += 1
			if not path.is_empty() and not navigation_disabled:
				while index < path.size() - 1 and player.position.distance_to(path[index]) <= 1.5:
					index += 1
				_move_toward(path[index], 1.0)
		await physics_frame
		await process_frame
	_release()
	Input.action_release("attack")
	var prior := failed
	_check(false, "동적 도보 시간 초과: %s → %s (현재 %s)" % [start, target, player.position])
	if not prior and navigation_disabled and player.position.distance_to(start) < 1.5:
		print("ONBOARDING_NAVIGATION_DISABLED_CONFIRMED")
	return false


func _route(target: Vector2) -> PackedVector2Array:
	# QA 조작기의 경로 탐색. 제품 Ground/충돌은 읽기만 하고 이동은 기존 액션으로 수행한다.
	var ground: TileMapLayer = world.get_node("Ground")
	var grid := AStarGrid2D.new()
	var pitch := _navigation_pitch()
	var scale := 16 / pitch
	var used := ground.get_used_rect()
	grid.region = Rect2i(used.position * scale, used.size * scale)
	grid.cell_size = Vector2(pitch, pitch)
	grid.offset = Vector2.ZERO if pitch == 8 else Vector2(pitch, pitch) / 2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.collision_mask = player.collision_mask
	var space := world.get_world_2d().direct_space_state
	for y in range(grid.region.position.y, grid.region.end.y):
		for x in range(grid.region.position.x, grid.region.end.x):
			var cell := Vector2i(x, y)
			query.transform = Transform2D(
				0, grid.get_point_position(cell) + player.get_node("CollisionShape2D").position
			)
			grid.set_point_solid(cell, not space.intersect_shape(query, 1).is_empty())
	var start := Vector2i((player.position / float(pitch)).floor())
	var end := Vector2i((target / float(pitch)).floor())
	if not grid.region.has_point(start) or not grid.region.has_point(end):
		return PackedVector2Array()
	grid.set_point_solid(start, false)
	var path := grid.get_point_path(start, end)
	if not path.is_empty():
		path.append(target)
	return path


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


func _nearest_enemy(radius: float, source: String = "") -> Node2D:
	var nearest: Node2D = null
	for enemy in world.get_node("MonsterSpawner").get_children():
		if not enemy is Node2D or not enemy.has_method("is_dead") or enemy.is_dead():
			continue
		if not source.is_empty() and enemy.get_meta("spawn_source_id", "") != source:
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance < radius:
			radius = distance
			nearest = enemy
	return nearest


func _move_toward(target: Vector2, tolerance: float) -> void:
	var delta := target - player.position
	if absf(delta.x) > tolerance:
		Input.action_press("move_right" if delta.x > 0 else "move_left")
	if absf(delta.y) > tolerance:
		Input.action_press("move_down" if delta.y > 0 else "move_up")


func _combat_step(enemy: Node2D, allow_attack: bool) -> void:
	var mouse := InputEventMouseMotion.new()
	mouse.position = (
		player.get_global_transform_with_canvas() * (enemy.global_position - player.global_position)
	)
	Input.parse_input_event(mouse)
	root.warp_mouse(mouse.position)
	var distance := player.position.distance_to(enemy.position)
	if distance > 16.0:
		_move_toward(enemy.position, 2.0)
	if distance < 32.0 and allow_attack:
		Input.action_press("attack")
	var stats = player.get_node("PlayerStats")
	if (
		allow_attack
		and stats.current_hp < stats.stats.max_hp * 0.5
		and stats.get_potion_cooldown_remaining_sec() <= 0.0
		and player.get_node("Inventory").get_quickslot_potion() != null
	):
		Input.action_press("quickslot_1")


func _release() -> void:
	super._release()
	Input.action_release("attack")
	Input.action_release("quickslot_1")


func _bag_counts() -> Dictionary:
	var result := {}
	for entry in player.get_node("Inventory").bag:
		result[entry.item.item_id] = entry.quantity
	return result


func _pickup_drop() -> bool:
	# 실제 사냥에서 생긴 WorldItem만 사용한다. 드롭/가방에 테스트 아이템을 넣지 않는다.
	var drops := world.find_children("*", "WorldItem", false, false)
	if drops.is_empty():
		_check(false, "실제 드롭 없음: 줍기 검증 생략 불가")
		return false
	drops.sort_custom(
		func(a, b):
			return player.position.distance_to(a.position) < player.position.distance_to(b.position)
	)
	var drop = drops[0]
	var id: String = drop.item_data.item_id
	var quantity: int = drop.quantity
	var before: int = player.get_node("Inventory").get_bag_quantity(id)
	if not await _walk(_pickup_destination(drop)):
		return false
	_release()
	Input.action_release("attack")
	# 위치 진입의 body_entered 및 UI 갱신을 기다린 뒤 F 액션을 보낸다.
	await physics_frame
	await process_frame
	_check(drop.get_node("PickupPrompt").visible, "실제 줍기 프롬프트")
	await _input_action("interact")
	await physics_frame
	var after: int = player.get_node("Inventory").get_bag_quantity(id)
	_check(after >= before + quantity and not is_instance_valid(drop), "F 입력 드롭 소멸·가방 수량 증가")
	print("ONBOARDING_PICKUP: ", id, " ", before, " → ", after)
	return not failed


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
		var nearest := _nearest_enemy(INF, source)
		# 의뢰 대상만 보며 달리면 옆의 다른 종에게 계속 맞는다. 가까운 교전부터 처리한다.
		if not blocked:
			var threat := _nearest_enemy(48.0)
			if threat != null:
				nearest = threat
		if nearest != null:
			_combat_step(nearest, not blocked)
			if tick % 120 == 0:
				print(
					"사냥 표본: ",
					id,
					" HP ",
					player.get_node("PlayerStats").current_hp,
					" 조준 ",
					player.get_global_mouse_position(),
					" 대상 ",
					nearest.position
				)
		await physics_frame
		await process_frame
	_release()
	Input.action_release("attack")
	var prior := failed
	_check(false, "실제 처치 시간 초과: " + id)
	if not prior and blocked and _state(id) == "active":
		var counts = world.get_node("QuestController").journal.export_state()[id].counts
		if counts == [0]:
			print("ONBOARDING_ATTACK_DISABLED_CONFIRMED")
	return false


func _instantiate_onboarding_world() -> Node:
	return load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()


func _navigation_pitch() -> int:
	return 16


func _pickup_destination(drop: Node2D) -> Vector2:
	return drop.position
