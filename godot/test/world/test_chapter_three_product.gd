extends GutTest
const Catalog = preload("res://scripts/content/game_catalog.gd")
const Product = preload("res://scripts/world/game_product.gd")
const Bootstrap = preload("res://scripts/world/game_bootstrap.gd")


func after_each() -> void:
	BgmManager.reset()
	get_tree().paused = false


func test_chapter_entry_and_title_are_derived_from_completed_quests() -> void:
	var catalog = Catalog.new()
	var journal := QuestJournal.new(catalog)
	assert_eq(journal.accept("MQ-03-01"), "quest_prerequisite")
	var bootstrap := Bootstrap.new()
	var prepared: Dictionary = bootstrap.preparation(catalog, 3)
	bootstrap.free()
	assert_eq(journal.restore_state(prepared.quests), "")
	assert_eq(journal.reputation(), 600)
	assert_eq(catalog.honors(journal.export_state()), "신분: 모험가 · 영지: 없음")
	assert_eq(journal.accept("MQ-03-01"), "")
	assert_false(journal.export_state().has("MQ-03-05"))


func test_defense_world_has_no_automatic_wave_and_guides_to_rally() -> void:
	var world = Product.instantiate_world("yeoulmok_defense")
	assert_not_null(world)
	if world == null:
		return
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(world.has_node("DefenseSpawner"))
	assert_false(world.has_node("ContentSpawner"))
	assert_eq(world.get_node("MonsterSpawner").get_child_count(), 0)
	var found := false
	for candidate in world.get_node("WorldInteraction").candidates:
		if "npc_id" in candidate and candidate.npc_id == "defense_rally":
			found = true
	assert_true(found)
	world.free()
	await get_tree().process_frame


func test_second_chapter_preparation_has_all_first_chapter_report_gold() -> void:
	var bootstrap := Bootstrap.new()
	var catalog = Catalog.new()
	var prepared: Dictionary = bootstrap.preparation(catalog, 2)
	var expected := 0
	for id in prepared.quests:
		expected += catalog.definitions[id].reward_gold
	assert_eq(prepared.gold, expected)
	bootstrap.free()
