## 1장 완료·누적3820 EXP만 준비한다. 2장 수락/처치/조사/보고는 제품 입력 경로.
# gdlint: disable=max-returns
extends "res://../docs/qa/tools/m6_combat_probe.gd"
const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")


func _initialize() -> void:
	save_root = "user://m7_candidate_combat"
	node_added.connect(_observe_death_sequence)
	create_timer(600).timeout.connect(_timeout)
	_run.call_deferred()


func _instantiate_onboarding_world() -> Node:
	return load("res://scripts/chapter_two/m7_environment.gd").instantiate_world("novera_commons")


func _play(phase: String) -> void:
	if phase not in ["play", "reload"]:
		_check(false, "M7 지원 단계")
		return
	root.size = Vector2i(1920, 1080)
	world = _instantiate_onboarding_world()
	world.set_meta("save_directory", save_root)
	root.add_child(world)
	current_scene = world
	await _refresh_world()
	if phase == "reload":
		_check(world.get_node("SaveSession").load_slot(1).ok, "M7 별도 프로세스 복원")
		await _refresh_world()
		var expected = JSON.parse_string(
			FileAccess.get_file_as_string(save_root.path_join("expected.json"))
		)
		_check(expected == JSON.parse_string(JSON.stringify(_snapshot())), "M7 전투 진행 스냅샷 복원")
		completed_flow = true
		return
	var journal = world.get_node("QuestController").journal
	var fixture := {}
	for id in QuestCatalog.ORDER:
		fixture[id] = {
			"state": "completed", "counts": Array(journal.catalog.definitions[id].objective_counts)
		}
	_check(journal.restore_state(fixture) == "", "1장 완료 준비 fixture")
	player.get_node("PlayerProgression").add_exp(3820)
	for number in range(1, 5):
		var id := "MQ-02-%02d" % number
		if not await _walk(Vector2(480, 352)):
			return
		if not await _choose(journal.catalog.definitions[id].title + " 수락"):
			return
		if not await _gate("novera_outskirts"):
			return
		if number <= 3:
			var source: String = [
				"novera_dog_habitat", "novera_water_habitat", "novera_rift_habitat"
			][number - 1]
			if not await _kills(id, source):
				return
		if number > 1:
			var point: Vector2 = [Vector2(352, 272), Vector2(1120, 272), Vector2(272, 128)][
				number - 2
			]
			if not await _walk(point):
				return
			if number == 3:
				await _input_action("interact")
		if not await _gate("novera_commons"):
			return
		if number == 4:
			if not await _walk(Vector2(544, 352)) or not await _choose("나중에 / 닫기 [Esc]"):
				return
		if not await _walk(Vector2(480, 352)) or not await _choose("보고하고 보상 받기"):
			return
		journal = world.get_node("QuestController").journal
		_check(_state(id) == "completed", "실제 입력 완료 " + id)
	_check(player.get_node("PlayerProgression").current_level >= 10, "실제 보고 Lv10")
	if not await _save(1):
		return
	var file := FileAccess.open(save_root.path_join("expected.json"), FileAccess.WRITE)
	if file == null:
		_check(false, "M7 스냅샷 기록")
		return
	file.store_string(JSON.stringify(_snapshot()))
	file.close()
	completed_flow = true


func _gate(destination: String) -> bool:
	var edge := RegionsM7.edge(world.map_id, destination)
	if not await _walk(edge[2] + Vector2(0, 24)):
		return false
	if not await _choose(RegionsM7.NAMES[destination] + "로 이동"):
		return false
	await _refresh_world()
	_check(world.map_id == destination, "입력 지역 이동 " + destination)
	return world.map_id == destination


func _kills(id: String, source: String, objective: int = 0) -> bool:
	var path := PackedVector2Array()
	var index := 0
	var last_target := Vector2.INF
	for tick in 5400:
		_release()
		var journal = world.get_node("QuestController").journal
		var state: Dictionary = journal.export_state()[id]
		if state.counts[objective] >= journal.catalog.definitions[id].objective_counts[objective]:
			return true
		if failed or player.get_node("PlayerStats").is_dead():
			return false
		var enemy := _nearest_enemy(48)
		if enemy == null:
			enemy = _nearest_enemy(INF, source)
		if enemy != null:
			if (
				player.position.distance_to(enemy.position) <= 48
				and _combat_corridor_clear(player.position, enemy)
			):
				_combat_step(enemy, true)
				last_target = Vector2.INF
			else:
				# 실제 충돌을 읽어 경로만 계산하고 기존 이동 액션으로 접근한다.
				if tick % 30 == 0 or last_target.distance_to(enemy.position) > 16:
					path = _approach_route(enemy)
					index = 0
					last_target = enemy.position
					repaths += 1
				if not path.is_empty():
					while (
						index < path.size() - 1 and player.position.distance_to(path[index]) <= 1.5
					):
						index += 1
					_move_toward(path[index], 1.0)
		await physics_frame
		await process_frame
	_check(false, "M7 처치 제한 시간 " + id)
	return false


func _approach_route(enemy: Node2D) -> PackedVector2Array:
	# 적 몸체가 막은 끝점 대신 주변의 실제 통과 가능한 캡슐 위치를 찾는다.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.collision_mask = player.collision_mask
	var toward: Vector2 = (player.position - enemy.position).normalized()
	for angle in [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2, PI]:
		var target: Vector2 = enemy.position + toward.rotated(angle) * 32
		query.transform = Transform2D(0, target + player.get_node("CollisionShape2D").position)
		if not world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		if not _combat_corridor_clear(target, enemy):
			continue
		var path := _route(target)
		if not path.is_empty():
			return path
	return PackedVector2Array()


func _combat_corridor_clear(origin: Vector2, enemy: Node2D) -> bool:
	# 플레이어 실제 캡슐을 목표까지 쓸어 벽/다른 몸체를 검사한다.
	# 두 참가자 RID만 제외한다. 월드 충돌이나 HP/좌표는 변경하지 않는다.
	var query := PhysicsShapeQueryParameters2D.new()
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	query.shape = shape.shape
	query.collision_mask = player.collision_mask
	query.transform = Transform2D(0, origin + shape.position)
	query.motion = enemy.position - origin
	query.exclude = [player.get_rid(), enemy.get_rid()]
	var space := world.get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var fractions := space.cast_motion(query)
	return fractions[0] >= 1.0
