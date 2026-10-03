extends GutTest

const Conversion = preload("res://scripts/save/product_conversion.gd")
const BaseCodec = preload("res://scripts/save/character_save_codec.gd")
const Registry = preload("res://scripts/save/save_content_registry.gd")
const Model = preload("res://scripts/economy/economy_candidate.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
const ProductSave = preload("res://scripts/save/product_save.gd")
var account: Dictionary
var original: Dictionary
var actor: Node2D
var conversion = Conversion.new()


func before_each() -> void:
	var codec = BaseCodec.new()
	account = codec.new_account()
	var player = PLAYER.instantiate()
	actor = player
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector2(152, 504)
	original = codec.capture(player, account.account_id)


func sharpshooter() -> Dictionary:
	var result: Dictionary = conversion.upgrade(original, account)
	assert_true(result.ok)
	var data: Dictionary = result.data
	data.player.level = 40
	data.player.exp = 0
	data.player.job_id = "sharpshooter"
	data.player.skill_points = 42
	data.player.spent_points = 1
	data.player.skill_levels = {"sharpshooter_precision_burst": 2}
	data.player.skill_costs = {"sharpshooter_precision_burst": 1}
	data.player.hp = 1.0
	data.player.mp = 0.0
	data.inventory.equipment = conversion.model.starter(40, "sharpshooter")
	data.inventory.equipment.weapon = "WPN-BW-40-B"
	return data


func test_current_revision_sharpshooter_and_skill_spending_json_roundtrip() -> void:
	var data := sharpshooter()
	assert_eq(conversion.validate(data, account), "")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	assert_eq(conversion.validate(parsed, account), "")
	assert_eq(conversion.upgrade(parsed, account).data, parsed)
	assert_eq(data.progress.quests, {}, "불러오기가 시련 완료를 만들지 않음")


func test_legacy_registry_and_validation_do_not_accept_new_content() -> void:
	assert_false(Registry.new().jobs.has("sharpshooter"))
	assert_false(Registry.new().items.has("WPN-BW-40-B"))
	assert_false(Model.new().job_families.has("sharpshooter"))
	var data := original.duplicate(true)
	data.player.job_id = "sharpshooter"
	assert_eq(conversion.upgrade(data, account).code, "unknown_job")
	var upgraded: Dictionary = conversion.legacy.upgrade(original, account).data
	upgraded.player.job_id = "sharpshooter"
	assert_eq(conversion.upgrade(upgraded, account).code, "unknown_job")


func test_lower_revision_rejects_each_new_content_claim() -> void:
	var data := sharpshooter()
	data.content_revision = 5
	assert_eq(conversion.validate(data, account), "unsupported_content")
	data.player.job_id = "archer"
	assert_eq(conversion.validate(data, account), "unsupported_content")
	data.player.skill_levels = {}
	data.player.skill_costs = {}
	data.player.spent_points = 0
	data.player.skill_points = 41
	assert_eq(conversion.validate(data, account), "unsupported_content")
	data.inventory.equipment.weapon = "WPN-BW-40-C"
	data.inventory.bag.append({"item_id": "WPN-BW-40-B", "quantity": 1})
	assert_eq(conversion.validate(data, account), "unsupported_content")
	data.inventory.bag.pop_back()
	data.inventory.overflow = [{"item_id": "WPN-BW-40-B", "quantity": 1}]
	assert_eq(conversion.validate(data, account), "unsupported_content")
	data.inventory.overflow = []
	assert_eq(conversion.validate(data, account), "")


func test_existing_gladiator_without_trial_remains_valid() -> void:
	var data := sharpshooter()
	data.player.job_id = "gladiator"
	data.player.skill_levels = {}
	data.player.skill_costs = {}
	data.player.spent_points = 0
	data.player.skill_points = 43
	data.inventory.equipment = conversion.model.starter(40, "gladiator")
	data.content_revision = 5
	assert_eq(conversion.validate(data, account), "")
	assert_eq(data.progress.quests, {})


func test_product_codec_restores_job_equipment_and_skill_spending_without_regrant() -> void:
	var data := sharpshooter()
	data.inventory.bag.append({"item_id": "WPN-BW-40-B", "quantity": 1})
	data.inventory.overflow = [{"item_id": "WPN-BW-40-B", "quantity": 1}]
	var codec = ProductSave.Codec.new()
	assert_eq(codec.restore_into(actor, data, account), "")
	assert_eq(actor.get_node("PlayerJobTransition").current_job_id, &"sharpshooter")
	var runtime = actor.get_meta("economy_candidate")
	assert_eq(runtime.state(), data.inventory)
	var captured: Dictionary = codec.capture(actor, account.account_id, data)
	assert_eq(captured.player, data.player)
	assert_eq(captured.inventory, data.inventory)
	assert_eq(codec.schema.character_error(captured, account), "")
	assert_eq(codec.restore_into(actor, data, account), "target_not_fresh")
	assert_eq(runtime.state(), data.inventory, "중복 복원 거부 시 무기를 다시 지급하지 않음")
