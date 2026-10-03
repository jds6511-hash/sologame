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


func test_one_pickup_collects_neighbors_without_duplicate_or_full_bag_loss() -> void:
	_inventory.bag_capacity = 1
	var same = ITEM_SCENE.instantiate()
	same.item_data = _item.item_data
	same.quantity = 2
	same.position = Vector2(20, 0)
	add_child_autofree(same)
	same.set_process(false)
	same._on_body_entered(_player)
	var other = ITEM_SCENE.instantiate()
	other.item_data = ItemData.new()
	other.item_data.item_id = "OTHER"
	other.position = Vector2(24, 0)
	add_child_autofree(other)
	other.set_process(false)
	other._on_body_entered(_player)
	_item._on_body_entered(_player)
	Input.action_press("interact")
	_item._process(0.0)
	assert_eq(_inventory.get_bag_quantity("PICKUP-TEST"), 3)
	assert_true(same.is_queued_for_deletion())
	assert_false(other.is_queued_for_deletion())
	same._process(0.0)
	assert_eq(_inventory.get_bag_quantity("PICKUP-TEST"), 3)


func test_pickup_area_is_wider() -> void:
	assert_eq(_item.get_node("CollisionShape2D").shape.radius, 24.0)


func test_wall_prevents_remote_pickup_and_prompt() -> void:
	_item.position = Vector2(24, 0)
	var wall := StaticBody2D.new()
	wall.position = Vector2(12, 0)
	wall.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(4, 64)
	collision.shape = shape
	wall.add_child(collision)
	add_child_autofree(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_item._on_body_entered(_player)
	Input.action_press("interact")
	_item._process(0.0)
	assert_eq(_inventory.get_bag_quantity("PICKUP-TEST"), 0)
	assert_false(_item.get_node("PickupPrompt").visible)


func test_only_nearest_prompt_and_no_pickup_outside_distance_or_other_world() -> void:
	_item._on_body_entered(_player)
	var far = ITEM_SCENE.instantiate()
	far.item_data = _item.item_data
	far.position = Vector2(40, 0)
	add_child_autofree(far)
	far.set_process(false)
	far._on_body_entered(_player)
	far._process(0.0)
	assert_false(far.get_node("PickupPrompt").visible)
	var world := Node2D.new()
	add_child_autofree(world)
	var foreign = ITEM_SCENE.instantiate()
	foreign.item_data = _item.item_data
	world.add_child(foreign)
	foreign.set_process(false)
	foreign._on_body_entered(_player)
	Input.action_press("interact")
	_item._process(0.0)
	assert_eq(_inventory.get_bag_quantity("PICKUP-TEST"), 1)
	assert_false(far.is_queued_for_deletion())
	assert_false(foreign.is_queued_for_deletion())
