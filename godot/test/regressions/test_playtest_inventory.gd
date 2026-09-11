extends GutTest
## 실제 플레이에서 발견한 아이템 소유권·충돌·소비 회귀 검사.
const PLAYER := preload("res://scenes/player/player.tscn")
const POTION := preload("res://data/items/pot_hp_1.tres")


func _item(id: String, slot: ItemData.EquipSlot = ItemData.EquipSlot.WEAPON) -> ItemData:
	var item := ItemData.new()
	item.item_id = id
	item.equip_slot = slot
	return item


func _inventory() -> InventoryComponent:
	var inventory := InventoryComponent.new()
	inventory.bag_capacity = 1
	add_child_autofree(inventory)
	return inventory


func test_full_bag_unequip_keeps_weapon() -> void:
	var inv := _inventory()
	var sword := _item("sword")
	inv.pickup(sword)
	inv.equip(sword)
	inv.pickup(_item("other"))
	assert_null(inv.unequip(ItemData.EquipSlot.WEAPON))
	assert_same(inv.get_equipped(ItemData.EquipSlot.WEAPON), sword)
	assert_eq(inv.get_bag_quantity("other"), 1)


func test_full_bag_stack_swap_is_atomic() -> void:
	var inv := _inventory()
	var first := _item("first")
	var second := _item("second")
	inv.pickup(first)
	inv.equip(first)
	inv.pickup(second, 2)
	assert_false(inv.equip(second))
	assert_same(inv.get_equipped(ItemData.EquipSlot.WEAPON), first)
	assert_eq(inv.get_bag_quantity("second"), 2)


func test_full_bag_single_swap_can_reuse_freed_slot() -> void:
	var inv := _inventory()
	var first := _item("first")
	var second := _item("second")
	inv.pickup(first)
	inv.equip(first)
	inv.pickup(second)
	assert_true(inv.equip(second))
	assert_same(inv.get_equipped(ItemData.EquipSlot.WEAPON), second)
	assert_eq(inv.get_bag_quantity("first"), 1)


func test_full_bag_ring_unequip_keeps_both_slots() -> void:
	var inv := _inventory()
	var ring := _item("ring", ItemData.EquipSlot.RING)
	inv.pickup(ring, 2)
	inv.equip(ring, 0)
	inv.equip(ring, 1)
	inv.pickup(_item("other"))
	assert_null(inv.unequip(ItemData.EquipSlot.RING, 1))
	assert_same(inv.get_equipped(ItemData.EquipSlot.RING, 0), ring)
	assert_same(inv.get_equipped(ItemData.EquipSlot.RING, 1), ring)


func test_nonpositive_drop_never_changes_quantity() -> void:
	var inv := _inventory()
	inv.pickup(_item("first"), 2)
	assert_null(inv.drop_item("first", -2))
	assert_null(inv.drop_item("first", 0))
	assert_eq(inv.get_bag_quantity("first"), 2)


func test_real_item_detects_player_and_preserves_full_bag() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var inv := InventoryComponent.new()
	inv.name = "Inventory"
	inv.bag_capacity = 1
	player.add_child(inv)
	inv.pickup(_item("filler"))
	var drop: WorldItem = load("res://scenes/items/world_item.tscn").instantiate()
	drop.item_data = POTION
	add_child_autofree(drop)
	drop.global_position = player.global_position
	await wait_physics_frames(3)
	assert_true(drop.get_overlapping_bodies().has(player))
	drop._try_pickup()
	assert_false(drop.is_queued_for_deletion())
	inv.drop_item("filler")
	drop._try_pickup()
	assert_true(drop.is_queued_for_deletion())
	assert_eq(inv.get_bag_quantity("POT-HP-1"), 1)


func test_quickslot_consumes_real_potion_amount_only_once() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var inv := InventoryComponent.new()
	inv.name = "Inventory"
	player.add_child(inv)
	var stats := player.get_node("PlayerStats") as PlayerStatsComponent
	stats.set_process(false)
	stats.current_hp = 10.0
	await _press_potion(player)
	assert_eq(stats.current_hp, 10.0, "가방이 비었으면 회복하지 않음")
	inv.pickup(POTION, 2)
	await _press_potion(player)
	assert_eq(stats.current_hp, 110.0, "하급 포션은 고정 100 회복")
	assert_eq(inv.get_bag_quantity("POT-HP-1"), 1)
	await _press_potion(player)
	assert_eq(inv.get_bag_quantity("POT-HP-1"), 1, "쿨다운에는 소비하지 않음")


func _press_potion(player: PlayerController) -> void:
	player.set_physics_process(true)
	var event := InputEventKey.new()
	event.keycode = KEY_5
	event.physical_keycode = KEY_5
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert_true(Input.is_action_pressed("quickslot_1"), "입력 사전 조건")
	await wait_physics_frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	player.set_physics_process(false)


func test_quickslot_uses_lowest_usable_tier_and_rejects_wrong_type() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var inv := InventoryComponent.new()
	inv.name = "Inventory"
	player.add_child(inv)
	var stats := player.get_node("PlayerStats") as PlayerStatsComponent
	var medium: ItemData = load("res://data/items/pot_hp_2.tres")
	inv.pickup(medium)
	assert_null(inv.get_quickslot_potion(), "Lv1은 중급 포션을 선택할 수 없음")
	assert_false(inv.use_potion(medium.item_id, stats))
	assert_eq(inv.get_bag_quantity(medium.item_id), 1)
	var material := _item("material", ItemData.EquipSlot.NONE)
	material.heal_amount = 100.0
	inv.pickup(material)
	assert_false(inv.use_potion(material.item_id, stats), "회복량을 가진 비포션도 거절")
	inv.pickup(POTION)
	player.get_node("PlayerProgression").current_level = 30
	assert_same(inv.get_quickslot_potion(), POTION, "상급을 먼저 획득해도 하급부터 소비")
	inv.drop_item(POTION.item_id)
	assert_same(inv.get_quickslot_potion(), medium)


func test_direct_potion_api_rejects_zero_quantity_entry() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	var inv := InventoryComponent.new()
	inv.name = "Inventory"
	player.add_child(inv)
	inv.bag.append({"item": POTION, "quantity": 0})
	var stats := player.get_node("PlayerStats") as PlayerStatsComponent
	stats.current_hp = 10.0
	assert_false(inv.use_potion(POTION.item_id, stats))
	assert_eq(stats.current_hp, 10.0)
