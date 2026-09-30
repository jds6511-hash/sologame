extends GutTest
const Catalog = preload("res://scripts/chapter_two_closure/closure_catalog.gd")
const Regions = preload("res://scripts/chapter_two_closure/closure_regions.gd")
const Layout = preload("res://scripts/chapter_two_closure/closure_layout.gd")
const Env = preload("res://scripts/chapter_two_closure/closure_environment.gd")


func test_selection_is_journal_local_and_never_changes_catalog_or_save_state() -> void:
	var catalog := Catalog.new()
	var first := QuestJournal.new(catalog)
	var second := QuestJournal.new(catalog)
	completed_first(first)
	completed_first(second)
	var before := first.export_state()
	assert_false("selected_quest_id" in catalog)
	assert_true(catalog.has_method("selected_view"))
	if not catalog.has_method("selected_view"):
		return
	var selection = load("res://scripts/chapter_two_closure/closure_selection.gd")
	assert_true(selection.select_quest(first, "SQ-NOV-002"))
	assert_eq(selection.selected_id(first), "SQ-NOV-002")
	assert_eq(selection.selected_id(second), "")
	assert_eq(first.export_state(), before)
	assert_eq(catalog.definition_errors(), {})
	var presentation = load("res://scripts/quests/quest_presentation.gd")
	assert_eq(presentation.for_journal(first, "novera_receptionist").quest_id, "SQ-NOV-002")
	assert_eq(presentation.for_journal(second, "novera_receptionist").quest_id, "MQ-02-05")
	assert_false(selection.select_quest(first, "invalid"))
	assert_eq(selection.selected_id(first), "SQ-NOV-002")


func test_outskirts_uses_field_music_in_both_candidates() -> void:
	for environment in [load("res://scripts/chapter_two/m7_environment.gd"), Env]:
		var world: Node = environment.instantiate_world("novera_outskirts")
		world.set_meta("save_directory", "user://m7_closure_candidate_music_test" if environment == Env else "user://m7_candidate_music_test")
		add_child_autofree(world)
		assert_eq(String(BgmManager.current_track_id), "field_eastern_frontier_south")
		GameClock.debug_jump_hours(17.0)
		assert_eq(String(BgmManager.current_track_id), "field_night_common")
		world.queue_free()
		await wait_process_frames(2)
		GameClock.reset()


func completed_first(journal: QuestJournal) -> void:
	var states := {}
	for id in QuestCatalog.ORDER + ["MQ-02-01", "MQ-02-02", "MQ-02-03", "MQ-02-04"]:
		states[id] = {
			"state": "completed", "counts": Array(journal.catalog.definitions[id].objective_counts)
		}
	assert_eq(journal.restore_state(states), "")


func test_dialog_map_tracker_and_travel_selection_share_journal_state() -> void:
	var world: Node = Env.instantiate_world("novera_commons")
	var directory := "user://m7_closure_candidate_selection_%d" % Time.get_ticks_usec()
	world.set_meta("save_directory", directory)
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var journal: QuestJournal = world.get_node("QuestController").journal
	completed_first(journal)
	var dialog = world.get_node("QuestDialog")
	assert_true(dialog.open_dialog("novera_receptionist"))
	dialog._select("SQ-NOV-002")
	assert_eq(dialog._selection.quest_id, "SQ-NOV-002")
	assert_true(world.get_node("QuestTracker")._label.text.contains(journal.catalog.definitions["SQ-NOV-002"].title))
	assert_true(world.quest_targets()[0].label.contains(journal.catalog.definitions["SQ-NOV-002"].title))
	dialog.choose("accept", "SQ-NOV-002")
	assert_eq(journal.export_state()["SQ-NOV-002"].state, "active")
	assert_eq(world.quest_targets()[0].position, Regions.EDGES.commons_east_gate[2])
	var session = world.get_node("SaveSession")
	var snapshot: Dictionary = session.codec.capture(world.get_node("Player"), session.account.account_id)
	assert_eq(session.codec.schema.character_error(snapshot, session.account), "")
	assert_false(JSON.stringify(snapshot).contains("selected_quest_id"))
	session._destination = "novera_outskirts"
	session._carrying_tracking = true
	var next: Node = session._instantiate_world()
	assert_eq(next.get_meta("closure_tracking"), "SQ-NOV-002")
	assert_true(session.store.write_save("account", 0, session.account).ok)
	next.set_meta("save_directory", directory)
	snapshot.world.map_id = "novera_outskirts"
	snapshot.world.position = [144, 320]
	next.set_meta("save_boot", {"account": session.account, "character": snapshot, "slot": 0, "message": ""})
	add_child_autofree(next)
	assert_eq(next.get_meta("save_boot_error"), "")
	var next_journal: QuestJournal = next.get_node("QuestController").journal
	assert_eq(next_journal.get_meta("selected_quest_id"), "SQ-NOV-002")
	assert_eq(next.quest_targets()[0].position, Regions.EDGES.outskirts_rift_gate[2])
	session._carrying_tracking = false
	var fresh: Node = session._instantiate_world()
	assert_false(fresh.has_meta("closure_tracking"))
	fresh.free()
	var states := journal.export_state()
	states["MQ-02-05"] = {"state": "completed", "counts": [1, 3, 1]}
	states["MQ-02-06"] = {"state": "ready", "counts": [1]}
	assert_eq(journal.restore_state(states), "")
	assert_true(dialog.open_dialog("novera_gareth"))
	dialog._select("MQ-02-06")
	assert_eq(dialog._selection.quest_id, "MQ-02-06")
	assert_eq(dialog._selection.action, "report")
	assert_true(world.get_node("QuestTracker")._label.text.contains(journal.catalog.definitions["MQ-02-06"].title))
	assert_eq(world.quest_targets()[0].position, Layout.GARETH)
	dialog.close_dialog()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)


