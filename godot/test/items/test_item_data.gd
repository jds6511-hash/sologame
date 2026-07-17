## IT-1 스타터 아이템 데이터 검증
## economy-foundation.md 3-1장 표 9종의 공격력/방어력 수치가
## 경제/성장 문서 공식(무기 8+1.6L, 방어구 (5+1.5L)×슬롯비율, 등급 배율)과 일치하는지 확인한다.
## 장신구 주 옵션(3-3장)·신발 이동 속도(3-4장) 확정값도 함께 검증한다.
extends GutTest

const ITEM_DIR := "res://data/items/"


func test_starter_weapon_c_lv1_attack_power() -> void:
	var item: ItemData = load(ITEM_DIR + "wpn_sw_01_c.tres")
	assert_eq(item.item_id, "WPN-SW-01-C")
	assert_eq(item.main_stat_value, 8.0, "(8+1.6*1)*0.85 반올림")


func test_starter_weapon_c_lv10_attack_power() -> void:
	var item: ItemData = load(ITEM_DIR + "wpn_gs_10_c.tres")
	assert_eq(item.main_stat_value, 20.0, "(8+1.6*10)*0.85 반올림")


func test_starter_weapon_b_lv10_attack_power() -> void:
	var item: ItemData = load(ITEM_DIR + "wpn_gs_10_b.tres")
	assert_eq(item.main_stat_value, 24.0, "(8+1.6*10)*1.00")


func test_starter_armor_body_b_lv10_defense() -> void:
	var item: ItemData = load(ITEM_DIR + "arm_body_10_b.tres")
	assert_eq(item.main_stat_value, 8.0, "(5+1.5*10)*0.40*1.00")


func test_starter_armor_leg_c_lv10_defense() -> void:
	var item: ItemData = load(ITEM_DIR + "arm_leg_10_c.tres")
	assert_eq(item.main_stat_value, 4.0, "(5+1.5*10)*0.25*0.85 반올림")


func test_starter_armor_head_c_lv10_defense() -> void:
	var item: ItemData = load(ITEM_DIR + "arm_head_10_c.tres")
	assert_eq(item.main_stat_value, 3.0, "(5+1.5*10)*0.20*0.85 반올림")


func test_starter_armor_foot_c_lv10_defense() -> void:
	var item: ItemData = load(ITEM_DIR + "arm_foot_10_c.tres")
	assert_eq(item.main_stat_value, 3.0, "(5+1.5*10)*0.15*0.85 반올림")


func test_starter_accessory_slots_match_growth_8_slot_structure() -> void:
	var ring: ItemData = load(ITEM_DIR + "acc_ring_10_b.tres")
	var neck: ItemData = load(ITEM_DIR + "acc_neck_10_b.tres")
	assert_eq(ring.equip_slot, ItemData.EquipSlot.RING)
	assert_eq(neck.equip_slot, ItemData.EquipSlot.NECKLACE)


func test_starter_accessory_ring_b_lv10_crit_chance() -> void:
	var item: ItemData = load(ITEM_DIR + "acc_ring_10_b.tres")
	assert_eq(
		item.main_stat_value, 0.28, "3.7 * (10/100) * (1.00/1.32) 반올림 (economy-foundation.md 3-3장)"
	)


func test_starter_accessory_neck_b_lv10_max_hp() -> void:
	var item: ItemData = load(ITEM_DIR + "acc_neck_10_b.tres")
	assert_eq(
		item.main_stat_value, 0.76, "10.0 * (10/100) * (1.00/1.32) 반올림 (economy-foundation.md 3-3장)"
	)


func test_starter_armor_foot_c_move_speed_bonus() -> void:
	var item: ItemData = load(ITEM_DIR + "arm_foot_10_c.tres")
	assert_eq(item.move_speed_bonus, 2.0, "C급 고정값 (economy-foundation.md 3-4장, 레벨 무관)")


