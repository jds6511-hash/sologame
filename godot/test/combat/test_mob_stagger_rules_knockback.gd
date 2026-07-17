## M2 Phase3 검증 — combat.md 5-2-1장(2026-07-17 신설) 잡몹 넉백 거리 체급별 표가
## MobStaggerRules 데이터(.tres)에 정확히 반영됐는지 확인한다.
extends GutTest

const STANDARD_RULES: MobStaggerRules = preload("res://data/combat/mob_stagger_rules.tres")
const LIGHT_RULES: MobStaggerRules = preload("res://data/combat/mob_stagger_rules_light.tres")
const HEAVY_RULES: MobStaggerRules = preload("res://data/combat/mob_stagger_rules_heavy.tres")


func test_standard_weight_preset_matches_wolf_baseline() -> void:
	assert_eq(STANDARD_RULES.light_knockback_tiles, 0.2, "표준 체급(들개 마수) 일반 타격 넉백")
	assert_eq(STANDARD_RULES.heavy_knockback_tiles, 0.45, "표준 체급 강타·치명타 넉백")


func test_light_weight_preset_matches_rabbit() -> void:
	assert_eq(LIGHT_RULES.light_knockback_tiles, 0.3, "경량 체급(뿔토끼) 일반 타격 넉백 = 표준x1.5")
	assert_eq(LIGHT_RULES.heavy_knockback_tiles, 0.7, "경량 체급 강타·치명타 넉백 ≈ 표준x1.5")


func test_heavy_weight_preset_matches_rift_slime() -> void:
	assert_eq(HEAVY_RULES.light_knockback_tiles, 0.1, "중량 체급(균열 점액) 일반 타격 넉백 = 표준x0.5")
	assert_eq(HEAVY_RULES.heavy_knockback_tiles, 0.25, "중량 체급 강타·치명타 넉백 ≈ 표준x0.5")


func test_standard_preset_stays_below_player_light_knockback_of_0_5_tiles() -> void:
	## combat.md 5-2-1장 기준값(표준 체급)에 대한 제약: "절대값은 작게 유지하고(플레이어
	## 피격 넉백 0.5타일보다 항상 작음)". 체급별 저항 계수를 곱한 경량 강타(0.7)는 문서
	## 표에도 명시된 대로 이 제약을 넘어선다 — 표준 기준값에만 적용되는 제약이다.
	assert_lt(STANDARD_RULES.light_knockback_tiles, 0.5)
	assert_lt(STANDARD_RULES.heavy_knockback_tiles, 0.5)


func test_stagger_timing_is_shared_across_weight_classes() -> void:
	## 경직 시간은 체급 무관 공통(5-2장) — 넉백 거리만 체급별로 다르다.
	for rules in [LIGHT_RULES, HEAVY_RULES]:
		assert_eq(rules.light_stagger_sec, STANDARD_RULES.light_stagger_sec)
		assert_eq(rules.heavy_stagger_sec, STANDARD_RULES.heavy_stagger_sec)
		assert_eq(rules.stagger_chain_limit, STANDARD_RULES.stagger_chain_limit)
		assert_eq(rules.superarmor_sec, STANDARD_RULES.superarmor_sec)
