extends GutTest
const BaseCodec = preload("res://scripts/save/character_save_codec.gd")
const Frozen = preload("res://scripts/economy/economy_save_candidate.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
const CONVERSION_PATH = "res://scripts/save/product_conversion.gd"
const SAVE_PATH = "res://scripts/save/product_save.gd"
var codec = BaseCodec.new()
var account: Dictionary
var player: Node2D


func before_each() -> void:
	account = codec.new_account()
	player = PLAYER.instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector2(152, 504)


func _old() -> Dictionary:
	return codec.capture(player, account.account_id)


func test_old_versions_are_validated_before_content_expansion() -> void:
	var conversion = load(CONVERSION_PATH).new()
	for version in range(1, 6):
		var data := _old()
		if version == 5:
			data = Frozen.new().upgrade(data, account).data
		data.character_save_version = version
		var original := data.duplicate(true)
		var result: Dictionary = conversion.upgrade(data, account)
		assert_true(result.ok, "V%d" % version)
		assert_eq(data, original)
		assert_eq(result.data.character_save_version, 6)
		assert_eq(result.data.content_revision, 1)
		assert_eq(result.data.progress.quests, {})
		data.world.map_id = "novera_commons"
		assert_eq(conversion.upgrade(data, account).code, "unknown_map")
		data.world.map_id = "eastern_frontier_start"
		data.player.hp = 999999
		assert_eq(conversion.upgrade(data, account).code, "vitals")


func test_revision_and_old_candidate_numbers_are_not_interchangeable() -> void:
	var conversion = load(CONVERSION_PATH).new()
	var data: Dictionary = conversion.upgrade(_old(), account).data
	assert_eq(conversion.upgrade(data, account).data, data)
	for revision in [null, 0, -1, 1.5, 2, "1", true]:
		var copy := data.duplicate(true)
		copy.content_revision = revision
		assert_eq(conversion.validate(copy, account), "unsupported_content")
	data.erase("content_revision")
	assert_eq(conversion.validate(data, account), "unsupported_content", "old candidate V6")
	data.character_save_version = 7
	assert_eq(conversion.validate(data, account), "unsupported_version", "old candidate V7")


func _complete(data: Dictionary, catalog: QuestCatalog, ids: Array) -> void:
	for id in ids:
		data.progress.quests[id] = {
			"state": "completed", "counts": Array(catalog.definitions[id].objective_counts)
		}
		data.progress.reputation += catalog.definitions[id].reward_reputation


func test_integrated_ids_prerequisites_region_locks_and_reputation() -> void:
	var conversion = load(CONVERSION_PATH).new()
	var data: Dictionary = conversion.upgrade(_old(), account).data
	var catalog: QuestCatalog = conversion.expanded.expanded.quest_catalog
	data.world.map_id = "missing_map"
	assert_eq(conversion.validate(data, account), "unknown_map")
	for region in ["novera_commons", "novera_outskirts", "novera_rift"]:
		data.world.map_id = region
		assert_eq(conversion.validate(data, account), "region_locked")
	data.world.map_id = "eastern_frontier_start"
	data.progress.quests["UNKNOWN"] = {"state": "active", "counts": []}
	assert_eq(conversion.validate(data, account), "unknown_quest")
	data.progress.quests.clear()
	data.progress.quests["MQ-02-06"] = {"state": "completed", "counts": [1]}
	assert_eq(conversion.validate(data, account), "quest_prerequisite")
	data.progress.quests.clear()
	_complete(data, catalog, ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04", "MQ-01-05",
		"MQ-02-01", "MQ-02-02", "MQ-02-03", "MQ-02-04", "MQ-02-05", "MQ-02-06"])
	data.world.map_id = "novera_rift"
	assert_eq(conversion.validate(data, account), "")
	assert_eq(data.progress.reputation, 600)
	data.progress.reputation += 1
	assert_eq(conversion.validate(data, account), "reputation")


func test_future_revision_cannot_recover_backup_or_be_overwritten() -> void:
	var save = load(SAVE_PATH)
	var directory := "user://product_content_save_test_%d" % Time.get_ticks_usec()
	var store = save.Store.new(directory)
	var product_codec = save.Codec.new()
	assert_eq(product_codec.bind_store(store, account), "")
	var data: Dictionary = product_codec.prepare_loaded(_old(), account).data
	assert_true(store.write_save("character", 1, data).ok)
	assert_true(store.write_save("character", 1, data).ok)
	var path := directory.path_join("character_01.json")
	var future := data.duplicate(true)
	future.content_revision = 2
	var payload := JSON.stringify(future, "", true, true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind": "character", "version": 6,
		"payload": payload, "checksum": payload.sha256_text()}))
	file.close()
	var digest := FileAccess.get_sha256(path)
	var result: Dictionary = store.read_save("character", 1)
	assert_eq(result.code, "unsupported_content")
	assert_eq(result.backup_code, "not_checked")
	assert_false(result.recovered)
	assert_eq(store.write_save("character", 1, data).code, "unsupported_content")
	assert_eq(FileAccess.get_sha256(path), digest)
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)


func test_session_directory_allowlist_rejects_candidates_and_traversal() -> void:
	var session = load(SAVE_PATH).Session.new()
	autofree(session)
	assert_eq(session.codec.character_version(), 6)
	assert_true(session.codec.schema.quest_catalog.definitions.has("MQ-02-06"))
	assert_true(session.codec.schema.quest_catalog.definitions.has("SQ-NOV-002"))
	for directory in ["user://saves", "user://product_verify", "user://product_real_copy"]:
		assert_true(session._allows_directory(directory))
	for directory in ["user://m7_candidate_test", "user://m7_closure_candidate_test",
		"user://product_verify/../saves", "user://saves/"]:
		assert_false(session._allows_directory(directory))
