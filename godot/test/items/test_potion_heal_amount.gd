## 포션 고정 회복량 검증 (economy-foundation.md 5-1장 포션 4티어 표).
##
## 회복량이 ItemData.heal_amount 데이터로 들어오고, 실제 사용 시 그 절댓값으로 회복되는지
## 확인한다. 5-1장의 설계 의도("고정치 + 레벨 제한"으로 저레벨의 상급 포션 과회복 차단)가
## 실효화됐는지도 함께 본다 — 최대 HP가 큰 상태에서 하급 포션이 30%가 아니라 100만 회복해야 한다.
extends GutTest

const POT_HP_1_PATH := "res://data/items/pot_hp_1.tres"
const POT_HP_2_PATH := "res://data/items/pot_hp_2.tres"

var _stats: CombatantStats


func before_each() -> void:
	_stats = CombatantStats.new()
	_stats.max_hp = 2000.0
	_stats.max_mp = 100.0


# --- 데이터 값 (economy-foundation.md 5-1장 표) ---


func test_pot_hp_1_data_matches_spec() -> void:
	var potion: ItemData = load(POT_HP_1_PATH)
	assert_eq(potion.heal_amount, 100.0, "하급 회복 포션 = 회복량 100")
	assert_eq(potion.level_limit, 1)


func test_pot_hp_2_data_matches_spec() -> void:
	var potion: ItemData = load(POT_HP_2_PATH)
	assert_eq(potion.heal_amount, 320.0, "중급 회복 포션 = 회복량 320")
	assert_eq(potion.level_limit, 30)


# --- 실제 사용 시 회복량 적용 ---


func test_use_potion_heals_data_amount() -> void:
	var player_stats := _make_player_stats()
	player_stats.current_hp = 500.0
	var inv := _make_inventory_with(load(POT_HP_2_PATH))

	assert_true(inv.use_potion("POT-HP-2", player_stats))
	assert_eq(player_stats.current_hp, 820.0, "500 + 데이터 회복량 320")


func test_lower_tier_potion_does_not_overheal_at_high_max_hp() -> void:
	## 최대 HP 2000에서 하급 포션은 30%(600)가 아니라 고정 100만 회복해야 한다.
	var player_stats := _make_player_stats()
	player_stats.current_hp = 500.0
	var inv := _make_inventory_with(load(POT_HP_1_PATH))

	assert_true(inv.use_potion("POT-HP-1", player_stats))
	assert_eq(player_stats.current_hp, 600.0, "500 + 고정 100 (비율 회복 600이 아님)")


func test_heal_is_clamped_to_max_hp() -> void:
	var player_stats := _make_player_stats()
	player_stats.current_hp = 1900.0
	var inv := _make_inventory_with(load(POT_HP_2_PATH))

	assert_true(inv.use_potion("POT-HP-2", player_stats))
	assert_eq(player_stats.current_hp, 2000.0, "최대 HP를 넘지 않음")


func test_potion_without_heal_amount_is_rejected() -> void:
	## 회복량 없는 아이템이 비율 회복으로 우회되지 않도록 거절한다.
	var potion := ItemData.new()
	potion.item_id = "POT-HP-TEST"
	potion.item_type = ItemData.ItemType.POTION
	var player_stats := _make_player_stats()
	player_stats.current_hp = 500.0
	var inv := _make_inventory_with(potion)

	assert_false(inv.use_potion("POT-HP-TEST", player_stats))
	assert_eq(player_stats.current_hp, 500.0)
	assert_eq(inv.get_bag_quantity("POT-HP-TEST"), 1)


func _make_player_stats() -> PlayerStatsComponent:
	var parent := Node2D.new()
	var player_stats := PlayerStatsComponent.new()
	player_stats.stats = _stats
	player_stats.recovery_rules = PlayerRecoveryRules.new()
	parent.add_child(player_stats)
	add_child_autofree(parent)
	return player_stats


func _make_inventory_with(potion: ItemData) -> InventoryComponent:
	var parent := Node.new()
	add_child_autofree(parent)
	var progression := PlayerProgression.new()
	progression.name = "PlayerProgression"
	progression.current_level = 30
	parent.add_child(progression)
	var inv := InventoryComponent.new()
	parent.add_child(inv)
	inv.pickup(potion)
	return inv
