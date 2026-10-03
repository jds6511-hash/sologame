extends GutTest
## API 경로 검증. 입력 전투 완주나 5시간 분량 검증과 구분한다.
const Content = preload("res://scripts/content/game_content.gd")
const Catalog = preload("res://scripts/content/game_catalog.gd")
const Product = preload("res://scripts/world/game_product.gd")


func after_each() -> void:
	BgmManager.reset()
	get_tree().paused = false


func first_act(catalog: QuestCatalog) -> Dictionary:
	var states := {}
	for id in catalog.ordered_ids():
		if Content.QUEST_REVISIONS[id] > 2:
			continue
		states[id] = {
			"state": "completed", "counts": Array(catalog.definitions[id].objective_counts)
		}
	return states


func test_nine_quests_restore_mid_objective_and_report_exact_budget() -> void:
	var catalog = Catalog.new()
	var journal := QuestJournal.new(catalog)
	assert_eq(journal.accept("MQ-04-01"), "quest_prerequisite")
	assert_eq(journal.restore_state(first_act(catalog)), "")
	var totals := Vector3i.ZERO
	var token := 100
	for id in catalog.ordered_ids():
		if not (id.begins_with("MQ-04-") or id.begins_with("SQ-CH04-")):
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
	assert_eq(totals, Vector3i(198351, 68850, 750))
	assert_eq(journal.accept("MQ-04-04"), "quest_already_accepted")


func test_each_region_has_sources_npcs_and_spawned_enemy_stats() -> void:
	for region in ["han_gilmok", "gransia", "brantel"]:
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
		for monster in world.get_node("MonsterSpawner").get_children():
			var id: String = monster.get_meta("content_id", "")
			assert_true(Content.MONSTER_VARIANTS.has(id) or id == "highwayman")
			if Content.MONSTER_VARIANTS.has(id):
				assert_eq(monster.stats.display_name, Content.MONSTER_VARIANTS[id].title)
				assert_eq(
					MonsterDropRegistry.table_for(monster).monster_level,
					Content.MONSTER_VARIANTS[id].level
				)
		world.free()
		await get_tree().process_frame


func test_new_enemy_telegraphs_and_approaches_are_distinct() -> void:
	var boar: MonsterStatsData = load(Content.MONSTER_VARIANTS.wild_boar.stats)
	var scarecrow: MonsterStatsData = load(Content.MONSTER_VARIANTS.cursed_scarecrow.stats)
	var harpy: MonsterStatsData = load(Content.MONSTER_VARIANTS.cliff_harpy.stats)
	assert_gt(boar.charge_telegraph_sec, 0.6)
	assert_gt(scarecrow.melee_telegraph_sec, 1.0)
	assert_lt(scarecrow.combat_move_speed_tiles, boar.combat_move_speed_tiles)
	assert_gt(harpy.leap_max_range_tiles, 4.0)
	assert_gt(harpy.leap_recovery_sec, 0.4)


func freeze_processes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze_processes(child)


func test_routes_to_all_sites_and_gates_use_actual_player_shape() -> void:
	for region in ["han_gilmok", "gransia", "brantel"]:
		var world: Node = Product.instantiate_world(region)
		world.set_meta("save_directory", "user://product_verify")
		add_child(world)
		freeze_processes(world)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var player: CharacterBody2D = world.get_node("Player")
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
			var transform := player.global_transform
			transform.origin = Vector2(192, 480)
			var turn := Vector2(point.x, 480)
			assert_false(player.test_move(transform, turn - transform.origin), region + " 가도")
			transform.origin = turn
			assert_false(player.test_move(transform, point - turn), region + " 표식 접근")
		world.free()
		await get_tree().process_frame
