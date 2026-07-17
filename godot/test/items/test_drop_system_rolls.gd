## IT-2 확률 굴림·슬롯/등급 롤·장비 티어 해석·몬스터 사망 통합 검증. 골드 공식·정책값
## 자체는 test_drop_system_gold.gd 참고(gdlint max-public-methods 20개 제한으로 파일 분리).
extends GutTest

var _rate: DropRateConfig


func before_each() -> void:
	_rate = DropRateConfig.new()


# --- 확률 판정 순수 함수 (Monte Carlo, seed 고정으로 재현 가능) ---


func test_should_drop_material_probability_close_to_30_percent_for_normal_tier() -> void:
	seed(42)
	var hits := 0
	var trials := 20000
	for i in range(trials):
		if DropSystem.should_drop_material(
			_rate, DropTableData.MonsterTier.NORMAL, false, "약", randf()
		):
			hits += 1
	assert_almost_eq(float(hits) / trials, 0.30, 0.02, "2만회 시행, 허용 오차 ±2%p")


func test_should_drop_material_always_true_when_core_break_guarantee_and_strong_hit() -> void:
	for i in range(50):
		assert_true(
			DropSystem.should_drop_material(
				_rate, DropTableData.MonsterTier.NORMAL, true, "강", 0.999
			),
			"핵 파괴(강 등급 마무리)는 확률 굴림과 무관하게 100%"
		)


func test_should_drop_material_not_guaranteed_when_hit_grade_is_not_strong() -> void:
	assert_false(
		DropSystem.should_drop_material(_rate, DropTableData.MonsterTier.NORMAL, true, "약", 0.999)
	)


func test_should_drop_potion_probability_close_to_2_percent_for_normal_tier() -> void:
	seed(7)
	var hits := 0
	var trials := 30000
	for i in range(trials):
		if DropSystem.should_drop_potion(_rate, DropTableData.MonsterTier.NORMAL, randf()):
			hits += 1
	assert_almost_eq(float(hits) / trials, 0.02, 0.01, "3만회 시행, 허용 오차 ±1%p")


# --- 슬롯/등급 롤 (rng 값 주입 — 결정적 경계 테스트) ---


func test_roll_equipment_slot_boundaries() -> void:
	assert_eq(DropSystem.roll_equipment_slot(_rate, 0.0), ItemData.EquipSlot.WEAPON)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 19.99), ItemData.EquipSlot.WEAPON)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 20.01), ItemData.EquipSlot.ARMOR_BODY)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 34.99), ItemData.EquipSlot.ARMOR_BODY)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 35.01), ItemData.EquipSlot.ARMOR_LEG)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 64.99), ItemData.EquipSlot.ARMOR_HEAD)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 79.99), ItemData.EquipSlot.ARMOR_FOOT)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 80.01), ItemData.EquipSlot.RING)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 93.39), ItemData.EquipSlot.RING)
	assert_eq(DropSystem.roll_equipment_slot(_rate, 93.5), ItemData.EquipSlot.NECKLACE)


func test_roll_boss_equipment_grade_boundaries() -> void:
	assert_eq(DropSystem.roll_boss_equipment_grade(_rate, 0.0), ItemData.ItemGrade.B)
	assert_eq(DropSystem.roll_boss_equipment_grade(_rate, 0.69), ItemData.ItemGrade.B)
	assert_eq(DropSystem.roll_boss_equipment_grade(_rate, 0.70), ItemData.ItemGrade.A)
	assert_eq(DropSystem.roll_boss_equipment_grade(_rate, 0.94), ItemData.ItemGrade.A)
	assert_eq(DropSystem.roll_boss_equipment_grade(_rate, 0.95), ItemData.ItemGrade.S)
	assert_eq(DropSystem.roll_boss_equipment_grade(_rate, 0.999), ItemData.ItemGrade.S)


# --- 장비 티어 해석 (2-1장 "자기 레벨 이하의 최고 티어" + jobs.md 5-2 스마트 드랍) ---


