extends GutTest

const ITEM_SCENE = preload("res://scenes/items/world_item.tscn")

var _player: Node2D
var _inventory: InventoryComponent
var _item: WorldItem


func before_each() -> void:
	_player = Node2D.new()
	_inventory = InventoryComponent.new()
	_inventory.name = "Inventory"
	_player.add_child(_inventory)
	add_child_autofree(_player)
	_item = ITEM_SCENE.instantiate()
	_item.item_data = ItemData.new()
	_item.item_data.item_id = "PICKUP-TEST"
	add_child_autofree(_item)
	_item.set_process(false)


func after_each() -> void:
	Input.action_release("interact")
	await get_tree().process_frame


func test_npc_priority_hides_prompt_and_blocks_pickup_on_entry() -> void:
	_player.set_meta("world_interaction_available", true)
	_item._on_body_entered(_player)
	assert_false(_item.get_node("PickupPrompt").visible)
	Input.action_press("interact")
	_item._process(0.0)
	assert_false(_item.get_node("PickupPrompt").visible)
	assert_eq(_inventory.get_bag_quantity("PICKUP-TEST"), 0)
	assert_false(_item.is_queued_for_deletion())


func test_prompt_tracks_npc_priority_without_overlap_reentry() -> void:
	_item._on_body_entered(_player)
	assert_true(_item.get_node("PickupPrompt").visible)
	_player.set_meta("world_interaction_available", true)
	_item._process(0.0)
	assert_false(_item.get_node("PickupPrompt").visible)
	_player.set_meta("world_interaction_available", false)
	_item._process(0.0)
	assert_true(_item.get_node("PickupPrompt").visible)
	Input.action_press("interact")
	_item._process(0.0)
	assert_eq(_inventory.get_bag_quantity("PICKUP-TEST"), 1)
	assert_true(_item.is_queued_for_deletion())


func test_leaving_overlap_keeps_prompt_hidden_after_npc_priority_ends() -> void:
	_item._on_body_entered(_player)
	_player.set_meta("world_interaction_available", true)
	_item._process(0.0)
	_item._on_body_exited(_player)
	_player.set_meta("world_interaction_available", false)
	_item._process(0.0)
	assert_false(_item.get_node("PickupPrompt").visible)
