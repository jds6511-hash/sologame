## M3 B-1 검증 — 배포된 level_curve.tres의 REQ(L)·EXP(L)가 m3-leveling-spec.md 2장
## 검산표 수치와 정확히 일치하는지 확인한다(공식 + 배포 계수 동시 검증). 대표 레벨
## 1/10/20/40/80/99/100을 검산한다.
extends GutTest

const LEVEL_CURVE: LevelCurveData = preload("res://data/progression/level_curve.tres")

# --- REQ(L) = round(55 x L^2.5 x 초반 배율), spec 2-2 표 ---


func test_req_representative_levels_match_spec() -> void:
	## {레벨: spec 2-2 REQ 값}
	var expected := {1: 25, 2: 140, 3: 386, 9: 6014, 10: 17393, 20: 98387}
	for level: int in expected:
		assert_eq(LEVEL_CURVE.req(level), expected[level], "REQ(%d)" % level)


func test_first_transition_uses_early_curve_only_before_level_10() -> void:
	assert_eq(LEVEL_CURVE.first_transition_level, 10)
	assert_almost_eq(LEVEL_CURVE.pre_transition_req_multiplier, 0.45, 0.001)
	assert_eq(LEVEL_CURVE.req(9), 6014, "Lv9 -> Lv10은 초반 배율 적용")
	assert_eq(LEVEL_CURVE.req(10), 17393, "Lv10 이후는 기존 곡선 복귀")


func test_cumulative_exp_to_first_transition_matches_spec() -> void:
	var total := 0
	for level in range(1, LEVEL_CURVE.first_transition_level):
		total += LEVEL_CURVE.req(level)
	assert_eq(total, 18612, "Lv10 도달 누적 경험치")


func test_req_band_levels_match_spec() -> void:
	## spec 2-2 밴드 참고값(40 2차 전직·80 3차 전직·99 마지막 곡선값).
	assert_eq(LEVEL_CURVE.req(40), 556561, "REQ(40)")
	assert_eq(LEVEL_CURVE.req(80), 3148384, "REQ(80)")
	assert_eq(LEVEL_CURVE.req(99), 5363530, "REQ(99)")


# --- EXP(L) = round(5 x L^1.5), spec 2-2 표 "동렙 몹 EXP" ---


func test_mob_exp_representative_levels_match_spec() -> void:
	var expected := {1: 5, 2: 14, 3: 26, 10: 158, 20: 447, 40: 1265, 80: 3578, 100: 5000}
	for level: int in expected:
		assert_eq(LEVEL_CURVE.mob_exp(level), expected[level], "EXP(%d)" % level)


# --- 누적 도달 경험치(spec 2-2 "누적 EXP") — 만렙 도달 총합 검산 ---


func test_cumulative_exp_to_max_level_matches_spec() -> void:
	var total := 0
	for level in range(1, LEVEL_CURVE.max_level):  ## 1..99 합
		total += LEVEL_CURVE.req(level)
	assert_eq(total, 154381573, "Lv100 도달 누적 경험치")


# --- 계수/지수 데이터 구동 확인(D-2 페이스 레버가 코드 수정 없이 먹히는지) ---


func test_req_is_driven_by_coefficient_and_exponent() -> void:
	var curve := LevelCurveData.new()
	curve.req_coefficient = 100.0
	curve.req_exponent = 2.0
	assert_eq(curve.req(10), 10000, "req = round(100 x 10^2)")


func test_shipped_max_level_is_100() -> void:
	assert_eq(LEVEL_CURVE.max_level, 100)
