extends GutTest

const CONVERSION_PATH = "res://scripts/chapter_two_closure/closure_save_candidate.gd"
const ENV_PATH = "res://scripts/chapter_two_closure/closure_environment.gd"
const Legacy = preload("res://scripts/chapter_two/m7_save_candidate.gd")
const BaseCodec = preload("res://scripts/save/character_save_codec.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
var codec = BaseCodec.new()
var account: Dictionary
var source: Node2D


func before_each() -> void:
	account = codec.new_account()
	source = PLAYER.instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	source.add_child(inventory)
	add_child_autofree(source)
	source.process_mode = Node.PROCESS_MODE_DISABLED
	source.position = Vector2(152, 504)


func test_v7_conversion_is_available() -> void:
	assert_true(ResourceLoader.exists(CONVERSION_PATH), "격리 V7 변환기가 있어야 함")
	assert_true(ResourceLoader.exists(ENV_PATH), "격리 V7 실행 환경이 있어야 함")


func _v6() -> Dictionary:
	return Legacy.new().upgrade(codec.capture(source, account.account_id), account).data


func _complete_first_loop(data: Dictionary, catalog: QuestCatalog) -> void:
	for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04", "MQ-01-05",
		"MQ-02-01", "MQ-02-02", "MQ-02-03", "MQ-02-04"]:
		data.progress.quests[id] = {
			"state": "completed", "counts": Array(catalog.definitions[id].objective_counts)
		}
	data.progress.reputation = 100


func test_v6_snapshot_upgrade_is_immutable_and_v7_idempotent() -> void:
	var conversion = load(CONVERSION_PATH).new()
	var data := _v6()
	_complete_first_loop(data, conversion.expanded.expanded.quest_catalog)
	data.world.map_id = "novera_outskirts"
	data.world.position = [1120, 320]
	data.inventory.gold = 3210
	data.player.exp = 7
	var before := data.duplicate(true)
	var expected := data.duplicate(true)
	expected.character_save_version = 7
	var result: Dictionary = conversion.upgrade(data, account)
	assert_true(result.ok)
	assert_eq(data, before)
	assert_eq(result.data, expected)
	assert_eq(conversion.upgrade(result.data, account).data, expected)
	result.data.inventory.gold = 1
	assert_eq(data, before, "반환 객체 수정도 원본과 분리")


func test_v1_through_v6_use_frozen_validation_before_upgrade() -> void:
	var conversion = load(CONVERSION_PATH).new()
	for version in range(1, 7):
		var data: Dictionary = codec.capture(source, account.account_id)
		if version >= 5:
			data = _v6()
		data.character_save_version = version
		var before := data.duplicate(true)
		var result: Dictionary = conversion.upgrade(data, account)
		assert_true(result.ok, "V%d" % version)
		assert_eq(data, before)
		assert_eq(result.data.character_save_version, 7)
		assert_eq(result.data.progress.quests, {})
		data.player.hp = 999999
		assert_eq(conversion.upgrade(data, account).code, "vitals")
	var old := _v6()
	old.world.map_id = "novera_rift"
	assert_eq(conversion.upgrade(old, account).code, "unknown_map")
	old.world.map_id = "eastern_frontier_start"
	old.progress.quests["MQ-02-05"] = {"state": "active", "counts": [0, 0, 0]}
	assert_eq(conversion.upgrade(old, account).code, "unknown_quest")
	assert_eq(Legacy.new().validate(old, account), "unknown_quest")


func test_v7_regions_require_completed_entry_quests() -> void:
	var conversion = load(CONVERSION_PATH).new()
	var data: Dictionary = conversion.upgrade(_v6(), account).data
	for region in ["novera_commons", "novera_outskirts", "novera_rift"]:
		data.world.map_id = region
		data.world.position = [144, 320]
		assert_eq(conversion.validate(data, account), "region_locked", region)
	_complete_first_loop(data, conversion.expanded.expanded.quest_catalog)
	assert_eq(conversion.validate(data, account), "")
	data.progress.quests["MQ-02-04"].state = "ready"
	assert_eq(conversion.validate(data, account), "region_locked")