func test_all_nine_starter_items_load() -> void:
	var files := [
		"wpn_sw_01_c.tres",
		"wpn_gs_10_c.tres",
		"wpn_gs_10_b.tres",
		"arm_body_10_b.tres",
		"arm_leg_10_c.tres",
		"arm_head_10_c.tres",
		"arm_foot_10_c.tres",
		"acc_ring_10_b.tres",
		"acc_neck_10_b.tres",
	]
	assert_eq(files.size(), 9, "economy-foundation.md 3-1장 표는 9종")
	for file_name in files:
		var item: ItemData = load(ITEM_DIR + file_name)
		assert_not_null(item, "%s 로드 실패" % file_name)
		assert_ne(item.item_id, "", "%s item_id 누락" % file_name)


## economy-foundation.md 3-1장 "Lv1 티어 드랍 세트" 확정(2026-07-17) 10종 검증
func test_lv1_tier_drop_set_ten_items_load_with_correct_stats() -> void:
	var expected := {
		"wpn_gs_01_c.tres": {"id": "WPN-GS-01-C", "stat": 8.0, "price": 12},
		"wpn_gs_01_b.tres": {"id": "WPN-GS-01-B", "stat": 10.0, "price": 36},
		"arm_body_01_c.tres": {"id": "ARM-BODY-01-C", "stat": 2.0, "price": 80},
		"arm_body_01_b.tres": {"id": "ARM-BODY-01-B", "stat": 3.0, "price": 8},
		"arm_leg_01_c.tres": {"id": "ARM-LEG-01-C", "stat": 1.0, "price": 50},
		"arm_leg_01_b.tres": {"id": "ARM-LEG-01-B", "stat": 2.0, "price": 5},
		"arm_head_01_c.tres": {"id": "ARM-HEAD-01-C", "stat": 1.0, "price": 40},
		"arm_head_01_b.tres": {"id": "ARM-HEAD-01-B", "stat": 1.0, "price": 4},
		"arm_foot_01_c.tres": {"id": "ARM-FOOT-01-C", "stat": 1.0, "price": 30},
		"arm_foot_01_b.tres": {"id": "ARM-FOOT-01-B", "stat": 1.0, "price": 3},
	}
	for file_name in expected:
		var item: ItemData = load(ITEM_DIR + file_name)
		var exp: Dictionary = expected[file_name]
		assert_not_null(item, "%s 로드 실패" % file_name)
		assert_eq(item.item_id, exp["id"], file_name)
		assert_eq(item.main_stat_value, exp["stat"], file_name)
		assert_eq(item.price, exp["price"], file_name)
		assert_eq(item.level_limit, 1, file_name)


func test_lv1_tier_foot_armor_move_speed_bonus_matches_grade() -> void:
	var c_item: ItemData = load(ITEM_DIR + "arm_foot_01_c.tres")
	var b_item: ItemData = load(ITEM_DIR + "arm_foot_01_b.tres")
	assert_eq(c_item.move_speed_bonus, 2.0, "C급 고정값 (economy-foundation.md 3-4장)")
	assert_eq(b_item.move_speed_bonus, 3.0, "B급 고정값 (economy-foundation.md 3-4장)")


func test_material_prices_confirmed_per_economy_foundation_2_9() -> void:
	var rabbit: ItemData = load(ITEM_DIR + "mat_rabbit_foot.tres")
	var fang: ItemData = load(ITEM_DIR + "mat_dog_fang.tres")
	var core: ItemData = load(ITEM_DIR + "mat_slime_core.tres")
	assert_eq(rabbit.price, 4, "토끼 발 = 2 x g(1) (economy-foundation.md 2-9장)")
	assert_eq(fang.price, 32, "들개 이빨 = 2 x g(4)")
	assert_eq(core.price, 90, "점액질 핵 = 2 x g(8), 핵파괴 예외에도 단가 불변")
