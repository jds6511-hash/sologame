extends GutTest

const Store = preload("res://scripts/save/save_file_store.gd")
var store: RefCounted
var directory: String


class FailingStore:
	extends "res://scripts/save/save_file_store.gd"
	var fail_suffix := ""
	var fail_replace := false

	func _write_text(path: String, text: String) -> Error:
		if not fail_suffix.is_empty() and path.ends_with(fail_suffix):
			return ERR_FILE_CANT_WRITE
		return super._write_text(path, text)

	func _replace_file(source: String, destination: String) -> Error:
		if fail_replace and destination.ends_with(".json"):
			return ERR_FILE_CANT_WRITE
		return super._replace_file(source, destination)


func before_each() -> void:
	directory = "user://m4_test_%d" % Time.get_ticks_usec()
	store = Store.new(directory)


func after_each() -> void:
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)


func test_account_and_ten_slots_are_independent() -> void:
	assert_true(store.write_save("account", 0, {"discoveries": ["rabbit"]}).ok)
	for slot in range(1, 11):
		assert_true(store.write_save("character", slot, {"level": slot}).ok)
	for slot in range(1, 11):
		assert_eq(int(store.read_save("character", slot).data.level), slot)
	assert_eq(store.read_save("account", 0).data.discoveries, ["rabbit"])


func test_bad_slot_and_kind_cannot_escape_directory() -> void:
	assert_false(store.write_save("../outside", 1, {}).ok)
	assert_false(store.write_save("character", 0, {}).ok)
	assert_false(store.write_save("character", 11, {}).ok)
	assert_false(store.write_save("account", 1, {}).ok)


func test_corruption_recovers_previous_good_generation() -> void:
	store.write_save("character", 1, {"gold": 10})
	store.write_save("character", 1, {"gold": 20})
	var file := FileAccess.open(directory.path_join("character_01.json"), FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var result: Dictionary = store.read_save("character", 1)
	assert_true(result.ok)
	assert_true(result.recovered)
	assert_eq(int(result.data.gold), 10)
	assert_true(store.write_save("character", 1, {"gold": 30}).ok)
	assert_eq(int(store.read_save("character", 1).data.gold), 30)


func test_unsupported_version_is_not_overwritten_or_silently_rolled_back() -> void:
	store.write_save("character", 1, {"level": 2})
	store.write_save("character", 1, {"level": 3})
	var path := directory.path_join("character_01.json")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	envelope.version = 99
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	var original := FileAccess.get_file_as_string(path)
	assert_eq(store.read_save("character", 1).code, "unsupported_version")
	assert_false(store.write_save("character", 1, {"level": 1}).ok)
	assert_eq(FileAccess.get_file_as_string(path), original)


func test_checksum_detects_valid_json_with_changed_payload() -> void:
	store.write_save("account", 0, {"value": 1})
	var path := directory.path_join("account.json")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	envelope.payload = '{"value":999}'
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	assert_false(store.read_save("account", 0).ok)
	assert_eq(store.read_save("character", 1).code, "missing")


func test_write_failure_does_not_report_success() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("file"), FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	var blocked = Store.new(directory.path_join("file/child"))
	assert_false(blocked.write_save("account", 0, {}).ok)
	assert_engine_error_count(1, "디렉터리 대신 파일을 둔 의도적 I/O 실패")


func test_each_write_failure_preserves_last_committed_save() -> void:
	var failing := FailingStore.new(directory)
	assert_true(failing.write_save("character", 1, {"gold": 10}).ok)
	for suffix in [".json.tmp", ".bak.tmp"]:
		failing.fail_suffix = suffix
		assert_eq(failing.write_save("character", 1, {"gold": 20}).code, "io_error")
		assert_eq(int(store.read_save("character", 1).data.gold), 10)
	failing.fail_suffix = ""
	failing.fail_replace = true
	assert_eq(failing.write_save("character", 1, {"gold": 30}).code, "io_error")
	assert_eq(int(store.read_save("character", 1).data.gold), 10)
	failing.fail_replace = false
	assert_true(failing.write_save("character", 1, {"gold": 40}).ok)
	assert_eq(int(store.read_save("character", 1).data.gold), 40)


func test_schema_invalid_main_recovers_without_overwriting_backup() -> void:
	store.write_save("character", 1, {"level": 2})
	store.write_save("character", 1, {"level": -1})
	store.validators["character"] = func(data: Dictionary) -> String:
		return "" if data.get("level", 0) >= 1 else "invalid_level"
	var result: Dictionary = store.read_save("character", 1)
	assert_true(result.recovered)
	assert_eq(int(result.data.level), 2)
	assert_eq(store.write_save("character", 1, {"level": -5}).code, "invalid_data")
	assert_true(store.write_save("character", 1, {"level": 3}).ok)
	var backup := FileAccess.get_file_as_string(directory.path_join("character_01.json.bak"))
	var body: Dictionary = JSON.parse_string(JSON.parse_string(backup).payload)
	assert_eq(int(body.level), 2)


func test_uncommitted_temp_is_never_selected() -> void:
	store.write_save("character", 1, {"gold": 10})
	var failing := FailingStore.new(directory)
	failing.fail_replace = true
	failing.write_save("character", 1, {"gold": 99})
	var restarted = Store.new(directory)
	assert_eq(int(restarted.read_save("character", 1).data.gold), 10)
	failing.write_save("character", 2, {"gold": 99})
	assert_eq(restarted.read_save("character", 2).code, "missing")


func test_repeated_roundtrip_keeps_fractional_time() -> void:
	var data := {"day": 3, "elapsed": 1298.125, "position": [-12.5, 37.25]}
	for iteration in range(10):
		assert_true(store.write_save("character", 1, data).ok)
		data = store.read_save("character", 1).data
	assert_eq(float(data.elapsed), 1298.125)
	assert_eq(data.position, [-12.5, 37.25])


func test_older_version_is_rejected_too() -> void:
	store.write_save("account", 0, {})
	var path := directory.path_join("account.json")
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	envelope.version = 0
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	assert_eq(store.read_save("account").code, "unsupported_version")
	assert_eq(store.write_save("account", 0, {}).code, "unsupported_version")
