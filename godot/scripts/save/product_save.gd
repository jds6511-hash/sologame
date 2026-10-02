extends RefCounted
# 명시한 내부 클래스는 부모의 동명 Codec/Schema 상수보다 우선해야 한다.
# gdlint: disable=duplicated-load
const ProductConversion = preload("res://scripts/save/product_conversion.gd")
const ProductContent = preload("res://scripts/content/game_content.gd")
const ProductCatalog = preload("res://scripts/content/game_catalog.gd")
const ProductRuntime = preload("res://scripts/economy/economy_runtime.gd")


class Schema:
	extends "res://scripts/save/save_schema.gd"
	var conversion = ProductConversion.new()

	func _init() -> void:
		registry.items = conversion.model.items
		quest_catalog = ProductCatalog.new(registry)
		regions = ProductContent

	func character_error(data: Dictionary, account: Dictionary) -> String:
		return conversion.validate(data, account)


class Codec:
	extends "res://scripts/save/character_save_codec.gd"

	func _init() -> void:
		schema = load("res://scripts/save/product_save.gd").Schema.new()
		registry = schema.registry

	func character_version() -> int:
		return 6

	func prepare_loaded(data: Dictionary, account: Dictionary) -> Dictionary:
		return schema.conversion.upgrade(data, account)

	func capture(player: Node2D, account_id: String, carry: Dictionary = {}) -> Dictionary:
		var data := super.capture(player, account_id, carry)
		data.content_revision = ProductContent.CURRENT_REVISION
		data.inventory.overflow = player.get_meta("economy_candidate").overflow.duplicate(true)
		return data

	func restore_into(player: Node2D, data: Dictionary, account: Dictionary) -> String:
		var error := super.restore_into(player, data, account)
		if error != "":
			return error
		var runtime := ProductRuntime.new()
		runtime.name = "Economy"
		player.add_child(runtime)
		runtime.install(player, false)
		runtime.overflow = data.inventory.overflow.duplicate(true)
		return ""


class Store:
	extends "res://scripts/save/save_file_store.gd"

	func current_version(kind: String) -> int:
		return 6 if kind == "character" else 1

	func supported_versions(kind: String) -> Array:
		return [1, 2, 3, 4, 5, 6] if kind == "character" else [1]


class Session:
	extends "res://scripts/save/save_session.gd"
	var _carrying_tracking := false

	func _init() -> void:
		codec = load("res://scripts/save/product_save.gd").Codec.new()
		regions = ProductContent

	func _allows_directory(directory: String) -> bool:
		return (
			directory
			in [
				"user://saves",
				"user://m6_product_test",
				"user://m6_product_process",
				"user://m6_product_combat",
				"user://product_verify",
				"user://product_real_copy",
				"user://product_chapter_preview"
			]
		)

	func setup(owner_world: Node) -> String:
		if not _allows_directory(owner_world.get_meta("save_directory", "")):
			return "product_directory"
		return super.setup(owner_world)

	func _create_store(directory: String) -> RefCounted:
		return load("res://scripts/save/product_save.gd").Store.new(directory)

	func _instantiate_world() -> Node:
		var next: Node = load("res://scripts/world/game_product.gd").instantiate_world(_destination)
		if _carrying_tracking:
			var journal: QuestJournal = world.get_node("QuestController").journal
			next.set_meta("selected_quest_id", journal.get_meta("selected_quest_id", ""))
		return next

	func _economy_busy() -> bool:
		var actor := world.get_node("Player")
		return actor.has_meta("economy_candidate") and actor.get_meta("economy_candidate").busy

	func _change_blocked() -> bool:
		return _economy_busy() or super._change_blocked()

	func save_slot(slot: int) -> Dictionary:
		if _economy_busy():
			return _failure("transaction_busy")
		return super.save_slot(slot)

	func travel(destination: String) -> Dictionary:
		if _economy_busy():
			return _failure("transaction_busy")
		if ProductContent.edge(world.map_id, destination).is_empty():
			return _failure("unknown_map")
		_carrying_tracking = true
		var result: Dictionary = super.travel(destination)
		_carrying_tracking = false
		return result

	func _departure(destination: String) -> Vector2:
		return ProductContent.edge(world.map_id, destination)[2]

	func _arrival(destination: String) -> Vector2:
		return ProductContent.edge(world.map_id, destination)[3]
