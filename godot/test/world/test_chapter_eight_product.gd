extends GutTest
## 실제 형상 경로·생성·사망 신호 검사. 사람 입력 전투·체감 검증과 구분한다.
const Content = preload("res://scripts/content/game_content.gd")
const Product = preload("res://scripts/world/game_product.gd")


func after_each() -> void:
	BgmManager.reset()
	GameClock.reset()
	get_tree().paused = false


func frame_bounded(frame_signal: Signal, label: String) -> void:
	var state := {"seen": false}
	var arrived := func(): state.seen = true
	frame_signal.connect(arrived, CONNECT_ONE_SHOT)
	await wait_until(func(): return state.seen, 2.0, label)
	if frame_signal.is_connected(arrived):
		frame_signal.disconnect(arrived)
	assert_false(did_wait_timeout(), label)


func test_each_region_has_sources_npcs_and_spawned_enemy_stats() -> void:
	for region in ["pilgrimage_path", "oranse", "jaetgol_approach", "jaetgol"]:
		var world: Node = Product.instantiate_world(region)
		assert_not_null(world, region)
		if world == null:
			continue
		world.set_meta("save_directory", "user://product_verify")
		add_child(world)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var ids := []
		for candidate in world.get_node("WorldInteraction").candidates:
			if "npc_id" in candidate:
				ids.append(candidate.npc_id)
		for id in Content.NPCS:
			if Content.NPCS[id][0] == region:
				assert_has(ids, id)
		for id in Content.SITES:
			if Content.SITES[id][4] == region:
				assert_has(ids, id)
		var expected := 0
		for habitat in Content.HABITATS.values():
			if habitat[0] == region:
				expected += habitat[1].size()
		assert_eq(world.get_node("MonsterSpawner").get_child_count(), expected, region)
		if region in ["pilgrimage_path", "oranse"]:
			assert_eq(expected, 0, "성역 경로에는 전투가 없다")
		var progression: PlayerProgression = world.get_node("Player/PlayerProgression")
		var emissions := {"exp": 0, "gold": 0}
		progression.exp_changed.connect(func(_current, _next): emissions.exp += 1)
		var drops: DropSystem = world.get_node("DropSystem")
		drops.gold_dropped.connect(func(_amount, _position): emissions.gold += 1)
		for monster in world.get_node("MonsterSpawner").get_children():
			var id: String = monster.get_meta("content_id", "")
			assert_true(Content.MONSTER_VARIANTS.has(id))
			if Content.MONSTER_VARIANTS.has(id):
				assert_eq(monster.stats.display_name, Content.MONSTER_VARIANTS[id].title)
				assert_eq(
					MonsterDropRegistry.table_for(monster).monster_level,
					Content.MONSTER_VARIANTS[id].level
				)
				assert_almost_eq(monster.hp, monster.effective_max_hp(), 0.01)
				assert_almost_eq(
					monster.effective_attack_power(),
					monster.stats.attack_power * GameClock.get_monster_stat_multiplier(false),
					0.01
				)
				var count: int = emissions.exp
				var gold_count: int = emissions.gold
				monster.take_damage(monster.effective_max_hp() * 10.0)
				monster.take_damage(monster.effective_max_hp() * 10.0)
				assert_eq(emissions.gold, gold_count + 1)
				assert_eq(emissions.exp, count + 1)
		world.free()
		await frame_bounded(get_tree().process_frame, region + " 생성 검사 뒤 프레임")


func freeze_processes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze_processes(child)


func test_routes_to_all_sites_and_gates_use_actual_player_shape() -> void:
	for region in ["saleno", "brantel", "pilgrimage_path", "oranse", "jaetgol_approach", "jaetgol"]:
		var world: Node = Product.instantiate_world(region)
		world.set_meta("save_directory", "user://product_verify")
		add_child(world)
		freeze_processes(world)
		for frame in 2:
			await frame_bounded(get_tree().physics_frame, region + " 물리 동기화")
			if did_wait_timeout():
				world.free()
				return
		var player: CharacterBody2D = world.get_node("Player")
		var reachable := reachable_points(player, Content.BOUNDS[region])
		var points := []
		for habitat in Content.HABITATS.values():
			if habitat[0] == region:
				for spawn: Vector2 in habitat[1]:
					points.append(spawn + Vector2(0, 32))
		for arrival_edge in Content.EDGES.values():
			if arrival_edge[1] == region:
				points.append(arrival_edge[3])
		for id in Content.NPCS:
			if Content.NPCS[id][0] == region:
				points.append(Content.NPCS[id][1] + Vector2(0, 24))
		for site in Content.SITES.values():
			if site[4] == region:
				points.append(site[0] + Vector2(0, 24))
		for edge in Content.EDGES.values():
			if edge[0] == region:
				points.append(edge[2] + Vector2(0, 24))
		for point in points:
			var reached := false
			for step: Vector2 in reachable:
				if step.distance_to(point) > 48.0:
					continue
				var transform := player.global_transform
				transform.origin = step
				if not player.test_move(transform, point - step):
					reached = true
					break
			assert_true(reached, region + " 실제 플레이어 충돌 경로: " + str(point))
		world.free()
		await frame_bounded(get_tree().process_frame, region + " 경로 검사 뒤 프레임")


func reachable_points(player: CharacterBody2D, bounds: Rect2) -> Array[Vector2]:
	# 물·책장은 통과하지 않고 실제 플레이어 형상으로 우회한다.
	var queue: Array[Vector2] = [player.global_position]
	var visited := {player.global_position: true}
	var head := 0
	while head < queue.size():
		var point := queue[head]
		head += 1
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var next: Vector2 = point + direction * 32.0
			if visited.has(next) or not bounds.grow(-32).has_point(next):
				continue
			var transform := player.global_transform
			transform.origin = point
			if player.test_move(transform, next - point):
				continue
			visited[next] = true
			queue.append(next)
	return queue