func test_resolve_equipment_item_picks_highest_tier_at_or_below_monster_level() -> void:
	var low := ItemData.new()
	low.item_id = "WPN-GS-01-C"
	low.equip_slot = ItemData.EquipSlot.WEAPON
	low.grade = ItemData.ItemGrade.C
	low.level_limit = 1

	var high := ItemData.new()
	high.item_id = "WPN-GS-10-C"
	high.equip_slot = ItemData.EquipSlot.WEAPON
	high.grade = ItemData.ItemGrade.C
	high.level_limit = 10

	var items: Array[ItemData] = [low, high]
	var picked := DropSystem.resolve_equipment_item(
		items, 8, ItemData.ItemGrade.C, ItemData.EquipSlot.WEAPON, "WPN-GS-"
	)
	assert_eq(picked, low, "몬스터 Lv8 이하 최고 티어 = Lv1(Lv10 티어는 레벨 초과라 제외)")


func test_resolve_equipment_item_filters_by_weapon_smart_drop_series() -> void:
	var short_sword := ItemData.new()
	short_sword.item_id = "WPN-SW-01-C"
	short_sword.equip_slot = ItemData.EquipSlot.WEAPON
	short_sword.grade = ItemData.ItemGrade.C
	short_sword.level_limit = 1

	var items: Array[ItemData] = [short_sword]
	var picked := DropSystem.resolve_equipment_item(
		items, 8, ItemData.ItemGrade.C, ItemData.EquipSlot.WEAPON, "WPN-GS-"
	)
	assert_null(picked, "M2 스마트 드랍은 대검(GS) 계열만 허용 — 소검(SW)은 제외")


func test_resolve_equipment_item_returns_null_when_no_candidate() -> void:
	var items: Array[ItemData] = []
	assert_null(
		DropSystem.resolve_equipment_item(
			items, 8, ItemData.ItemGrade.B, ItemData.EquipSlot.ARMOR_BODY, "WPN-GS-"
		)
	)


func test_m2_real_item_data_has_lv1_tier_great_sword() -> void:
	## economy-foundation.md 3-1장 "Lv1 티어 드랍 세트" 확정(2026-07-17)으로 WPN-GS-01-C가
	## data/items/에 추가됨 — M2 3종 몬스터(Lv1/4/8)는 이제 이 Lv1 티어 대검을 드랍할 수
	## 있다. 과거 데이터 공백 기록 테스트(assert_null)를 실제 데이터에 맞게 뒤집었다.
	var dir := DirAccess.open("res://data/items")
	var items: Array[ItemData] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load("res://data/items/%s" % file_name)
			if res is ItemData:
				items.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	var picked := DropSystem.resolve_equipment_item(
		items, 8, ItemData.ItemGrade.C, ItemData.EquipSlot.WEAPON, "WPN-GS-"
	)
	assert_not_null(picked, "Lv1 티어 대검(WPN-GS-01-C)이 존재하므로 드랍 후보가 있어야 함")
	assert_eq(picked.item_id, "WPN-GS-01-C")


# --- 몬스터 사망 → 드랍 시그널 (통합, MonsterBase.died 연동 확인) ---


func test_monster_death_emits_gold_dropped_matching_formula() -> void:
	var drop_system := DropSystem.new()
	drop_system.rate_config = _rate
	add_child_autofree(drop_system)

	var stats := MonsterStatsData.new()
	stats.max_hp = 10.0
	var monster := MonsterBase.new()
	monster.stats = stats
	add_child_autofree(monster)

	var table := DropTableData.new()
	table.monster_level = 1

	watch_signals(drop_system)
	drop_system.register_monster(monster, table)
	monster.take_damage(9999.0)

	assert_signal_emitted(drop_system, "gold_dropped")
	var params: Array = get_signal_parameters(drop_system, "gold_dropped", 0)
	assert_eq(params[0], 2, "Lv1 몬스터 골드 = round(2*1^1.5) = 2")


func test_core_break_guarantees_material_drop_on_strong_hit() -> void:
	var drop_system := DropSystem.new()
	drop_system.rate_config = _rate
	add_child_autofree(drop_system)

	var stats := MonsterStatsData.new()
	stats.max_hp = 10.0
	var monster := MonsterBase.new()
	monster.stats = stats
	add_child_autofree(monster)

	var table := DropTableData.new()
	table.monster_level = 8
	table.material_item_id = "MAT-SLIME-CORE"
	table.core_break_guarantees_material = true

	watch_signals(drop_system)
	drop_system.register_monster(monster, table)
	monster.take_damage(9999.0, "강")

	assert_signal_emitted(drop_system, "item_dropped")
	var params: Array = get_signal_parameters(drop_system, "item_dropped", 0)
	assert_eq(params[0].item_id, "MAT-SLIME-CORE")
	assert_eq(params[1], 1)
