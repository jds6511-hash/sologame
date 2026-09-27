## C1/V3는 이 테스트 환경에만 존재한다. 제품 씬·리소스에 후보 설정을 저장하지 않는다.
extends RefCounted

const Store = preload("res://scripts/save/save_file_store.gd")
const Codec = preload("res://scripts/save/character_save_codec.gd")
const Schema = preload("res://scripts/save/save_schema.gd")
const Session = preload("res://scripts/save/save_session.gd")
const World = preload("res://scripts/world/eastern_frontier_starting_area.gd")
const Rules = preload("res://scripts/save/save_progression_rules.gd")
const WORLD_PATH := "res://scenes/world/eastern_frontier_starting_area.tscn"


static func instantiate_world() -> Node:
	var world = load(WORLD_PATH).instantiate()
	world.set_script(CandidateWorld)
	world.get_node("Player/PlayerProgression").level_curve = CandidateCurve.new()
	return world


static func seed_files(directory: String, version: int = 2) -> Dictionary:
	assert(directory.begins_with("user://c1_candidate_") and not ".." in directory)
	var account: Dictionary = Codec.new().new_account()
	var data := {
		"character_id": "a".repeat(32),
		"character_save_version": version,
		"account_id": account.account_id,
		"name": "호환 검사",
		"play_seconds": 120.0,
		"player":
		{
			"level": 20,
			"exp": 20000 if version == 3 else 50000,
			"job_id": "adventurer",
			"hp": 10.0,
			"mp": 0.0,
			"skill_points": 19,
			"spent_points": 0,
			"skill_levels": {},
			"skill_costs": {}
		},
		"inventory":
		{
			"gold": 71,
			"bag": [{"item_id": "POT-HP-1", "quantity": 3}],
			"equipment":
			{
				"weapon": "",
				"body": "",
				"legs": "",
				"head": "",
				"feet": "",
				"ring_1": "",
				"ring_2": "",
				"necklace": ""
			}
		},
		"world":
		{
			"map_id": "eastern_frontier_start",
			"position": [160.0, 504.0],
			"day_number": 2,
			"elapsed_real_sec_in_day": 15.0,
			"flags": {},
			"discovered_regions": []
		},
		"progress":
		{
			"quests": {} if version == 1 else {"MQ-01-01": {"state": "active", "counts": [0, 0]}},
			"reputation": 0,
			"territory": {},
			"story_flags": {},
			"first_death_waiver_used": false
		},
		"tutorial": {"tutorial_done": false, "hint_heal_done": false},
		"pending_transfer": null,
		"applied_transfer_ids": []
	}
	var store = Store.new(directory)
	assert(store.write_save("account", 0, account).ok)
	write_fixture(directory.path_join("character_01.json"), data)
	return {"account": account, "data": data}


static func write_fixture(path: String, data: Dictionary) -> void:
	assert(path.begins_with("user://c1_candidate_") and not ".." in path)
	var payload := JSON.stringify(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"kind": "character",
				"version": data.character_save_version,
				"payload": payload,
				"checksum": payload.sha256_text()
			}
		)
	)
	file.close()


class CandidateCurve:
	extends LevelCurveData

	func req(level: int) -> int:
		return Rules.for_version(3).req(level)


class CandidateSchema:
	extends Schema

	func character_error(data: Dictionary, account: Dictionary) -> String:
		return candidate_character_error(data, account)


class CandidateCodec:
	extends Codec

	func _init() -> void:
		schema = CandidateSchema.new()
		registry = schema.registry

	func character_version() -> int:
		return 3

	func prepare_loaded(data: Dictionary, account: Dictionary) -> Dictionary:
		return prepare_candidate_loaded(data, account)


class CandidateStore:
	extends Store

	func current_version(kind: String) -> int:
		return 3 if kind == "character" else 1

	func supported_versions(kind: String) -> Array:
		return [1, 2, 3] if kind == "character" else [1]


class CandidateSession:
	extends Session

	func _init() -> void:
		codec = CandidateCodec.new()

	func setup(owner_world: Node) -> String:
		var directory: String = owner_world.get_meta("save_directory", "")
		if not directory.begins_with("user://c1_candidate_") or ".." in directory:
			return "candidate_directory"
		if not owner_world.get_node("Player/PlayerProgression").level_curve is CandidateCurve:
			return "candidate_runtime"
		return super.setup(owner_world)

	func _create_store(directory: String) -> RefCounted:
		return CandidateStore.new(directory)

	func _instantiate_world() -> Node:
		return load("res://test/save/c1_candidate_environment.gd").instantiate_world()


class CandidateWorld:
	extends World

	func _create_save_session() -> Node:
		return CandidateSession.new()
