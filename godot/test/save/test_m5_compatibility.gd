# gdlint: disable=max-public-methods
extends GutTest

const Codec = preload("res://scripts/save/character_save_codec.gd")
const Store = preload("res://scripts/save/save_file_store.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
var codec: RefCounted
var account: Dictionary
var data: Dictionary
var directory: String


func before_each() -> void:
	codec = Codec.new()
	account = codec.new_account()
	var player = PLAYER.instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	data = codec.capture(player, account.account_id)
	directory = "user://m5_compat_%d" % Time.get_ticks_usec()


func after_each() -> void:
	GameClock.reset()
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)


func test_new_capture_uses_version_two() -> void:
	assert_eq(data.character_save_version, 2)


func test_previous_catalog_recovers_backup_and_preserves_unknown_third_quest_on_write() -> void:
	var store = Store.new(directory)
	codec.bind_store(store, account)
	var previous: Dictionary = data.duplicate(true)
	previous.progress.quests = {
		"MQ-01-01": {"state": "completed", "counts": [1, 1]},
		"MQ-01-02": {"state": "completed", "counts": [2]}
	}
	assert_true(store.write_save("character", 1, previous).ok)
	var future := previous.duplicate(true)
	future.progress.quests["MQ-01-03"] = {"state": "active", "counts": [1]}
	assert_true(store.write_save("character", 1, future).ok)
	var path := directory.path_join("character_01.json")
	var original_hash := FileAccess.get_sha256(path)
	codec.schema.quest_catalog.definitions.erase("MQ-01-03")
	assert_eq(codec.schema.character_error(future, account), "quest_fields")
	var recovered: Dictionary = store.read_save("character", 1)
	assert_true(recovered.ok)
	assert_true(recovered.recovered)
	assert_eq(recovered.main_code, "invalid_data")
	assert_eq(FileAccess.get_sha256(path), original_hash, "read never rewrites original")
	assert_true(store.write_save("character", 1, previous).ok)
	assert_eq(FileAccess.get_sha256(path + ".preserved." + original_hash), original_hash)


func test_third_quest_all_states_remain_version_two_and_restore_to_independent_journal() -> void:
	for state in ["active", "ready", "completed"]:
		data.progress.quests = {
			"MQ-01-01": {"state": "completed", "counts": [1, 1]},
			"MQ-01-02": {"state": "completed", "counts": [2]},
			"MQ-01-03": {"state": state, "counts": [1 if state == "active" else 2]}
		}
		assert_eq(codec.schema.character_error(data, account), "")
		var journal := QuestJournal.new(codec.schema.quest_catalog)
		assert_eq(
			journal.restore_state(JSON.parse_string(JSON.stringify(data.progress.quests))), ""
		)
		assert_eq(journal.export_state(), data.progress.quests)
		data.progress.quests["MQ-01-03"].counts[0] = 0
		assert_ne(journal.export_state(), data.progress.quests)


func test_direct_codec_unsupported_integer_versions_match_store() -> void:
	for version in [0, -1, 3, 0.0]:
		data.character_save_version = version
		assert_eq(codec.prepare_loaded(data, account).code, "unsupported_version")


func test_unaccepted_content_error_does_not_recover_or_modify_saves() -> void:
	var store = Store.new(directory)
	codec.bind_store(store, account)
	assert_true(store.write_save("character", 1, data).ok)
	assert_true(store.write_save("character", 1, data).ok)
	var path := directory.path_join("character_01.json")
	var main_hash := FileAccess.get_sha256(path)
	var backup_hash := FileAccess.get_sha256(path + ".bak")
	var copy: QuestData = codec.schema.quest_catalog.definitions["MQ-01-02"].duplicate(true)
	codec.schema.quest_catalog.definitions[copy.quest_id] = copy
	for fault in ["objective_counts", "reward_item_id"]:
		copy.objective_counts.assign([0] if fault == "objective_counts" else [2])
		copy.reward_item_id = "missing_item" if fault == "reward_item_id" else "POT-HP-1"
		var read: Dictionary = store.read_save("character", 1)
		assert_eq(read.code, "quest_content_error")
		assert_eq(read.backup_code, "not_checked")
		assert_eq(store.write_save("character", 1, data).code, "quest_content_error")
		assert_eq(FileAccess.get_sha256(path), main_hash)
		assert_eq(FileAccess.get_sha256(path + ".bak"), backup_hash)
		assert_eq(DirAccess.get_files_at(directory).size(), 2)


