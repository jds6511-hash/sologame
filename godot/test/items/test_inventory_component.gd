## IT-3 인벤토리 최소 기능 검증 — 줍기·장착·버리기 + 장착 스탯 반영(growth.md 3장 8슬롯),
## PlayerStatsComponent.use_potion()과의 연동을 확인한다.
extends GutTest

var _inv: InventoryComponent
var _stats: CombatantStats

var _sword: ItemData
var _ring_a: ItemData
var _ring_b: ItemData
var _neck: ItemData
var _armor: ItemData


func before_each() -> void:
	_stats = CombatantStats.new()
	_stats.attack_power = 10.0
	_stats.defense = 5.0
	_stats.max_hp = 100.0
	_stats.max_mp = 50.0

	_inv = InventoryComponent.new()
	_inv.combat_stats = _stats
	add_child_autofree(_inv)

	_sword = ItemData.new()
	_sword.item_id = "WPN-TEST-1"
	_sword.equip_slot = ItemData.EquipSlot.WEAPON
	_sword.main_stat_type = ItemData.MainStatType.ATTACK_POWER
	_sword.main_stat_value = 20.0

	_armor = ItemData.new()
	_armor.item_id = "ARM-TEST-BODY"
	_armor.equip_slot = ItemData.EquipSlot.ARMOR_BODY
	_armor.main_stat_type = ItemData.MainStatType.DEFENSE
	_armor.main_stat_value = 8.0

	_ring_a = ItemData.new()
	_ring_a.item_id = "ACC-TEST-RING-A"
	_ring_a.equip_slot = ItemData.EquipSlot.RING
	_ring_a.main_stat_type = ItemData.MainStatType.CRIT_CHANCE
	_ring_a.main_stat_value = 3.0

	_ring_b = ItemData.new()
	_ring_b.item_id = "ACC-TEST-RING-B"
	_ring_b.equip_slot = ItemData.EquipSlot.RING
	_ring_b.main_stat_type = ItemData.MainStatType.CRIT_CHANCE
	_ring_b.main_stat_value = 3.0

	_neck = ItemData.new()
	_neck.item_id = "ACC-TEST-NECK"
	_neck.equip_slot = ItemData.EquipSlot.NECKLACE
	_neck.main_stat_type = ItemData.MainStatType.MAX_HP
	_neck.main_stat_value = 10.0  ## +10%


# --- 줍기 ---


func test_pickup_adds_item_to_bag() -> void:
	assert_true(_inv.pickup(_sword))
	assert_eq(_inv.get_bag_quantity("WPN-TEST-1"), 1)


func test_pickup_stacks_existing_item_quantity() -> void:
	_inv.pickup(_sword, 1)
	_inv.pickup(_sword, 2)
	assert_eq(_inv.get_bag_quantity("WPN-TEST-1"), 3)


func test_pickup_fails_when_bag_is_full() -> void:
	_inv.bag_capacity = 1
	_inv.pickup(_sword)
	var other := ItemData.new()
	other.item_id = "WPN-TEST-2"
	watch_signals(_inv)
	assert_false(_inv.pickup(other))
	assert_signal_emitted(_inv, "inventory_full")


func test_pickup_world_item_adds_to_bag_and_frees_world_item() -> void:
	var world_item := WorldItem.new()
	world_item.item_data = _sword
	world_item.quantity = 1
	add_child_autofree(world_item)

	assert_true(_inv.pickup_world_item(world_item))
	assert_eq(_inv.get_bag_quantity("WPN-TEST-1"), 1)


# --- 장착/해제 (8슬롯, 스탯 반영) ---


func test_equip_requires_item_in_bag_first() -> void:
	assert_false(_inv.equip(_sword), "가방에 없는 아이템은 장착 실패해야 함")


func test_equip_weapon_removes_from_bag_and_adds_attack_power() -> void:
	_inv.pickup(_sword)
	assert_true(_inv.equip(_sword))
	assert_eq(_inv.get_bag_quantity("WPN-TEST-1"), 0, "장착 시 가방에서 빠져야 함")
	assert_eq(_stats.attack_power, 30.0, "기본 10 + 무기 20")


func test_equip_armor_adds_defense() -> void:
	_inv.pickup(_armor)
	_inv.equip(_armor)
	assert_eq(_stats.defense, 13.0, "기본 5 + 방어구 8")


