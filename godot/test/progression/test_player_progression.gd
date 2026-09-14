## M3 B-1 검증 — PlayerProgression의 경험치 누적·레벨업 트리거·다중 레벨업·초과 이월·
## 만렙 처리·처치 경험치 지급(레벨 차·등급·야간 배율)이 m3-leveling-spec.md 3·4장과
## 일치하는지 확인한다.
extends GutTest

const LEVEL_CURVE: LevelCurveData = preload("res://data/progression/level_curve.tres")
const LEVEL_DIFF_CURVE: LevelDiffCurve = preload("res://data/progression/level_diff_curve.tres")

var _prog: PlayerProgression


func before_each() -> void:
	_prog = PlayerProgression.new()
	_prog.level_curve = LEVEL_CURVE
	_prog.level_diff_curve = LEVEL_DIFF_CURVE
	autofree(_prog)


func after_each() -> void:
	GameClock.reset()


# --- 레벨업 임계 (spec 3-2) ---


func test_starts_at_level_1_zero_exp() -> void:
	assert_eq(_prog.current_level, 1)
	assert_eq(_prog.current_exp, 0)


func test_exp_below_threshold_does_not_level_up() -> void:
	var below_threshold := LEVEL_CURVE.req(1) - 1
	_prog.add_exp(below_threshold)
	assert_eq(_prog.current_level, 1)
	assert_eq(_prog.current_exp, below_threshold)


func test_exp_exactly_threshold_levels_up_to_2() -> void:
	_prog.add_exp(LEVEL_CURVE.req(1))
	assert_eq(_prog.current_level, 2)
	assert_eq(_prog.current_exp, 0)


func test_carryover_exp_after_level_up() -> void:
	_prog.add_exp(LEVEL_CURVE.req(1) + 10)
	assert_eq(_prog.current_level, 2)
	assert_eq(_prog.current_exp, 10)


# --- 다중 레벨업 + 초과 이월 (spec 3-2 while 루프) ---


func test_multi_level_up_in_single_gain() -> void:
	var lump := LEVEL_CURVE.req(1) + LEVEL_CURVE.req(2) + LEVEL_CURVE.req(3) + 5
	_prog.add_exp(lump)  ## Lv1 -> Lv4, 이월 5
	assert_eq(_prog.current_level, 4)
	assert_eq(_prog.current_exp, 5)


func test_leveled_up_signal_emitted_per_level() -> void:
	watch_signals(_prog)
	var lump := LEVEL_CURVE.req(1) + LEVEL_CURVE.req(2) + LEVEL_CURVE.req(3)
	_prog.add_exp(lump)
	assert_signal_emit_count(_prog, "leveled_up", 3)
	assert_signal_emitted_with_parameters(_prog, "leveled_up", [4], 2)  ## 마지막 발신 = Lv4


func test_exp_changed_signal_reports_current_and_next() -> void:
	watch_signals(_prog)
	_prog.add_exp(10)
	assert_signal_emitted_with_parameters(_prog, "exp_changed", [10, LEVEL_CURVE.req(1)])


# --- 만렙 처리 (spec 3-2 — 초과 EXP 폐기, 바 만충) ---


func test_max_level_discards_excess_exp() -> void:
	_prog.current_level = LEVEL_CURVE.max_level
	_prog.current_exp = 0
	_prog.add_exp(999999)
	assert_eq(_prog.current_level, LEVEL_CURVE.max_level)
	assert_eq(_prog.current_exp, 0)
	assert_true(_prog.is_max_level())
	assert_eq(_prog.exp_to_next(), 0, "만렙은 다음 레벨 없음 → 0")


func test_reaching_max_level_zeroes_carryover() -> void:
	_prog.current_level = LEVEL_CURVE.max_level - 1  ## Lv99
	_prog.current_exp = 0
	_prog.add_exp(LEVEL_CURVE.req(LEVEL_CURVE.max_level - 1) + 500)  ## Lv100 도달 + 초과
	assert_eq(_prog.current_level, LEVEL_CURVE.max_level)
	assert_eq(_prog.current_exp, 0, "만렙 도달 시 초과분 폐기")


# --- 처치 경험치 계산 (spec 3-1) — 순수 함수 ---


func test_calc_exp_gain_all_multipliers() -> void:
	## 158 x 6(정예) x 1.0 x 1.0 = 948
	assert_eq(PlayerProgression.calc_exp_gain(158, 6.0, 1.0, 1.0), 948)


func test_calc_exp_gain_final_round_only() -> void:
	## 158 x 1 x 1 x 1.2(야간) = 189.6 -> round 190 (최종 1회 반올림)
	assert_eq(PlayerProgression.calc_exp_gain(158, 1.0, 1.0, 1.2), 190)


func test_calc_exp_gain_floor_is_one() -> void:
	## 3 x 1 x 0.1 = 0.3 -> round 0 이지만 최소 1 보장(spec 3-1 하한)
	assert_eq(PlayerProgression.calc_exp_gain(3, 1.0, 0.1, 1.0), 1)


# --- 처치 경험치 지급 (grant_kill_exp) — 낮 기준(GameClock 기본 is_day=true) ---


func test_grant_kill_exp_normal_same_level() -> void:
	## Lv1 플레이어가 Lv1 일반 몹 처치: mob_exp(1)=5, 등급1, d=0(1.0), 낮(1.0) → 5
	_prog.grant_kill_exp(1, DropTableData.MonsterTier.NORMAL)
	assert_eq(_prog.current_exp, 5)


func test_grant_kill_exp_elite_multiplier() -> void:
	## Lv1 플레이어가 Lv1 정예 몹: 5 x 6 = 30 (Lv2 임계 25 통과, 5 이월)
	_prog.grant_kill_exp(1, DropTableData.MonsterTier.ELITE)
	assert_eq(_prog.current_level, 2)
	assert_eq(_prog.current_exp, 5)


func test_grant_kill_exp_applies_level_diff_penalty() -> void:
	## Lv10 플레이어가 Lv5 몹 처치: d=-5 → 배율 0.85. mob_exp(5)=56.
	## round(56 x 1 x 0.85 x 1) = round(47.6) = 48
	_prog.current_level = 10
	_prog.grant_kill_exp(5, DropTableData.MonsterTier.NORMAL)
	assert_eq(_prog.current_exp, 48)


func test_grade_multiplier_maps_tier() -> void:
	assert_eq(_prog.grade_multiplier(DropTableData.MonsterTier.NORMAL), 1.0)
	assert_eq(_prog.grade_multiplier(DropTableData.MonsterTier.ELITE), 6.0)
	assert_eq(_prog.grade_multiplier(DropTableData.MonsterTier.BOSS), 40.0)
