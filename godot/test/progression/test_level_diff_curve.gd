## M3 B-1 검증 — 배포된 level_diff_curve.tres의 레벨 차 배율이 m3-leveling-spec.md 4장
## 표와 정확히 일치하는지 확인한다. d = 몬스터 레벨 - 플레이어 레벨.
extends GutTest

const LEVEL_DIFF_CURVE: LevelDiffCurve = preload("res://data/progression/level_diff_curve.tres")


func test_multiplier_matches_spec_table() -> void:
	## {d: spec 4장 배율}
	var expected := {
		10: 1.2,  ## +5 이상 상한
		5: 1.2,
		4: 1.0,  ## 중립 상단 경계
		0: 1.0,
		-4: 1.0,  ## 중립 하단 경계
		-5: 0.85,
		-6: 0.7,
		-7: 0.55,
		-8: 0.4,
		-9: 0.25,
		-10: 0.1,  ## 바닥 진입
		-20: 0.1,  ## 바닥 유지
	}
	for d: int in expected:
		assert_almost_eq(LEVEL_DIFF_CURVE.multiplier(d), float(expected[d]), 0.0001, "d=%d" % d)
