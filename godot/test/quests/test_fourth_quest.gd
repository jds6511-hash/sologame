extends GutTest

const Catalog = preload("res://scripts/quests/quest_catalog.gd")
const Presentation = preload("res://scripts/quests/quest_presentation.gd")


func test_fourth_definition_exists_and_matches_rewards() -> void:
	var catalog = Catalog.new()
	assert_true(catalog.definitions.has("MQ-01-04"))
	if not catalog.definitions.has("MQ-01-04"):
		return
	var definition = catalog.definitions["MQ-01-04"]
	assert_eq(definition.reward_exp, 1040)
	assert_eq(definition.reward_gold, 300)
	assert_eq(definition.definition_error(), "")


func test_blank_offer_is_content_error() -> void:
	var definition = Catalog.new().definitions["MQ-01-02"].duplicate(true)
	definition.offer_text = "  \n "
	assert_eq(definition.definition_error(), "quest_presentation")


func test_fourth_order_projection_and_duplicate_interact() -> void:
	var catalog = Catalog.new()
	if not catalog.definitions.has("MQ-01-04"):
		assert_true(false, "MQ04 정의 필요")
		return
	var journal := QuestJournal.new(catalog)
	assert_eq(journal.accept("MQ-01-04"), "quest_prerequisite")
	assert_eq(journal.restore_state(_previous()), "")
	journal.record_event("INTERACT", "yeoulmok_rift_mark", "yeoulmok_old_rift_site", 0)
	assert_eq(journal.accept("MQ-01-04"), "")
	journal.record_event("INTERACT", "yeoulmok_rift_mark", "yeoulmok_old_rift_site", 0)
	assert_eq(journal.export_state()["MQ-01-04"].counts, [0, 0])
	journal.record_event("REACH", "yeoulmok_old_rift_entrance", "wrong", 0)
	assert_eq(journal.export_state()["MQ-01-04"].counts, [0, 0])
	journal.record_event("REACH", "yeoulmok_old_rift_entrance", "yeoulmok_old_rift_site", 0)
	var view = Presentation.select(catalog, journal.export_state(), "yeoulmok_receptionist")
	assert_string_contains(view.tracker, "표식")
	for unused in 3:
		journal.record_event("INTERACT", "yeoulmok_rift_mark", "yeoulmok_old_rift_site", 0)
	assert_eq(journal.export_state()["MQ-01-04"], {"state": "ready", "counts": [1, 1]})


func _previous() -> Dictionary:
	return {
		"MQ-01-01": {"state": "completed", "counts": [1, 1]},
		"MQ-01-02": {"state": "completed", "counts": [2]},
		"MQ-01-03": {"state": "completed", "counts": [2]}
	}


func test_display_validation_and_pass_location_exception() -> void:
	var catalog = Catalog.new()
	var original: QuestData = catalog.definitions["MQ-01-04"]
	for field in ["title", "offer_text"]:
		var copy = original.duplicate(true)
		copy.set(field, " \n ")
		assert_eq(copy.definition_error(), "quest_presentation")
	for field in ["objective_labels", "objective_location_hints"]:
		var copy = original.duplicate(true)
		copy.get(field)[1] = " "
		assert_eq(copy.definition_error(), "quest_presentation")
		copy.get(field).clear()
		assert_eq(copy.definition_error(), "quest_presentation")
	var pass_quest = catalog.definitions["MQ-01-01"].duplicate(true)
	assert_eq(pass_quest.definition_error(), "")
	pass_quest.quest_id = "MQ-FAKE"
	assert_eq(pass_quest.definition_error(), "quest_presentation")


func test_old_catalog_preservation_and_content_error_file_protection() -> void:
	var codec = load("res://scripts/save/character_save_codec.gd").new()
	var actor = load("res://scenes/player/player.tscn").instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	actor.add_child(inventory)
	add_child_autofree(actor)
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	var account: Dictionary = codec.new_account()
	var data: Dictionary = codec.capture(actor, account.account_id)
	data.progress.quests = _previous()
	var directory := "user://m5_fourth_files_%d" % Time.get_ticks_usec()
	var store = load("res://scripts/save/save_file_store.gd").new(directory)
	codec.bind_store(store, account)
	assert_true(store.write_save("character", 1, data).ok)
	var fourth := data.duplicate(true)
	fourth.progress.quests["MQ-01-04"] = {"state": "active", "counts": [1, 0]}
	assert_true(store.write_save("character", 1, fourth).ok)
	var path := directory.path_join("character_01.json")
	var hash_before := FileAccess.get_sha256(path)
	codec.schema.quest_catalog.definitions.erase("MQ-01-04")
	assert_true(store.read_save("character", 1).recovered)
	assert_true(store.write_save("character", 1, data).ok)
	assert_eq(FileAccess.get_sha256(path + ".preserved." + hash_before), hash_before)
	codec.schema.quest_catalog = Catalog.new(codec.registry)
	var copy = codec.schema.quest_catalog.definitions["MQ-01-04"].duplicate(true)
	copy.offer_text = " "
	codec.schema.quest_catalog.definitions["MQ-01-04"] = copy
	var names := DirAccess.get_files_at(directory)
	var hashes := {}
	for name in names:
		hashes[name] = FileAccess.get_sha256(directory.path_join(name))
	assert_eq(store.read_save("character", 1).code, "quest_content_error")
	assert_eq(store.write_save("character", 1, data).code, "quest_content_error")
	assert_eq(DirAccess.get_files_at(directory), names)
	for name in names:
		assert_eq(FileAccess.get_sha256(directory.path_join(name)), hashes[name])
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
