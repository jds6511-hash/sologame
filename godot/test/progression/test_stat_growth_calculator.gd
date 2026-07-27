## M3 B-2 검증 — StatGrowthCalculator의 1차 스탯·파생 스탯이 m3-leveling-spec.md 2-3장
## 검산표(전사, 동렙 B급 장비 착용)와 정확히 일치하는지 확인한다. 값은 내부 float(정밀값)로
## 검증한다(표시 반올림은 HUD 몫, 내부는 float 유지 — spec 8-1). 궁수는 spec 2-4 스모크 확인.
extends GutTest

const FORMULA: StatGrowthFormula = preload("res://data/progression/stat_growth_formula.tres")
const JOB_WARRIOR: JobGrowthData = preload("res://data/progression/job_growth_warrior.tres")
const JOB_ARCHER: JobGrowthData = preload("res://data/progression/job_growth_archer.tres")
const JOB_ADVENTURER: JobGrowthData = preload("res://data/progression/job_growth_adventurer.tres")
const DAMAGE_FORMULA: DamageFormulaData = preload("res://data/combat/damage_formula.tres")

const TOL := 0.0001

# --- 성장 배분 합 == 6.0 (spec 7-3) ---


func test_all_jobs_growth_sum_is_six() -> void:
	assert_true(JOB_WARRIOR.is_valid(), "전사 배분 합 6.0")
	assert_true(JOB_ARCHER.is_valid(), "궁수 배분 합 6.0")
	assert_true(JOB_ADVENTURER.is_valid(), "모험가 배분 합 6.0")


# --- 1차 스탯 검산 (spec 2-3 전사) ---


func _assert_primary(
	level: int, job: JobGrowthData, s: float, a: float, i: float, v: float
) -> void:
	var p := StatGrowthCalculator.compute_primary(level, job, FORMULA)
	assert_almost_eq(p["str"], s, TOL, "Lv%d 힘" % level)
	assert_almost_eq(p["agi"], a, TOL, "Lv%d 민첩" % level)
	assert_almost_eq(p["int"], i, TOL, "Lv%d 지력" % level)
	assert_almost_eq(p["vit"], v, TOL, "Lv%d 체력" % level)


func test_warrior_primary_stats_checksum() -> void:
	_assert_primary(1, JOB_WARRIOR, 8.0, 8.0, 8.0, 8.0)
	_assert_primary(10, JOB_WARRIOR, 21.5, 21.5, 21.5, 21.5)
	_assert_primary(40, JOB_WARRIOR, 96.5, 51.5, 36.5, 81.5)
	_assert_primary(80, JOB_WARRIOR, 196.5, 91.5, 56.5, 161.5)
	_assert_primary(100, JOB_WARRIOR, 246.5, 111.5, 66.5, 201.5)


func test_primary_total_is_plus_six_per_level() -> void:
	## spec 2-2: 1차 스탯 총합 = 32 + (L-1)x6.0 (직업 무관).
	for level in [1, 10, 40, 80, 100]:
		var p := StatGrowthCalculator.compute_primary(level, JOB_WARRIOR, FORMULA)
		var total: float = p["str"] + p["agi"] + p["int"] + p["vit"]
		assert_almost_eq(total, 32.0 + (level - 1) * 6.0, TOL, "Lv%d 1차 총합" % level)


# --- 파생 스탯 전체 검산 (spec 2-3 전사, 동렙 B급 장비 포함 최종값) ---


func _assert_full(
	level: int, job: JobGrowthData, atk: float, hp: float, dfn: float, mp: float, crit: float
) -> void:
	var stats := CombatantStats.new()
	StatGrowthCalculator.apply(stats, level, job, FORMULA)
	assert_almost_eq(stats.attack_power, atk, TOL, "Lv%d 공격력" % level)
	assert_almost_eq(stats.max_hp, hp, TOL, "Lv%d 최대 HP" % level)
	assert_almost_eq(stats.defense, dfn, TOL, "Lv%d 방어력" % level)
	assert_almost_eq(stats.max_mp, mp, TOL, "Lv%d 최대 MP" % level)
	## 치명타%는 apply가 채운 agility를 DamageCalculator가 공식으로 산출(전투 반영 경로).
	var crit_chance := DamageCalculator.calculate_crit_chance(stats.agility, DAMAGE_FORMULA)
	assert_almost_eq(crit_chance, crit, TOL, "Lv%d 치명타" % level)


func test_warrior_derived_stats_checksum() -> void:
	_assert_full(1, JOB_WARRIOR, 25.6, 135.0, 14.5, 72.0, 0.054)
	_assert_full(10, JOB_WARRIOR, 67.0, 315.0, 41.5, 157.5, 0.06075)
	_assert_full(40, JOB_WARRIOR, 265.0, 1065.0, 146.5, 292.5, 0.07575)
	_assert_full(80, JOB_WARRIOR, 529.0, 2065.0, 286.5, 472.5, 0.09575)
	## 태스크 필수 목표: 전사 Lv100 공격661·HP2565·방어356(.5 내부 float).
	_assert_full(100, JOB_WARRIOR, 661.0, 2565.0, 356.5, 562.5, 0.10575)


func test_archer_derived_stats_smoke() -> void:
	## spec 2-4 궁수 참고표(민첩 주스탯 → 치명타 축이 전사보다 빠르게 성장).
	_assert_full(10, JOB_ARCHER, 67.0, 315.0, 41.5, 157.5, 0.06075)
	_assert_full(15, JOB_ARCHER, 101.0, 415.0, 56.5, 190.0, 0.06725)
	_assert_full(20, JOB_ARCHER, 135.0, 515.0, 71.5, 222.5, 0.07375)


# --- 순수 함수 성질 (spec 5-3) ---


func test_apply_is_idempotent_for_same_level() -> void:
	## 같은 (레벨, 직업)이면 몇 번 호출해도 결과가 동일(누적 가산이 아니라 재계산).
	var a := CombatantStats.new()
	var b := CombatantStats.new()
	StatGrowthCalculator.apply(a, 40, JOB_WARRIOR, FORMULA)
	StatGrowthCalculator.apply(b, 40, JOB_WARRIOR, FORMULA)
	StatGrowthCalculator.apply(b, 40, JOB_WARRIOR, FORMULA)  ## 재호출
	assert_almost_eq(a.attack_power, b.attack_power, TOL)
	assert_almost_eq(a.max_hp, b.max_hp, TOL)
	assert_almost_eq(a.defense, b.defense, TOL)


func test_lv1_matches_existing_snapshot_hp_mp_exactly() -> void:
	## HP/MP는 장비 기여가 없어 Lv1 순수 함수 값이 기존 스냅샷(135/72)과 정확히 일치.
	var stats := CombatantStats.new()
	StatGrowthCalculator.apply(stats, 1, JOB_WARRIOR, FORMULA)
	assert_eq(stats.max_hp, 135.0)
	assert_eq(stats.max_mp, 72.0)
