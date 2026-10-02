extends GutTest

const Bootstrap = preload("res://scripts/world/game_bootstrap.gd")


func test_chapter_preparation_is_separate_from_real_saves() -> void:
	var bootstrap = Bootstrap.new()
	assert_true(bootstrap.has_method("start_options"), "시작 화면은 기본 저장과 준비 상태를 구분한다")
	if bootstrap.has_method("start_options"):
		var options: Array = bootstrap.start_options()
		assert_eq(options.size(), 4)
		assert_eq(options[0].directory, "user://saves")
		for index in range(1, 4):
			assert_eq(options[index].directory, "user://product_chapter_preview")
			assert_eq(options[index].chapter, index)
	bootstrap.free()


func test_preparation_does_not_turn_third_chapter_into_completed_content() -> void:
	var bootstrap = Bootstrap.new()
	assert_true(bootstrap.has_method("preparation"))
	if bootstrap.has_method("preparation"):
		var catalog = load("res://scripts/content/game_catalog.gd").new()
		var data: Dictionary = bootstrap.preparation(catalog, 3)
		assert_eq(data.quests.size(), 13)
		assert_eq(data.exp, 42828)
		assert_true(data.quests.has("MQ-02-06"))
		assert_false(data.quests.has("MQ-03-01"))
		assert_eq(bootstrap.preparation(catalog, 2).quests.size(), 5)
		assert_eq(bootstrap.preparation(catalog, 1).quests.size(), 0)
	bootstrap.free()


func test_prepared_world_snapshots_follow_product_schema() -> void:
	var bootstrap = Bootstrap.new()
	for chapter in [1, 2, 3]:
		var region := (
			"eastern_frontier_start"
			if chapter == 1
			else ("novera_gate" if chapter == 2 else "novera_commons")
		)
		var world = load("res://scripts/world/game_product.gd").instantiate_world(region)
		world.set_meta("save_directory", "user://product_chapter_preview")
		add_child(world)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var journal: QuestJournal = world.get_node("QuestController").journal
		var prepared: Dictionary = bootstrap.preparation(journal.catalog, chapter)
		assert_eq(journal.restore_state(prepared.quests), "")
		var player = world.get_node("Player")
		player.get_node("PlayerProgression").add_exp(prepared.exp)
		player.get_node("Inventory").add_gold(prepared.gold)
		var session = world.get_node("SaveSession")
		var snapshot: Dictionary = session.codec.capture(player, session.account.account_id)
		assert_eq(
			session.codec.schema.character_error(snapshot, session.account),
			"",
			"chapter %d" % chapter
		)
		assert_eq(session.store.root, "user://product_chapter_preview")
		world.free()
		BgmManager.reset()
		await get_tree().process_frame
	bootstrap.free()