func test_new_quest_prerequisites_and_partial_ready_completed_roundtrip() -> void:
	var conversion = load(CONVERSION_PATH).new()
	var data: Dictionary = conversion.upgrade(_v6(), account).data
	var catalog: QuestCatalog = conversion.expanded.expanded.quest_catalog
	for id in ["MQ-02-05", "MQ-02-06", "SQ-NOV-001", "SQ-NOV-002"]:
		var copy := data.duplicate(true)
		copy.progress.quests[id] = {
			"state": "ready", "counts": Array(catalog.definitions[id].objective_counts)
		}
		assert_eq(conversion.validate(copy, account), "quest_prerequisite", id)
	_complete_first_loop(data, catalog)
	data.progress.quests["MQ-02-05"] = {"state": "active", "counts": [1, 2, 0]}
	assert_eq(conversion.validate(data, account), "")
	assert_eq(conversion.upgrade(data, account).data, data)
	data.progress.quests["MQ-02-05"] = {"state": "ready", "counts": [1, 3, 1]}
	assert_eq(conversion.validate(data, account), "")
	data.progress.quests["MQ-02-05"].state = "completed"
	data.progress.quests["MQ-02-06"] = {"state": "completed", "counts": [1]}
	data.progress.reputation = 600
	assert_eq(conversion.validate(data, account), "")
	assert_eq(conversion.upgrade(data, account).data, data)
	data.progress.reputation = 1100
	assert_eq(conversion.validate(data, account), "reputation")
	data.progress.reputation = 600
	for id in ["SQ-NOV-001", "SQ-NOV-002"]:
		for state in ["active", "ready", "completed"]:
			data.progress.quests[id] = {
				"state": state, "counts": [1, 0] if state == "active" else [1, 1]
			}
			assert_eq(conversion.validate(data, account), "")
			assert_eq(conversion.upgrade(data, account).data, data)
		data.progress.quests[id] = {"state": "active", "counts": [0, 1]}
		assert_eq(conversion.validate(data, account), "quest_order")
		data.progress.quests[id] = {"state": "completed", "counts": [1, 1]}
	var old := data.duplicate(true)
	old.character_save_version = 6
	assert_eq(Legacy.new().validate(old, account), "quest_fields")


func test_session_rejects_v6_production_and_traversal_directories() -> void:
	var environment = load(ENV_PATH)
	var session = environment.SessionClosure.new()
	var world := Node.new()
	autofree(session)
	autofree(world)
	for path in ["user://saves", "user://m6_candidate_current", "user://m7_candidate_current",
		"user://m7_closure_candidate_../saves", "user://m7_closure_candidate_x/../../saves"]:
		world.set_meta("save_directory", path)
		assert_eq(session.setup(world), "candidate_directory", path)


func test_v7_file_refused_by_old_stores_without_backup_fallback() -> void:
	var environment = load(ENV_PATH)
	var directory := "user://m7_closure_candidate_save_test_%d" % Time.get_ticks_usec()
	var store = environment.StoreClosure.new(directory)
	var candidate_codec = environment.CodecClosure.new()
	assert_eq(candidate_codec.bind_store(store, account), "")
	var data: Dictionary = candidate_codec.prepare_loaded(_v6(), account).data
	var old_data: Dictionary = codec.capture(source, account.account_id)
	var base_store = load("res://scripts/save/save_file_store.gd").new(directory)
	assert_eq(codec.bind_store(base_store, account), "")
	assert_true(base_store.write_save("character", 1, old_data).ok)
	assert_true(store.write_save("character", 1, data).ok)
	var loaded: Dictionary = store.read_save("character", 1)
	assert_true(loaded.ok)
	assert_eq(loaded.data, JSON.parse_string(JSON.stringify(data, "", true, true)))
	var path := directory.path_join("character_01.json")
	var digest := FileAccess.get_sha256(path)
	for old_store in [load("res://scripts/save/save_file_store.gd").new(directory),
		load("res://scripts/economy/economy_environment.gd").CandidateStore.new(directory),
		load("res://scripts/chapter_two/m7_environment.gd").StoreM7.new(directory)]:
		var rejected: Dictionary = old_store.read_save("character", 1)
		assert_eq(rejected.code, "unsupported_version")
		assert_eq(rejected.backup_code, "not_checked")
		assert_false(rejected.recovered)
	assert_eq(codec.schema.character_error(data, account), "unsupported_version")
	assert_eq(Legacy.new().validate(data, account), "unsupported_version")
	assert_eq(FileAccess.get_sha256(path), digest)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