func test_regular_journal_presentation_keeps_existing_selection() -> void:
	var presentation = load("res://scripts/quests/quest_presentation.gd")
	for catalog in [QuestCatalog.new(), load("res://scripts/economy/economy_environment.gd").CandidateSchema.new().quest_catalog]:
		var journal := QuestJournal.new(catalog)
		journal.set_meta("selected_quest_id", "SQ-NOV-002")
		assert_eq(presentation.for_journal(journal, "yeoulmok_receptionist"), presentation.select(catalog, {}, "yeoulmok_receptionist"))


func test_unselected_and_completed_selection_fallback_matches_map_and_tracker() -> void:
	var world: Node = Env.instantiate_world("novera_outskirts")
	world.set_meta("save_directory", "user://m7_closure_candidate_fallback_test")
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var journal: QuestJournal = world.get_node("QuestController").journal
	completed_first(journal)
	assert_eq(journal.accept("SQ-NOV-001"), "")
	var presentation = load("res://scripts/quests/quest_presentation.gd")
	var selection = load("res://scripts/chapter_two_closure/closure_selection.gd")
	assert_false(journal.has_meta("selected_quest_id"))
	assert_eq(presentation.for_journal(journal, "novera_receptionist").quest_id, "SQ-NOV-001")
	assert_eq(world.quest_targets()[0].position, Layout.SITES.novera_return_record_a[0])
	assert_true(world.get_node("QuestTracker")._label.text.contains(journal.catalog.definitions["SQ-NOV-001"].title))
	assert_true(selection.select_quest(journal, "MQ-02-05"))
	assert_eq(presentation.for_journal(journal, "novera_receptionist").quest_id, "MQ-02-05")
	assert_true(world.quest_targets()[0].label.contains(journal.catalog.definitions["MQ-02-05"].title))
	assert_true(selection.select_quest(journal, "SQ-NOV-002"))
	assert_eq(journal.accept("SQ-NOV-002"), "")
	journal.record_event("INTERACT", "novera_rift_record_a", "novera_rift_record_a_site", 0)
	journal.record_event("INTERACT", "novera_rift_record_b", "novera_rift_record_b_site", 0)
	journal.complete("SQ-NOV-002")
	assert_eq(presentation.for_journal(journal, "novera_receptionist").quest_id, "SQ-NOV-001")
	assert_eq(world.quest_targets()[0].position, Layout.SITES.novera_return_record_a[0])
	assert_true(world.get_node("QuestTracker")._label.text.contains(journal.catalog.definitions["SQ-NOV-001"].title))
	journal.record_event("INTERACT", "novera_return_record_a", "novera_return_record_a_site", 0)
	journal.record_event("INTERACT", "novera_return_record_b", "novera_return_record_b_site", 0)
	assert_eq(presentation.for_journal(journal, "novera_receptionist").action, "report")
	assert_true(world.quest_targets()[0].label.contains(journal.catalog.definitions["SQ-NOV-001"].title))


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
	assert_true(load("res://scripts/chapter_two_closure/closure_selection.gd").select_quest(journal, "SQ-NOV-002"))
	assert_eq(
		load("res://scripts/quests/quest_presentation.gd").for_journal(journal, "novera_receptionist").quest_id, "SQ-NOV-002"
	)
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
	assert_true(load("res://scripts/chapter_two_closure/closure_selection.gd").select_quest(journal, "SQ-NOV-001"))
	assert_eq(
		load("res://scripts/quests/quest_presentation.gd").for_journal(journal, "novera_receptionist").quest_id, "SQ-NOV-001"
	)


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
		assert_eq(
			world.get_node("Ground").get_used_rect().size * 16,
			Vector2i(Regions.BOUNDS[region].size)
		)
		var journal: QuestJournal = world.get_node("QuestController").journal
		completed_first(journal)
		assert_eq(journal.accept("MQ-02-05"), "")
		var targets: Array = world.quest_targets()
		assert_eq(
			targets[0].position,
			(
				Layout.SITES.novera_rift_chamber[0]
				if region == "novera_rift"
				else Regions.EDGES[Regions.next_gate(region, "novera_rift")][2]
			)
		)
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
			assert_true(
				world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),
				region + str(point)
			)
		world.queue_free()
		await wait_process_frames(2)
