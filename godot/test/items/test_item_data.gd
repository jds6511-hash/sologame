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
