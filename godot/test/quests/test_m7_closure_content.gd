extends GutTest
const Catalog = preload("res://scripts/chapter_two_closure/closure_catalog.gd")
const Regions = preload("res://scripts/chapter_two_closure/closure_regions.gd")
const Layout = preload("res://scripts/chapter_two_closure/closure_layout.gd")
const Env = preload("res://scripts/chapter_two_closure/closure_environment.gd")


func completed_first(journal: QuestJournal) -> void:
	var states := {}
	for id in QuestCatalog.ORDER + ["MQ-02-01", "MQ-02-02", "MQ-02-03", "MQ-02-04"]:
		states[id] = {"state": "completed", "counts": Array(journal.catalog.definitions[id].objective_counts)}
	assert_eq(journal.restore_state(states), "")


func after_each() -> void:
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()
	await wait_process_frames(20)


func test_catalog_budget_sources_and_side_selection() -> void:
	var catalog := Catalog.new()
	assert_eq(catalog.definition_errors(), {})
	assert_eq(catalog.ordered_ids().size(), 13)
	var exp_sum := 0
	var gold_sum := 0
	for id in catalog.NEW_IDS + catalog.CLOSURE_IDS:
		exp_sum += catalog.definitions[id].reward_exp
		gold_sum += catalog.definitions[id].reward_gold
	assert_eq(exp_sum, 36628)
	assert_eq(gold_sum, 22680)
	var journal := QuestJournal.new(catalog)
	completed_first(journal)
	assert_true(catalog.select_quest("SQ-NOV-002", journal.export_state()))
	assert_eq(catalog.special_view(journal.export_state(), "novera_receptionist").quest_id, "SQ-NOV-002")
	assert_eq(journal.accept("SQ-NOV-001"), "")
	assert_eq(journal.accept("SQ-NOV-002"), "")
	assert_eq(journal.accept("MQ-02-05"), "")
	journal.record_event("INTERACT", "novera_water_marker", "novera_water_site", 0)
	journal.record_event("KILL", "rift_slime", "novera_dungeon_habitat", 1)
	assert_eq(journal.export_state()["SQ-NOV-001"].counts, [0, 0])
	assert_eq(journal.export_state()["MQ-02-05"].counts, [0, 0, 0])
	journal.record_event("REACH", "novera_rift_chamber", "novera_rift_chamber_site", 0)
	journal.record_event("KILL", "rift_slime", "novera_rift_habitat", 2)
	assert_eq(journal.export_state()["MQ-02-05"].counts, [1, 0, 0])
	for token in [3, 4, 5]:
		journal.record_event("KILL", "rift_slime", "novera_dungeon_habitat", token)
	journal.record_event("INTERACT", "novera_rift_relic", "novera_rift_relic_site", 0)
	assert_eq(journal.export_state()["MQ-02-05"].state, "ready")
	journal.complete("MQ-02-05")
	assert_eq(journal.accept("MQ-02-06"), "")
	journal.record_event("TALK", "novera_gareth", "", 0)
	assert_eq(catalog.special_view(journal.export_state(), "novera_gareth").action, "report")
	journal.complete("MQ-02-06")
	assert_eq(journal.reputation(), 600)
	assert_true(catalog.select_quest("SQ-NOV-001", journal.export_state()))
	assert_eq(catalog.special_view(journal.export_state(), "novera_receptionist").quest_id, "SQ-NOV-001")


func test_dungeon_boot_navigation_spawns_and_actual_capsule() -> void:
	for region in Regions.SCENES:
		var world: Node = Env.instantiate_world(region)
		world.set_meta("save_directory", "user://m7_closure_candidate_content_test")
		add_child_autofree(world)
		assert_eq(world.get_meta("save_boot_error"), "")
		var dialog = world.get_node("QuestDialog")
		assert_not_null(dialog.controller)
		assert_not_null(dialog.panel)
		await wait_physics_frames(2)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		assert_eq(world.get_node("Ground").get_used_rect().size * 16, Vector2i(Regions.BOUNDS[region].size))
		var journal: QuestJournal = world.get_node("QuestController").journal
		completed_first(journal)
		assert_eq(journal.accept("MQ-02-05"), "")
		var targets: Array = world.quest_targets()
		assert_eq(targets[0].position, Layout.SITES.novera_rift_chamber[0] if region == "novera_rift" else Regions.EDGES[Regions.next_gate(region, "novera_rift")][2])
		if region == "novera_rift":
			assert_eq(world.get_node("MonsterSpawner").get_child_count(), 3)
			for monster in world.get_node("MonsterSpawner").get_children():
				assert_eq(monster.get_meta("spawn_source_id"), "novera_dungeon_habitat")
		var player = world.get_node("Player")
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = player.get_node("CollisionShape2D").shape
		query.collision_mask = 1
		var points := []
		for edge in Regions.EDGES.values():
			if edge[1] == region:
				points.append(edge[3])
				if edge[4] in ["outskirts_rift_gate", "rift_exit_gate"]:
					assert_gt(edge[3].distance_to(Regions.EDGES[edge[4]][2]), 40.0)
		for data in Layout.SITES.values():
			if data[4] == region:
				points.append(data[0])
		for point in points:
			query.transform = Transform2D(0, point + player.get_node("CollisionShape2D").position)
			assert_true(world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(), region + str(point))
		world.queue_free()
		await wait_process_frames(2)
