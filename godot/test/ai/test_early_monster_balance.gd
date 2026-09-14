## G3 디렉터 플레이 피드백 — 시작 지역 3종은 첫 전직 전 학습 구간용 완화값을 사용한다.
extends GutTest

const RABBIT := preload("res://data/monsters/rabbit_stats.tres")
const WOLF := preload("res://data/monsters/wolf_stats.tres")
const SLIME := preload("res://data/monsters/slime_stats.tres")


func test_early_monster_hp_uses_three_second_onboarding_budget() -> void:
	assert_eq(RABBIT.max_hp, 165.0, "뿔토끼 HP")
	assert_eq(WOLF.max_hp, 244.0, "들개 마수 HP")
	assert_eq(SLIME.max_hp, 356.0, "균열 점액 HP")


func test_early_monster_damage_allows_about_twelve_same_level_hits() -> void:
	assert_eq(RABBIT.attack_power, 12.0, "뿔토끼 공격력")
	assert_eq(WOLF.attack_power, 19.0, "들개 마수 공격력")
	assert_eq(SLIME.attack_power, 30.0, "균열 점액 공격력")
