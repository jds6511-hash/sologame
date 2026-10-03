extends GutTest
## API 경로 검증. 입력 전투 완주나 6시간 분량 검증과 구분한다.
const Content = preload("res://scripts/content/game_content.gd")
const Catalog = preload("res://scripts/content/game_catalog.gd")
const Product = preload("res://scripts/world/game_product.gd")


func after_each() -> void:
	BgmManager.reset()
	GameClock.reset()
	get_tree().paused = false


func await_frame_bounded(frame_signal: Signal, label: String) -> void:
	# GUT 전역 신호 watcher를 쓰면 테스트 종료 뒤 SceneTree 신호가 남는다.
	var state := {"seen": false}
	var arrived := func(): state.seen = true
	frame_signal.connect(arrived, CONNECT_ONE_SHOT)
	await wait_until(func(): return state.seen, 2.0, label)
	if frame_signal.is_connected(arrived):
		frame_signal.disconnect(arrived)


func previous_chapters(catalog: QuestCatalog) -> Dictionary:
	var states := {}
	for id in catalog.ordered_ids():
		if Content.QUEST_REVISIONS[id] >= 4:
			continue
		states[id] = {
			"state": "completed", "counts": Array(catalog.definitions[id].objective_counts)
		}
	return states


func test_twelve_quests_restore_mid_objective_and_report_exact_budget() -> void:
	var catalog = Catalog.new()
	var journal := QuestJournal.new(catalog)
	assert_eq(journal.accept("MQ-05-01"), "quest_prerequisite")
	assert_eq(journal.restore_state(previous_chapters(catalog)), "")
	var totals := Vector3i.ZERO
	var token := 100
	for id in catalog.ordered_ids():
		if not (id.begins_with("MQ-05-") or id.begins_with("SQ-CH05-")):
			continue
		var quest: QuestData = catalog.definitions[id]
		assert_eq(journal.accept(id), "", id)
		for index in quest.objective_counts.size():
			journal.record_event(
				quest.objective_kinds[index], quest.objective_targets[index], "wrong", token
			)
			assert_eq(journal.export_state()[id].counts[index], 0, "다른 출처는 무효")
			for count in quest.objective_counts[index]:
				token += 1
				journal.record_event(
					quest.objective_kinds[index],
					quest.objective_targets[index],
					quest.objective_sources[index],
					token
				)
			var restored := QuestJournal.new(catalog)
			assert_eq(restored.restore_state(journal.export_state()), "", id + " 중간 복원")
			journal = restored
		assert_eq(journal.export_state()[id].state, "ready")
		journal.complete(id)
		totals += Vector3i(quest.reward_exp, quest.reward_gold, quest.reward_reputation)
	assert_eq(totals, Vector3i(410663, 135150, 1150))
	assert_eq(journal.accept("MQ-05-04"), "quest_already_accepted")


func test_each_region_has_sources_npcs_and_spawned_enemy_stats() -> void:
	for region in ["saleno", "saleno_coast", "reed_marsh", "arsel", "arsel_library"]:
		print("CH5_STAGE instantiate ", region)
		var world: Node = Product.instantiate_world(region)
		assert_not_null(world, region)
		if world == null:
			continue
		world.set_meta("save_directory", "user://product_verify")
		print("CH5_STAGE add_child ", region)
		add_child(world)
		print("CH5_STAGE ready ", region)
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
		var progression: PlayerProgression = world.get_node("Player/PlayerProgression")
		watch_signals(progression)
		for monster in world.get_node("MonsterSpawner").get_children():
			var id: String = monster.get_meta("content_id", "")
			assert_true(Content.MONSTER_VARIANTS.has(id))
			if Content.MONSTER_VARIANTS.has(id):
				assert_eq(monster.get_meta("kill_exp_profile"), Content.EXP_PROFILES["5"])
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
				var count: int = get_signal_emit_count(progression, "exp_changed")
				monster.died.emit()
				assert_signal_emit_count(progression, "exp_changed", count + 1)
		print("CH5_STAGE free ", region)
		world.free()
		print("CH5_STAGE process_frame ", region)
		await await_frame_bounded(get_tree().process_frame, region + " 해제 뒤 프레임")
		assert_false(did_wait_timeout(), region + " 해제 뒤 프레임 시간 초과")
		print("CH5_STAGE done ", region)


func test_new_enemy_telegraphs_and_approaches_are_distinct() -> void:
	var crab: MonsterStatsData = load(Content.MONSTER_VARIANTS.tidal_crab.stats)
	var lizard: MonsterStatsData = load(Content.MONSTER_VARIANTS.marsh_lizard.stats)
	var mist: MonsterStatsData = load(Content.MONSTER_VARIANTS.water_mist.stats)
	assert_gte(crab.melee_telegraph_sec, 1.0)
	assert_gt(crab.melee_recovery_sec, 0.8)
	assert_gt(lizard.charge_telegraph_sec, 0.9)
	assert_gt(lizard.combat_move_speed_tiles, crab.combat_move_speed_tiles)
	assert_gt(mist.projectile_range_tiles, 6.0)
	assert_gte(mist.projectile_telegraph_sec, 1.0)
	assert_lt(mist.combat_move_speed_tiles, crab.combat_move_speed_tiles)


func freeze_processes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze_processes(child)


func test_routes_to_all_sites_and_gates_use_actual_player_shape() -> void:
	for region in ["saleno", "saleno_coast", "reed_marsh", "arsel", "arsel_library"]:
		print("CH5_ROUTE instantiate ", region)
		var world: Node = Product.instantiate_world(region)
		world.set_meta("save_directory", "user://product_verify")
		print("CH5_ROUTE add_child ", region)
		add_child(world)
		freeze_processes(world)
		print("CH5_ROUTE physics_frame ", region)
		for frame in 2:
			await await_frame_bounded(get_tree().physics_frame, region + " 물리 동기화")
			assert_false(did_wait_timeout(), region + " 물리 동기화 시간 초과")
			if did_wait_timeout():
				world.free()
				return
		var player: CharacterBody2D = world.get_node("Player")
		print("CH5_ROUTE path_query ", region)
		var reachable := reachable_points(player)
		var points := []
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
		await await_frame_bounded(get_tree().process_frame, region + " 경로 검사 뒤 프레임")
		assert_false(did_wait_timeout(), region + " 경로 검사 뒤 프레임 시간 초과")


func reachable_points(player: CharacterBody2D) -> Array[Vector2]:
	# 물·책장은 통과하지 않고 실제 플레이어 형상으로 우회한다.
	var queue: Array[Vector2] = [Vector2(192, 480)]
	var visited := {Vector2(192, 480): true}
	var head := 0
	while head < queue.size():
		var point := queue[head]
		head += 1
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var next: Vector2 = point + direction * 32.0
			if visited.has(next) or not Rect2(32, 32, 1472, 896).has_point(next):
				continue
			var transform := player.global_transform
			transform.origin = point
			if player.test_move(transform, next - point):
				continue
			visited[next] = true
			queue.append(next)
	return queue
