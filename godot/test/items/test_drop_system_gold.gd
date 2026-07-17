## IT-2 골드 공식·드랍률 정책값 검증 (QA-2 기반) — economy-foundation.md 1-1·1-2·2-5장
## 수치와 drop_rate_config.gd의 구현치가 일치하는지 확인한다. 롤 로직·통합 테스트는
## test_drop_system_rolls.gd 참고(gdlint max-public-methods 20개 제한으로 파일 분리).
extends GutTest

var _rate: DropRateConfig


func before_each() -> void:
	_rate = DropRateConfig.new()


# --- 골드 공식 (1-1·1-2장) ---


func test_gold_formula_matches_reference_table() -> void:
	## economy-foundation.md 1-2장 조견표
	var table := {
		1: 2,
		5: 22,
		10: 63,
		20: 179,
		30: 329,
		40: 506,
		50: 707,
		60: 930,
		70: 1171,
		80: 1431,
		90: 1708,
		100: 2000,
	}
	for level in table:
		assert_eq(
			DropSystem.calc_gold(level, DropTableData.MonsterTier.NORMAL, _rate),
			table[level],
			"L=%d" % level
		)


func test_gold_elite_multiplier_is_6x() -> void:
	assert_eq(DropSystem.calc_gold(10, DropTableData.MonsterTier.ELITE, _rate), 63 * 6)


func test_gold_boss_multiplier_is_40x() -> void:
	assert_eq(DropSystem.calc_gold(10, DropTableData.MonsterTier.BOSS, _rate), 63 * 40)


func test_gold_boss_repeat_kill_applies_half_multiplier() -> void:
	var first := DropSystem.calc_gold(10, DropTableData.MonsterTier.BOSS, _rate, false)
	var repeat := DropSystem.calc_gold(10, DropTableData.MonsterTier.BOSS, _rate, true)
	assert_eq(repeat, roundi(first * 0.5))


func test_m2_monster_gold_matches_monster_spec_table() -> void:
	## m2-monster-spec.md 4장: 뿔토끼 2골드 / 들개 마수 16골드 / 균열 점액 45골드
	assert_eq(DropSystem.calc_gold(1, DropTableData.MonsterTier.NORMAL, _rate), 2)
	assert_eq(DropSystem.calc_gold(4, DropTableData.MonsterTier.NORMAL, _rate), 16)
	assert_eq(DropSystem.calc_gold(8, DropTableData.MonsterTier.NORMAL, _rate), 45)


# --- 드랍률 표 (2-5장) 정책값 일치 확인 ---


func test_drop_rate_config_matches_economy_document_normal_row() -> void:
	assert_eq(_rate.material_chance_normal, 0.30)
	assert_eq(_rate.potion_chance_normal, 0.02)
	assert_eq(_rate.equip_c_chance_normal, 0.04)
	assert_eq(_rate.equip_b_chance_normal, 0.015)
	assert_eq(_rate.equip_a_chance_normal, 0.0015)
	assert_eq(_rate.equip_s_chance_normal, 0.0)


func test_drop_rate_config_matches_economy_document_elite_row() -> void:
	assert_eq(_rate.material_chance_elite, 1.0)
	assert_eq(_rate.material_count_elite, 2)
	assert_eq(_rate.potion_chance_elite, 0.20)
	assert_eq(_rate.equip_c_chance_elite, 0.12)
	assert_eq(_rate.equip_b_chance_elite, 0.08)
	assert_eq(_rate.equip_a_chance_elite, 0.012)
	assert_eq(_rate.equip_s_chance_elite, 0.0005)


func test_drop_rate_config_matches_economy_document_boss_row() -> void:
	assert_eq(_rate.material_count_boss, 4)
	assert_eq(_rate.potion_count_boss, 3)
	assert_eq(_rate.equip_boss_chance_b, 0.70)
	assert_eq(_rate.equip_boss_chance_a, 0.25)
	assert_eq(_rate.equip_boss_chance_s, 0.05)
	assert_almost_eq(
		_rate.equip_boss_chance_b + _rate.equip_boss_chance_a + _rate.equip_boss_chance_s,
		1.0,
		0.0001
	)


func test_slot_weight_distribution_matches_2_5_percentages() -> void:
	assert_almost_eq(DropSystem.total_slot_weight(_rate), 100.1, 0.001, "20+15x4+6.7x3")
