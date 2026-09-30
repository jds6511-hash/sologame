extends GutTest
const Env = preload("res://scripts/chapter_two/m7_environment.gd")
const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")
const Conversion = preload("res://scripts/chapter_two/m7_save_candidate.gd")
const CatalogM7 = preload("res://scripts/chapter_two/m7_catalog.gd")
var worlds: Array[Node] = []


func make_world(region: String = "novera_commons") -> Node:
	var world: Node = Env.instantiate_world(region)
	world.set_meta("save_directory", "user://m7_candidate_unit")
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	worlds.append(world)
	return world


func after_each() -> void:
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()
	await wait_process_frames(20)


func chapter_one(journal: QuestJournal) -> void:
	var state := {}
	for id in QuestCatalog.ORDER:
		state[id] = {
			"state": "completed", "counts": Array(journal.catalog.definitions[id].objective_counts)
		}
	journal.restore_state(state)


func test_catalog_budget_and_source_order_no_retroactive_progress() -> void:
	var catalog := CatalogM7.new()
	assert_eq(catalog.definition_errors(), {})
	assert_eq(catalog.ordered_ids().size(), 9)
	var total_exp := 0
	var total_gold := 0
	for id in catalog.NEW_IDS:
		total_exp += catalog.definitions[id].reward_exp
		total_gold += catalog.definitions[id].reward_gold
		assert_eq(catalog.definitions[id].reward_reputation, 0)
	assert_eq(total_exp, 15000)
	assert_eq(total_gold, 2250)
	var journal := QuestJournal.new(catalog)
	chapter_one(journal)
	journal.record_event("KILL", "feral_dog", "novera_dog_habitat", 1)
	assert_eq(journal.accept("MQ-02-01"), "")
	assert_eq(journal.export_state()["MQ-02-01"].counts, [0])
	journal.record_event("KILL", "feral_dog", "yeoulmok_dog_habitat", 2)
	assert_eq(journal.export_state()["MQ-02-01"].counts, [0])
	for token in [3, 4, 5]:
		journal.record_event("KILL", "feral_dog", "novera_dog_habitat", token)
	assert_eq(journal.export_state()["MQ-02-01"].state, "ready")


func test_old_versions_do_not_accept_candidate_regions_or_quests() -> void:
	var world := make_world("eastern_frontier_start")
	var session = world.get_node("SaveSession")
	var data: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	var original := data.duplicate(true)
	var conversion := Conversion.new()
	assert_eq(conversion.validate(data, session.account), "")
	assert_eq(conversion.upgrade(data, session.account).data, data)
	assert_eq(data, original)
	data.character_save_version = 5
	assert_true(conversion.upgrade(data, session.account).ok)
	data.world.map_id = "novera_commons"
	assert_eq(conversion.validate(data, session.account), "unknown_map")
	data.world.map_id = "eastern_frontier_start"
	data.progress.quests["MQ-02-01"] = {"state": "active", "counts": [0]}
	assert_eq(conversion.validate(data, session.account), "unknown_quest")
	data.character_save_version = 6
	assert_ne(conversion.validate(data, session.account), "")


func test_v1_through_v5_conversion_uses_original_rules_without_input_mutation() -> void:
	var codec = load("res://scripts/save/character_save_codec.gd").new()
	var player = load("res://scenes/player/player.tscn").instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector2(152, 504)
	var account: Dictionary = codec.new_account()
	var source: Dictionary = codec.capture(player, account.account_id)
	var conversion := Conversion.new()
	for version in [1, 2, 3, 4, 5]:
		var data := source.duplicate(true)
		if version == 5:
			data = conversion.legacy.upgrade(data, account).data
		else:
			data.character_save_version = version
		var before := data.duplicate(true)
		var result: Dictionary = conversion.upgrade(data, account)
		assert_true(result.ok, "원본 V%d" % version)
		assert_eq(data, before)
		assert_eq(result.data.character_save_version, 6)
		assert_eq(result.data.progress.quests, {})
		assert_eq(conversion.upgrade(result.data, account).data, result.data)
		data.player.hp = 999999
		assert_eq(conversion.upgrade(data, account).code, "vitals")


func test_all_regions_boot_and_real_bounds_and_navigation() -> void:
	for region in RegionsM7.SCENES:
		var world := make_world(region)
		assert_eq(world.get_meta("save_boot_error"), "", region)
		assert_eq(
			world.get_node("Ground").get_used_rect().size * 16,
			Vector2i(RegionsM7.BOUNDS[region].size)
		)
		var journal: QuestJournal = world.get_node("QuestController").journal
		chapter_one(journal)
		var targets: Array = world.quest_targets()
		assert_false(targets.is_empty(), region)
		if region != "novera_commons":
			assert_eq(
				targets[0].position,
				RegionsM7.EDGES[RegionsM7.next_gate(region, "novera_commons")][2]
			)


func test_merchant_actual_position_disable_and_distance_rechecked() -> void:
	var world := make_world()
	var player = world.get_node("Player")
	var merchant = world.get_node("Merchant")
	var registry = load("res://scripts/economy/economy_merchants.gd")
	player.position = merchant.position + Vector2(40, 0)
	assert_eq(registry.nearest(player), merchant)
	merchant.position.x -= 1
	assert_null(registry.nearest(player))
	assert_eq(player.get_meta("economy_candidate").act("buy", "POT-HP-1"), "merchant_distance")
	merchant.position = player.position
	merchant.trade_enabled = false
	assert_null(registry.nearest(player))