func test_unequip_restores_base_stats_and_returns_item_to_bag() -> void:
	_inv.pickup(_sword)
	_inv.equip(_sword)
	var removed := _inv.unequip(ItemData.EquipSlot.WEAPON)
	assert_eq(removed, _sword)
	assert_eq(_stats.attack_power, 10.0, "해제 후 기본값 복귀")
	assert_eq(_inv.get_bag_quantity("WPN-TEST-1"), 1, "해제한 아이템은 가방으로 돌아와야 함")


func test_equip_replacing_weapon_returns_previous_item_to_bag() -> void:
	var sword2 := ItemData.new()
	sword2.item_id = "WPN-TEST-2"
	sword2.equip_slot = ItemData.EquipSlot.WEAPON
	sword2.main_stat_type = ItemData.MainStatType.ATTACK_POWER
	sword2.main_stat_value = 5.0

	_inv.pickup(_sword)
	_inv.pickup(sword2)
	_inv.equip(_sword)
	_inv.equip(sword2)

	assert_eq(_inv.get_equipped(ItemData.EquipSlot.WEAPON), sword2)
	assert_eq(_inv.get_bag_quantity("WPN-TEST-1"), 1, "이전 무기는 가방으로 돌아와야 함")
	assert_eq(_stats.attack_power, 15.0, "기본 10 + 5(sword2)")


func test_equip_two_rings_into_separate_slots() -> void:
	_inv.pickup(_ring_a)
	_inv.pickup(_ring_b)
	assert_true(_inv.equip(_ring_a, 0))
	assert_true(_inv.equip(_ring_b, 1))
	assert_eq(_inv.get_equipped(ItemData.EquipSlot.RING, 0), _ring_a)
	assert_eq(_inv.get_equipped(ItemData.EquipSlot.RING, 1), _ring_b)
	assert_eq(_inv.get_total_crit_chance_bonus_percent(), 6.0, "반지 2개 각 +3%p 합산")


func test_equip_necklace_applies_max_hp_as_percentage_of_base() -> void:
	## economy-foundation.md 3-3장: main_stat_value는 증가율(%)로 저장 — 절댓값 아님.
	_inv.pickup(_neck)
	_inv.equip(_neck)
	assert_almost_eq(_stats.max_hp, 110.0, 0.001, "기본 100 x (1 + 10/100)")


func test_unequip_necklace_restores_original_max_hp() -> void:
	_inv.pickup(_neck)
	_inv.equip(_neck)
	_inv.unequip(ItemData.EquipSlot.NECKLACE)
	assert_eq(_stats.max_hp, 100.0)


# --- 버리기 ---


func test_drop_item_removes_from_bag_and_returns_item() -> void:
	_inv.pickup(_sword)
	var dropped := _inv.drop_item("WPN-TEST-1", 1)
	assert_eq(dropped, _sword)
	assert_eq(_inv.get_bag_quantity("WPN-TEST-1"), 0)


func test_drop_item_fails_when_quantity_insufficient() -> void:
	_inv.pickup(_sword, 1)
	assert_null(_inv.drop_item("WPN-TEST-1", 2))
	assert_eq(_inv.get_bag_quantity("WPN-TEST-1"), 1, "실패 시 수량 변화 없어야 함")


# --- 골드 ---


func test_add_and_spend_gold() -> void:
	_inv.add_gold(100)
	assert_eq(_inv.gold, 100)
	assert_true(_inv.spend_gold(40))
	assert_eq(_inv.gold, 60)


func test_spend_gold_fails_when_insufficient() -> void:
	_inv.add_gold(10)
	assert_false(_inv.spend_gold(20))
	assert_eq(_inv.gold, 10)


# --- 포션 사용 연동 (combat.md 5-4장 CB-5의 짝) ---


func test_use_potion_decrements_bag_on_success() -> void:
	var potion := ItemData.new()
	potion.item_id = "POT-HP-1"
	_inv.pickup(potion)

	var parent := Node2D.new()
	var player_stats := PlayerStatsComponent.new()
	player_stats.stats = _stats
	player_stats.recovery_rules = PlayerRecoveryRules.new()
	parent.add_child(player_stats)
	add_child_autofree(parent)

	assert_true(_inv.use_potion("POT-HP-1", player_stats))
	assert_eq(_inv.get_bag_quantity("POT-HP-1"), 0)


func test_use_potion_fails_when_not_in_bag() -> void:
	var parent := Node2D.new()
	var player_stats := PlayerStatsComponent.new()
	player_stats.stats = _stats
	player_stats.recovery_rules = PlayerRecoveryRules.new()
	parent.add_child(player_stats)
	add_child_autofree(parent)

	assert_false(_inv.use_potion("POT-HP-1", player_stats))