func test_supported_quest_progress_is_accepted() -> void:
	data.character_save_version = 2
	data.progress.quests = {
		"MQ-01-01": {"state": "completed", "counts": [1, 1]},
		"MQ-01-02": {"state": "active", "counts": [1]}
	}
	assert_eq(codec.schema.character_error(data, account), "")


func test_write_rejects_payload_version_mismatch() -> void:
	var store = Store.new(directory)
	data.character_save_version = 1
	assert_eq(store.write_save("character", 1, data).code, "invalid_data")


func test_read_rejects_envelope_payload_mismatch() -> void:
	var store = Store.new(directory)
	data.character_save_version = 2
	_raw(store, 1, data)
	assert_eq(store.read_save("character", 1).code, "invalid_data")


func test_v1_upgrade_is_pure_and_preserves_all_progress() -> void:
	data.character_save_version = 1
	data.inventory.gold = 193
	var original := data.duplicate(true)
	var result: Dictionary = codec.prepare_loaded(data, account)
	assert_true(result.ok)
	assert_eq(data, original)
	original.character_save_version = 2
	assert_eq(result.data, original)
	assert_eq(codec.prepare_loaded(result.data, account).data, original)
	result.data.progress.quests["MQ-01-01"] = {"state": "active", "counts": [0, 0]}
	assert_eq(data.progress.quests, {})


func test_invalid_v1_and_future_versions_are_not_migrated() -> void:
	data.character_save_version = 1
	data.player.level = -1
	assert_false(codec.prepare_loaded(data, account).ok)
	data.player.level = 1
	data.progress.quests = {"MQ-01-01": {"state": "ready", "counts": [1, 1]}}
	assert_eq(codec.prepare_loaded(data, account).code, "reserved_progress")
	data.character_save_version = 99
	assert_eq(codec.prepare_loaded(data, account).code, "unsupported_version")


func test_v1_read_and_first_v2_write_keep_original_backup() -> void:
	var store = Store.new(directory)
	codec.bind_store(store, account)
	data.character_save_version = 1
	_raw(store, 1, data)
	var path := directory.path_join("character_01.json")
	var original := FileAccess.get_sha256(path)
	var read: Dictionary = store.read_save("character", 1)
	assert_true(read.ok)
	assert_false(read.recovered)
	var prepared: Dictionary = codec.prepare_loaded(read.data, account)
	assert_eq(FileAccess.get_sha256(path), original)
	assert_true(store.write_save("character", 1, prepared.data).ok)
	assert_eq(FileAccess.get_sha256(path + ".bak"), original)
	assert_eq(int(store.read_save("character", 1).data.character_save_version), 2)
	for file in DirAccess.get_files_at(directory):
		assert_false(".preserved." in file)
	store._write_text(path, "broken")
	assert_true(store.read_save("character", 1).recovered)
	assert_eq(int(store.read_save("character", 1).data.character_save_version), 1)


func test_mismatch_preserved_and_future_body_never_overwritten() -> void:
	var store = Store.new(directory)
	var path := directory.path_join("character_01.json")
	for versions in [[1, 2], [2, 1]]:
		data.character_save_version = versions[1]
		_raw(store, versions[0], data)
		var digest := FileAccess.get_sha256(path)
		assert_eq(store.read_save("character", 1).code, "invalid_data")
		data.character_save_version = 2
		assert_true(store.write_save("character", 1, data).ok)
		assert_eq(FileAccess.get_sha256(path + ".preserved." + digest), digest)
	data.character_save_version = 99
	_raw(store, 2, data)
	var original := FileAccess.get_sha256(path)
	assert_eq(store.read_save("character", 1).code, "unsupported_version")
	data.character_save_version = 2
	assert_eq(store.write_save("character", 1, data).code, "unsupported_version")
	assert_eq(FileAccess.get_sha256(path), original)


func test_missing_fractional_and_boolean_body_versions_are_invalid() -> void:
	var store = Store.new(directory)
	for version in [null, true, 1.5, "2"]:
		data.character_save_version = version
		_raw(store, 2, data)
		assert_eq(store.read_save("character", 1).code, "invalid_data")
		assert_eq(store.write_save("character", 1, data).code, "invalid_data")


func _raw(store: RefCounted, version: int, payload_data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var payload := JSON.stringify(payload_data)
	store._write_text(
		directory.path_join("character_01.json"),
		JSON.stringify(
			{
				"kind": "character",
				"version": version,
				"payload": payload,
				"checksum": payload.sha256_text()
			}
		)
	)
