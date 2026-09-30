extends RefCounted
const Economy = preload("res://scripts/economy/economy_environment.gd")
const RegionsClosure = preload("res://scripts/chapter_two_closure/closure_regions.gd")
const Conversion = preload("res://scripts/chapter_two_closure/closure_save_candidate.gd")
const CatalogClosure = preload("res://scripts/chapter_two_closure/closure_catalog.gd")


static func instantiate_world(region: String = "eastern_frontier_start") -> Node:
	if not RegionsClosure.SCENES.has(region):
		return null
	var old_region := (
		region if region in ["eastern_frontier_start", "novera_gate"] else "novera_gate"
	)
	var world = Economy.instantiate_world(old_region)
	world.set_script(load("res://scripts/chapter_two_closure/closure_world.gd"))
	world.map_id = region
	return world


class SchemaClosure:
	extends Economy.CandidateSchema

	func _init() -> void:
		conversion = Conversion.new()
		registry.items = conversion.model.items
		quest_catalog = CatalogClosure.new(registry)
		regions = RegionsClosure


class CodecClosure:
	extends Economy.CandidateCodec

	func _init() -> void:
		schema = SchemaClosure.new()
		registry = schema.registry

	func character_version() -> int:
		return 7


class StoreClosure:
	extends Economy.CandidateStore

	func current_version(kind: String) -> int:
		return 7 if kind == "character" else 1

	func supported_versions(kind: String) -> Array:
		return [1, 2, 3, 4, 5, 6, 7] if kind == "character" else [1]


class SessionClosure:
	extends "res://scripts/save/save_session.gd"
	var _carrying_tracking := false

	func _init() -> void:
		codec = CodecClosure.new()
		regions = RegionsClosure

	func setup(owner_world: Node) -> String:
		var directory: String = owner_world.get_meta("save_directory", "")
		if not directory.begins_with("user://m7_closure_candidate_") or ".." in directory:
			return "candidate_directory"
		return super.setup(owner_world)

	func _create_store(directory: String) -> RefCounted:
		return StoreClosure.new(directory)

	func _instantiate_world() -> Node:
		var next: Node = load("res://scripts/chapter_two_closure/closure_environment.gd").instantiate_world(
			_destination
		)
		if _carrying_tracking:
			var catalog = world.get_node("QuestController").journal.catalog
			next.set_meta("closure_tracking", catalog.selected_quest_id)
		return next

	func _change_blocked() -> bool:
		return (
			world.get_node("Player").get_meta("economy_candidate").busy or super._change_blocked()
		)

	func save_slot(slot: int) -> Dictionary:
		if world.get_node("Player").get_meta("economy_candidate").busy:
			return _failure("transaction_busy")
		return super.save_slot(slot)

	func travel(destination: String) -> Dictionary:
		if RegionsClosure.edge(world.map_id, destination).is_empty():
			return _failure("unknown_map")
		_carrying_tracking = true
		var result: Dictionary = super.travel(destination)
		_carrying_tracking = false
		return result

	func _departure(destination: String) -> Vector2:
		return RegionsClosure.edge(world.map_id, destination)[2]

	func _arrival(destination: String) -> Vector2:
		return RegionsClosure.edge(world.map_id, destination)[3]
