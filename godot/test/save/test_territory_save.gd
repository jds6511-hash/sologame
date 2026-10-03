extends GutTest
const Frozen = preload("res://scripts/save/frozen_v6/conversion.gd")
const BaseCodec = preload("res://scripts/save/character_save_codec.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
const Conversion = preload("res://scripts/save/product_conversion.gd")
const ProductSave = preload("res://scripts/save/product_save.gd")
var account: Dictionary
var player: Node2D
var codec = BaseCodec.new()


class RejectingSession:
	extends ProductSave.Session
	var offered: Dictionary = {}

	func _replace_world(
		_saved_account: Dictionary,
		data: Dictionary,
		_slot: int,
		_message: String,
		_session_carry: Dictionary = {}
	) -> Dictionary:
		offered = data.duplicate(true)
		return {"ok": false, "code": "injected_world_failure"}


class AccountStore:
	extends RefCounted
	var account: Dictionary

	func read_save(_kind: String, _slot: int = 0) -> Dictionary:
		return {"ok": true, "code": "ok", "data": account}


func before_each() -> void:
	account = codec.new_account()
	player = PLAYER.instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector2(152, 504)


func old_snapshot() -> Dictionary:
	return Frozen.new().upgrade(codec.capture(player, account.account_id), account).data


func completed(data: Dictionary) -> void:
	var catalog = Frozen.new().expanded.expanded.quest_catalog
	for id in catalog.ordered_ids():
		data.progress.quests[id] = {
			"state": "completed", "counts": Array(catalog.definitions[id].objective_counts)
		}
		data.progress.reputation += catalog.definitions[id].reward_reputation


func test_v6_frozen_rules_reject_new_region_and_new_fields_before_migration() -> void:
	var conversion = Conversion.new()
	var data := old_snapshot()
	assert_eq(data.content_revision, 2)
	var original := data.duplicate(true)
	var result: Dictionary = conversion.upgrade(data, account)
	assert_true(result.ok)
	assert_eq(result.data.character_save_version, 7)
	assert_eq(data, original)
	data.world.map_id = "gransia"
	assert_eq(conversion.upgrade(data, account).code, "unknown_map")
	data = original.duplicate(true)
	data.progress.travel = {}
	assert_eq(conversion.upgrade(data, account).code, "progress_fields")
	data = original.duplicate(true)
	data.content_revision = 3
	assert_eq(conversion.upgrade(data, account).code, "unsupported_content")


func test_completed_ownership_and_proven_novera_visit_are_initialized_only_once() -> void:
	var conversion = Conversion.new()
	var data := old_snapshot()
	completed(data)
	var result: Dictionary = conversion.upgrade(data, account)
	assert_true(result.ok)
	assert_eq(result.data.progress.territory.representative, "yeoulmok")
	assert_true(result.data.progress.travel.unlocked.has("novera"))
	assert_eq(result.data.progress.travel.return_ms, 0)
	var state: Dictionary = result.data
	state.progress.territory.treasury = 70
	state.progress.travel.return_ms = 500000
	assert_eq(conversion.upgrade(state, account).data, state)
	assert_eq(data.progress.territory, {})


func test_invalid_territory_and_travel_are_not_stripped_without_validation() -> void:
	var conversion = Conversion.new()
	var data: Dictionary = conversion.upgrade(old_snapshot(), account).data
	data.progress.travel.unlocked = ["missing_city"]
	assert_ne(conversion.validate(data, account), "")
	data.progress.travel.unlocked = []
	data.progress.territory.treasury = -1
	assert_ne(conversion.validate(data, account), "")
	data.progress.territory.treasury = 0
	data.progress.territory.holdings = {"yeoulmok": {}}
	assert_ne(conversion.validate(data, account), "")


func test_failed_world_change_does_not_charge_gold_or_start_return_cooldown() -> void:
	var world = load("res://scripts/world/game_product.gd").instantiate_world()
	world.set_meta("save_directory", "user://product_territory_probe")
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var old := old_snapshot()
	completed(old)
	var journal: QuestJournal = world.get_node("QuestController").journal
	assert_eq(journal.restore_state(old.progress.quests), "")
	var actor: Node2D = world.get_node("Player")
	actor.get_node("Inventory").gold = 20000
	var travel: Dictionary = world.get_meta("travel_state")
	if "novera" not in travel.unlocked:
		travel.unlocked.append("novera")
	var before_territory: Dictionary = world.get_meta("territory_state").duplicate(true)
	var before_travel := travel.duplicate(true)
	var session := RejectingSession.new()
	session.world = world
	session.account = world.get_node("SaveSession").account
	var store := AccountStore.new()
	store.account = session.account
	session.store = store
	world.add_child(session)
	assert_eq(session.warp("novera").code, "injected_world_failure")
	assert_lt(session.offered.inventory.gold, 20000)
	assert_eq(actor.get_node("Inventory").gold, 20000)
	assert_eq(world.get_meta("territory_state"), before_territory)
	assert_eq(world.get_meta("travel_state"), before_travel)
	assert_eq(session.warp("", true).code, "injected_world_failure")
	assert_eq(session.offered.progress.travel.return_ms, 900000)
	assert_eq(world.get_meta("travel_state"), before_travel)
	world.free()
	BgmManager.reset()
	await get_tree().process_frame
