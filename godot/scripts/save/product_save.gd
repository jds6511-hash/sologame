extends RefCounted
# 명시한 내부 클래스는 부모의 동명 Codec/Schema 상수보다 우선해야 한다.
# gdlint: disable=duplicated-load,max-returns
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
		return 7

	func prepare_loaded(data: Dictionary, account: Dictionary) -> Dictionary:
		return schema.conversion.upgrade(data, account)

	func capture(player: Node2D, account_id: String, carry: Dictionary = {}) -> Dictionary:
		var data := super.capture(player, account_id, carry)
		data.content_revision = ProductContent.CURRENT_REVISION
		data.inventory.overflow = player.get_meta("economy_candidate").overflow.duplicate(true)
		var owner_world := player.get_parent()
		data.progress.territory = (
			owner_world
			. get_meta(
				"territory_state",
				load("res://scripts/territory/territory_model.gd").initial(data.progress.quests)
			)
			. duplicate(true)
		)
		data.progress.travel = (
			owner_world
			. get_meta(
				"travel_state",
				load("res://scripts/territory/territory_travel.gd").initial(
					data.progress.quests, data.world.map_id
				)
			)
			. duplicate(true)
		)
		data.player.hp = _json_vital(data.player.hp)
		data.player.mp = _json_vital(data.player.mp)
		return data

	func _json_vital(value: float) -> float:
		# JSON의 십진수 반올림이 최대 HP보다 1 ULP 높아질 수 있다.
		# 검증 허용치는 넓히지 않고, 원래 값 이하의 왕복 가능한 가장 가까운 값을 쓴다.
		if not is_finite(value) or value <= 0.0:
			return value
		var candidate := value
		var encoded := float(JSON.parse_string(JSON.stringify(candidate, "", true, true)))
		var bytes := PackedByteArray()
		bytes.resize(8)
		while encoded > value:
			bytes.encode_double(0, candidate)
			bytes.encode_u64(0, bytes.decode_u64(0) - 1)
			candidate = bytes.decode_double(0)
			encoded = float(JSON.parse_string(JSON.stringify(candidate, "", true, true)))
		return encoded

	func restore_into(player: Node2D, data: Dictionary, account: Dictionary) -> String:
		var error := super.restore_into(player, data, account)
		if error != "":
			return error
		var runtime := ProductRuntime.new()
		runtime.name = "Economy"
		player.add_child(runtime)
		runtime.install(player, false)
		runtime.overflow = data.inventory.overflow.duplicate(true)
		player.get_parent().set_meta("territory_state", data.progress.territory.duplicate(true))
		player.get_parent().set_meta("travel_state", data.progress.travel.duplicate(true))
		return ""


class Store:
	extends "res://scripts/save/save_file_store.gd"

	func current_version(kind: String) -> int:
		return 7 if kind == "character" else 1

	func supported_versions(kind: String) -> Array:
		return [1, 2, 3, 4, 5, 6, 7] if kind == "character" else [1]


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
				"user://product_defense_probe",
				"user://product_territory_probe",
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

	func warp(destination: String, returning: bool = false) -> Dictionary:
		if not account_error.is_empty():
			return _failure(account_error)
		if _change_blocked() or get_tree().paused:
			return _failure("session_blocked")
		var actor := world.get_node("Player")
		var snapshot: Dictionary = codec.capture(actor, account.account_id, character)
		var travel_model = load("res://scripts/territory/territory_travel.gd")
		if not returning:
			var departure: String = travel_model.departure_error(
				world.map_id, actor.position, snapshot.progress.territory
			)
			if departure != "":
				return _failure(departure)
		var offer: Dictionary = travel_model.quote(
			snapshot.progress.travel,
			snapshot.progress.territory,
			world.map_id,
			destination,
			int(snapshot.progress.reputation),
			returning
		)
		if offer.error != "":
			return _failure(offer.error)
		# 비용/쿨다운은 사본에만 적용한다. 월드 교체 실패 시 현재 인벤토리/영지는 불변이다.
		var error: String = travel_model.commit(snapshot.progress.travel, snapshot.inventory, offer)
		if error != "":
			return _failure(error)
		snapshot.world.map_id = offer.map_id
		var arrival: Vector2 = ProductContent.WARP_ARRIVALS[offer.map_id]
		snapshot.world.position = [arrival.x, arrival.y]
		snapshot.play_seconds = _play_seconds
		var tutorial := world.get_node("TutorialController")
		snapshot.tutorial = {
			"tutorial_done": tutorial.tutorial_done, "hint_heal_done": tutorial.hint_heal_done
		}
		error = codec.schema.character_error(snapshot, account)
		if error != "":
			return _failure(error)
		var disk: Dictionary = store.read_save("account")
		if disk.ok:
			if disk.data.account_id != account.account_id:
				return _failure("account_mismatch")
		elif disk.code == "missing" and _no_existing_saves():
			var written: Dictionary = store.write_save("account", 0, account)
			if not written.ok:
				return written
		else:
			return _account_failure(disk)
		_carrying_tracking = true
		var result: Dictionary = _replace_world(
			account,
			snapshot,
			active_slot,
			"워프 완료 · 저장은 별도입니다.",
			{
				"migration_pending": migration_pending,
				"loaded_source_version": loaded_source_version,
				"auto_elapsed": _auto_elapsed
			}
		)
		# 성공 뒤에는 이전 월드의 노드를 조회하지 않는다.
		_carrying_tracking = false
		return result
