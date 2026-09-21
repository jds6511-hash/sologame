## G3 디렉터 플레이 피드백 — 시작 지역 3종은 첫 전직 전 학습 구간용 완화값을 사용한다.
extends GutTest

const RABBIT := preload("res://data/monsters/rabbit_stats.tres")
const WOLF := preload("res://data/monsters/wolf_stats.tres")
const SLIME := preload("res://data/monsters/slime_stats.tres")


func test_early_monster_hp_uses_three_second_onboarding_budget() -> void:
	assert_eq(RABBIT.max_hp, 165.0, "뿔토끼 HP")
	assert_eq(WOLF.max_hp, 244.0, "들개 마수 HP")
	assert_eq(SLIME.max_hp, 356.0, "균열 점액 HP")


func test_early_damage_is_five_to_seven_percent_at_same_level() -> void:
	var growth = load("res://data/progression/stat_growth_formula.tres")
	var job = load("res://data/progression/job_growth_adventurer.tres")
	var formula = load("res://data/combat/damage_formula.tres")
	var monsters := [RABBIT, WOLF, SLIME]
	var levels := [1, 4, 8]
	for i in range(monsters.size()):
		var player := CombatantStats.new()
		StatGrowthCalculator.apply(player, levels[i], job, growth)
		var damage := DamageCalculator.calculate_damage(
			monsters[i].attack_power, 1.0, player.defense, formula, false, false, 1.0
		)
		assert_between(damage / player.max_hp, 0.05, 0.07, "동레벨 낮 기본타 피해 비율")


func test_early_melee_allows_walking_out_after_reaction_delay() -> void:
	var movement = load("res://data/player/player_movement.tres")
	for monster in [RABBIT, WOLF]:
		var travel: float = (
			(monster.melee_telegraph_sec - 0.25) * movement.get_walk_speed_px_per_sec()
		)
		var clearance: float = monster.melee_range_tiles * 16.0 * 0.5 + 9.0
		assert_gt(travel, clearance, "0.25초 반응 후 일반 걷기로 판정 중심에서 탈출")
		assert_gte(monster.melee_recovery_sec, 0.5, "헛친 뒤 반격 여유")
