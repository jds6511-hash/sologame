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
