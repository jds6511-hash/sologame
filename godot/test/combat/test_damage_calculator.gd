## CB-3 검증 — 데미지 공식(combat.md 6장)이 문서 수치를 그대로 재현하는지 확인.
## 방어 감산(제산형)·치명타 배율·위치 보정·치명타 확률 공식을 각각 검증하고,
## growth.md 2-2장(플레이어 Lv1 공격력 26) x m2-monster-spec.md 3-1장(뿔토끼 방어력 0.5)
## 조합으로 실제 몬스터 스펙에 데미지 공식을 적용한 값까지 재현한다.
extends GutTest

var _formula: DamageFormulaData


func before_each() -> void:
	_formula = load("res://data/combat/damage_formula.tres")


func test_defense_reduction_is_divisive_not_subtractive() -> void:
	## 방어력 100일 때 100/(100+100) = 0.5배 — 감산형(공격-방어)이 아님을 확인.
	var damage := DamageCalculator.calculate_damage(10.0, 1.0, 100.0, _formula, false, false, 1.0)
	assert_almost_eq(damage, 5.0, 0.0001)


func test_zero_defense_deals_full_attack_power_x_coefficient() -> void:
	var damage := DamageCalculator.calculate_damage(10.0, 2.0, 0.0, _formula, false, false, 1.0)
	assert_almost_eq(damage, 20.0, 0.0001)


func test_critical_hit_multiplies_by_1_5() -> void:
	var damage := DamageCalculator.calculate_damage(100.0, 1.0, 0.0, _formula, true, false, 1.0)
	assert_almost_eq(damage, 150.0, 0.0001)


func test_backattack_multiplies_by_1_15() -> void:
	var damage := DamageCalculator.calculate_damage(100.0, 1.0, 0.0, _formula, false, true, 1.0)
	assert_almost_eq(damage, 115.0, 0.0001)


func test_frontal_attack_multiplier_is_1_0() -> void:
	var damage := DamageCalculator.calculate_damage(100.0, 1.0, 0.0, _formula, false, false, 1.0)
	assert_almost_eq(damage, 100.0, 0.0001)


func test_random_variance_forced_value_is_used_as_is() -> void:
	var damage := DamageCalculator.calculate_damage(100.0, 1.0, 0.0, _formula, false, false, 0.95)
	assert_almost_eq(damage, 95.0, 0.0001)


func test_random_variance_auto_roll_stays_within_0_95_to_1_05() -> void:
	for i in range(50):
		var variance := DamageCalculator.roll_random_variance(_formula)
		assert_between(variance, 0.95, 1.05)


func test_crit_chance_formula_base_5_percent_plus_agility() -> void:
	## 5% + 민첩(8) x 0.05% = 5.4% (Lv1 전사 growth.md 2-2장 힘/체력 8 기준 스탯 세트 가정)
	var chance := DamageCalculator.calculate_crit_chance(8.0, _formula)
	assert_almost_eq(chance, 0.054, 0.0001)


func test_crit_chance_is_capped_at_40_percent() -> void:
	var chance := DamageCalculator.calculate_crit_chance(100000.0, _formula)
	assert_almost_eq(chance, 0.40, 0.0001)


func test_roll_critical_never_true_when_chance_is_zero() -> void:
	assert_false(DamageCalculator.roll_critical(0.0))


func test_roll_critical_always_true_when_chance_is_one() -> void:
	assert_true(DamageCalculator.roll_critical(1.0))


func test_reproduces_player_lv1_vs_rabbit_from_design_docs() -> void:
	## growth.md 2-2장: Lv1 전사 공격력 26 / m2-monster-spec.md 3-1장: 뿔토끼 방어력 0.5.
	## 기본 공격 1타(계수 1.0), 치명타·후방 없음, 랜덤 보정 없음(1.0) 가정.
	var damage := DamageCalculator.calculate_damage(26.0, 1.0, 0.5, _formula, false, false, 1.0)
	assert_almost_eq(damage, 26.0 * (100.0 / 100.5), 0.001)
	assert_almost_eq(damage, 25.8706, 0.001)
