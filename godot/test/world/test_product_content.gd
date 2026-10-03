extends GutTest
const Content = preload("res://scripts/content/game_content.gd")
const Catalog = preload("res://scripts/content/game_catalog.gd")
const Product = preload("res://scripts/world/game_product.gd")
const Selection = preload("res://scripts/content/game_selection.gd")


func after_each() -> void:
	BgmManager.reset()


func test_manifest_catalog_and_reciprocal_edges() -> void:
	var catalog = Catalog.new()
	assert_eq(catalog.ordered_ids().size(), 57)
	assert_eq(catalog.definition_errors(), {})
	for id in Content.EDGES:
		var edge: Array = Content.EDGES[id]
		assert_true(Content.contains(edge[0], edge[2]), id)
		assert_true(Content.contains(edge[1], edge[3]), id)
		assert_true(Content.EDGES.has(edge[4]), id)
		assert_eq(Content.EDGES[edge[4]][1], edge[0], id)
	assert_eq(Content.next_gate("novera_gate", "novera_rift"), "novera_city_gate")


func test_direct_scene_components_and_region_preservation() -> void:
	for region in Content.SCENES:
		var world = Product.instantiate_world(region)
		assert_eq(world.map_id, region)
		assert_eq(
			world.get_script().get_base_script().resource_path,
			"res://scripts/world/eastern_frontier_starting_area.gd"
		)
		assert_eq(
			world.get_node("Player/PlayerStatGrowth").get_script().resource_path,
			"res://scripts/economy/economy_growth_candidate.gd"
		)
		assert_eq(
			world.get_node("Player/PlayerJobTransition").get_script().resource_path,
			"res://scripts/economy/economy_transition_candidate.gd"
		)
		assert_not_null(world.get_node("Player/PlayerStatGrowth").job)
		assert_gt(world.get_node("Player/PlayerJobTransition").available_jobs.size(), 0)
		world.free()


func test_every_region_boots_with_content_interactions() -> void:
	for region in Content.SCENES:
		var world = Product.instantiate_world(region)
		world.set_meta("save_directory", "user://product_verify")
		add_child(world)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		assert_eq(world.get_meta("save_boot_error", ""), "", region)
		assert_eq(world.get_node("SaveSession").codec.character_version(), 7)
		assert_true(world.has_node("EconomyPanel"))
		assert_eq(world.get_node("QuestController").journal.catalog.ordered_ids().size(), 57)
		for monster in world.get_node("MonsterSpawner").get_children():
			if monster is MonsterBase and region in ["novera_outskirts", "novera_rift"]:
				var source := String(monster.get_meta("spawn_source_id", ""))
				assert_true(Content.HABITATS.has(source))
				assert_eq(Content.HABITATS[source][0], region)
		for id in Content.EDGES:
			if Content.EDGES[id][0] == region:
				var found := false
				for npc in world.get_node("WorldInteraction").candidates:
					if "npc_id" in npc and npc.npc_id == id:
						found = true
				assert_true(found, id)
		world.free()
		await get_tree().process_frame


func test_selection_is_per_journal_and_prerequisites_remain() -> void:
	var catalog = Catalog.new()
	var a := QuestJournal.new(catalog)
	var b := QuestJournal.new(catalog)
	assert_false(Selection.select_quest(a, "MQ-02-05"))
	assert_true(Selection.select_quest(a, "MQ-01-01"))
	assert_eq(Selection.selected_id(b), "")
	assert_eq(catalog.selected_view({}, "outskirts_rift_gate", ""), {})


func test_session_world_factory_carries_selection_only_for_travel() -> void:
	var world = Product.instantiate_world()
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var journal: QuestJournal = world.get_node("QuestController").journal
	assert_true(Selection.select_quest(journal, "MQ-01-01"))
	var session = world.get_node("SaveSession")
	session._destination = "novera_gate"
	session._carrying_tracking = true
	var next: Node = session._instantiate_world()
	assert_eq(next.get_meta("selected_quest_id", ""), "MQ-01-01")
	next.set_meta("save_directory", "user://product_verify")
	add_child(next)
	next.process_mode = Node.PROCESS_MODE_DISABLED
	assert_eq(Selection.selected_id(next.get_node("QuestController").journal), "MQ-01-01")
	next.free()
	session._carrying_tracking = false
	var fresh: Node = session._instantiate_world()
	assert_false(fresh.has_meta("selected_quest_id"))
	fresh.free()
	world.free()
	await get_tree().process_frame
