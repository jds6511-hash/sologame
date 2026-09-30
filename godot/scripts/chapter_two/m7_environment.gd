extends RefCounted
const Economy = preload("res://scripts/economy/economy_environment.gd")
const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")
const Conversion = preload("res://scripts/chapter_two/m7_save_candidate.gd")
const CatalogM7 = preload("res://scripts/chapter_two/m7_catalog.gd")

static func instantiate_world(region: String = "eastern_frontier_start") -> Node:
	if not RegionsM7.SCENES.has(region):
		return null
	var old_region := region if region in ["eastern_frontier_start", "novera_gate"] else "novera_gate"
	var world = Economy.instantiate_world(old_region)
	world.set_script(load("res://scripts/chapter_two/m7_world.gd"))
	world.map_id = region
	return world

class SchemaM7:
	extends Economy.CandidateSchema
	func _init() -> void:
		conversion = Conversion.new()
		registry.items = conversion.model.items
		quest_catalog = CatalogM7.new(registry)
		regions = RegionsM7

class CodecM7:
	extends Economy.CandidateCodec
	func _init() -> void:
		schema = SchemaM7.new()
		registry = schema.registry
	func character_version() -> int:
		return 6

class StoreM7:
	extends Economy.CandidateStore
	func current_version(kind: String) -> int:
		return 6 if kind == "character" else 1
	func supported_versions(kind: String) -> Array:
		return [1, 2, 3, 4, 5, 6] if kind == "character" else [1]

class SessionM7:
	extends "res://scripts/save/save_session.gd"
	func _init() -> void:
		codec = CodecM7.new()
		regions = RegionsM7
	func setup(owner_world: Node) -> String:
		var directory: String = owner_world.get_meta("save_directory", "")
		if not directory.begins_with("user://m7_candidate_") or ".." in directory:
			return "candidate_directory"
		return super.setup(owner_world)
	func _create_store(directory: String) -> RefCounted:
		return StoreM7.new(directory)
	func _instantiate_world() -> Node:
		return load("res://scripts/chapter_two/m7_environment.gd").instantiate_world(_destination)
	func _change_blocked() -> bool:
		return world.get_node("Player").get_meta("economy_candidate").busy or super._change_blocked()
	func save_slot(slot: int) -> Dictionary:
		if world.get_node("Player").get_meta("economy_candidate").busy:
			return _failure("transaction_busy")
		return super.save_slot(slot)
	func travel(destination: String) -> Dictionary:
		if RegionsM7.edge(world.map_id, destination).is_empty():
			return _failure("unknown_map")
		return super.travel(destination)
	func _departure(destination: String) -> Vector2:
		return RegionsM7.edge(world.map_id, destination)[2]
	func _arrival(destination: String) -> Vector2:
		return RegionsM7.edge(world.map_id, destination)[3]