func test_graph_rejects_nonadjacent_travel_and_keeps_world() -> void:
	var world := make_world("novera_gate")
	var session = world.get_node("SaveSession")
	assert_eq(session.travel("novera_outskirts").code, "unknown_map")
	assert_false(world.is_queued_for_deletion())
	assert_eq(session.travel("novera_commons").code, "region_locked")


func test_field_monsters_are_visible_to_existing_save_safety() -> void:
	var world := make_world("novera_outskirts")
	var monsters := world.get_node("MonsterSpawner").get_children()
	assert_eq(monsters.size(), 10)
	var player = world.get_node("Player")
	player.position = monsters[0].position + Vector2(48, 0)
	assert_false(load("res://scripts/save/save_safety.gd").nearby_enemy_details(world).is_empty())
	var session = Env.SessionM7.new()
	var foreign := Node.new()
	foreign.set_meta("save_directory", "user://saves")
	assert_eq(session.setup(foreign), "candidate_directory")
	foreign.set_meta("save_directory", "user://m7_candidate_../saves")
	assert_eq(session.setup(foreign), "candidate_directory")
	foreign.free()
	session.free()


func test_sites_do_not_steal_pickup_before_acceptance_or_after_completion() -> void:
	var world := make_world("novera_outskirts")
	var actor = world.get_node("Player")
	var controller: QuestController = world.get_node("QuestController")
	chapter_one(controller.journal)
	var rift: Node2D
	for candidate in world.get_node("WorldInteraction").candidates:
		if not candidate.get_script().resource_path.ends_with("m7_site.gd"):
			continue
		actor.position = candidate.position
		assert_false(candidate.can_interact(), "미수락 표식은 줍기를 가로채지 않음")
		if candidate.npc_id == "novera_rift_marker":
			rift = candidate
	var states := controller.journal.export_state()
	for id in ["MQ-02-01", "MQ-02-02"]:
		states[id] = {
			"state": "completed",
			"counts": Array(controller.journal.catalog.definitions[id].objective_counts)
		}
	states["MQ-02-03"] = {"state": "active", "counts": [4, 0]}
	assert_eq(controller.journal.restore_state(states), "")
	actor.position = rift.position
	assert_true(rift.can_interact(), "현재 조사 목표만 선택")
	assert_true(rift.interact())
	assert_false(rift.can_interact(), "조사 뒤에는 줍기에 선택권 반환")


func test_reports_level_ten_without_transition_and_no_duplicate_rewards() -> void:
	var world := make_world()
	var controller: QuestController = world.get_node("QuestController")
	var journal := controller.journal
	chapter_one(journal)
	var progression = world.get_node("Player/PlayerProgression")
	progression.add_exp(3820)
	var token := 0
	for id in journal.catalog.NEW_IDS:
		assert_eq(journal.accept(id), "")
		var definition: QuestData = journal.catalog.definitions[id]
		if id == "MQ-02-03":
			journal.record_event("INTERACT", "novera_rift_marker", "novera_rift_site", 0)
			assert_eq(journal.export_state()[id].counts, [0, 0])
		for index in definition.objective_counts.size():
			for count in definition.objective_counts[index]:
				token += 1
				journal.record_event(
					definition.objective_kinds[index],
					definition.objective_targets[index],
					definition.objective_sources[index],
					token
				)
		assert_eq(controller.report(id, "novera_receptionist"), "")
		var gold: int = world.get_node("Player/Inventory").gold
		assert_eq(controller.report(id, "novera_receptionist"), "quest_not_ready")
		assert_eq(world.get_node("Player/Inventory").gold, gold)
	assert_eq(progression.current_level, 10)
	assert_eq(progression.current_exp, 208)
	assert_eq(journal.reputation(), 100)
	var session = world.get_node("SaveSession")
	var data: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	assert_eq(Conversion.new().validate(data, session.account), "")
	assert_eq(data.character_save_version, 6)
	assert_eq(
		load("res://scripts/economy/economy_save_candidate.gd").new().validate(
			data, session.account
		),
		"unsupported_version"
	)
	assert_true(world.quest_targets()[0].label.contains("이번 구간 완료"))


func test_arrivals_npcs_sites_and_four_sides_use_actual_capsule() -> void:
	for region in ["novera_gate", "novera_commons", "novera_outskirts"]:
		var world := make_world(region)
		world.process_mode = Node.PROCESS_MODE_INHERIT
		await wait_physics_frames(2)
		var player = world.get_node("Player")
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = player.get_node("CollisionShape2D").shape
		query.collision_mask = 1
		var points: Array = []
		for edge in RegionsM7.EDGES.values():
			if edge[1] == region:
				points.append(edge[3])
		if region == "novera_commons":
			points.append_array([Vector2(480, 320), Vector2(544, 320), Vector2(416, 416)])
		if region == "novera_outskirts":
			for site in load("res://scripts/chapter_two/m7_layout.gd").SITES.values():
				points.append(site[0])
		for point in points:
			query.transform = Transform2D(0, point + player.get_node("CollisionShape2D").position)
			assert_true(
				world.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),
				region + str(point)
			)
		var bounds: Rect2 = RegionsM7.BOUNDS[region]
		for point in [
			Vector2(-8, 384),
			Vector2(bounds.end.x + 8, 384),
			Vector2(144, -8),
			Vector2(144, bounds.end.y + 8)
		]:
			query.transform = Transform2D(0, point)
			assert_false(world.get_world_2d().direct_space_state.intersect_shape(query).is_empty())
		world.process_mode = Node.PROCESS_MODE_DISABLED
