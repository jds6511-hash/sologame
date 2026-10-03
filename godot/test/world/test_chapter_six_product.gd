extends GutTest
## API 경로 검증. 입력 전투 완주나 6시간 분량 검증과 구분한다.
const Content = preload("res://scripts/content/game_content.gd")
const Catalog = preload("res://scripts/content/game_catalog.gd")
const Product = preload("res://scripts/world/game_product.gd")


func after_each() -> void:
	BgmManager.reset()
	GameClock.reset()
	get_tree().paused = false


func previous_chapters(catalog: QuestCatalog) -> Dictionary:
	var states := {}
	for id in catalog.ordered_ids():
		if Content.QUEST_REVISIONS[id] >= 5:
			continue
		states[id] = {
			"state": "completed", "counts": Array(catalog.definitions[id].objective_counts)
		}
	return states


func test_fifteen_quests_restore_mid_objective_and_report_exact_budget() -> void:
	var catalog = Catalog.new()
	var journal := QuestJournal.new(catalog)
	assert_eq(journal.accept("MQ-06-01"), "quest_prerequisite")
	assert_eq(journal.restore_state(previous_chapters(catalog)), "")
	var totals := Vector3i.ZERO
	var token := 100
	for id in catalog.ordered_ids():
		if not (id.begins_with("MQ-06-") or id.begins_with("SQ-06-")):
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
	assert_eq(totals, Vector3i(944345, 238200, 1500))
	assert_eq(journal.accept("MQ-06-04"), "quest_already_accepted")


func test_each_region_has_sources_npcs_and_spawned_enemy_stats() -> void:
	for region in ["misran", "forest_edge", "mosswood", "sylvien"]:
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
		var progression: PlayerProgression = world.get_node("Player/PlayerProgression")
		watch_signals(progression)
		var drops: DropSystem = world.get_node("DropSystem")
		watch_signals(drops)
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
				var count: int = get_signal_emit_count(progression, "exp_changed")
				var gold_count: int = get_signal_emit_count(drops, "gold_dropped")
				monster.take_damage(monster.effective_max_hp() * 10.0)
				monster.take_damage(monster.effective_max_hp() * 10.0)
				assert_signal_emit_count(drops, "gold_dropped", gold_count + 1)
				assert_signal_emit_count(progression, "exp_changed", count + 1)
		world.free()
		await get_tree().process_frame


func test_new_enemy_telegraphs_and_approaches_are_distinct() -> void:
	var vine: MonsterStatsData = load(Content.MONSTER_VARIANTS.thorn_vine.stats)
	var mushroom: MonsterStatsData = load(Content.MONSTER_VARIANTS.poison_mushroom.stats)
	var panther: MonsterStatsData = load(Content.MONSTER_VARIANTS.forest_panther.stats)
	var treant: MonsterStatsData = load(Content.MONSTER_VARIANTS.corrupted_treant.stats)
	assert_true(vine.anchored)
	assert_eq(vine.combat_move_speed_tiles, 0.0)
	assert_eq(vine.wander_speed_tiles, 0.0)
	assert_gte(vine.melee_telegraph_sec, 0.8)
	assert_gte(mushroom.projectile_telegraph_sec, 1.0)
	assert_eq(mushroom.self_destruct_radius_tiles, 2.5)
	assert_gt(panther.combat_move_speed_tiles, mushroom.combat_move_speed_tiles)
	assert_gte(panther.charge_telegraph_sec, 0.8)
	assert_gte(panther.charge_recovery_sec, 1.0)
	assert_gt(treant.melee_range_tiles, vine.melee_range_tiles)
	assert_gte(treant.melee_telegraph_sec, 1.4)

func freeze_processes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze_processes(child)


func test_routes_to_all_sites_and_gates_use_actual_player_shape() -> void:
	for region in ["brantel", "misran", "forest_edge", "mosswood", "sylvien"]:
		var world: Node = Product.instantiate_world(region)
		world.set_meta("save_directory", "user://product_verify")
		add_child(world)
		freeze_processes(world)
		await get_tree().physics_frame
		await get_tree().physics_frame
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
		await get_tree().process_frame


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
