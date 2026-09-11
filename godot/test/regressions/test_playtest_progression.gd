extends GutTest
## 전직에 따른 스킬 교체는 기존 투자 포인트를 잃게 해서는 안 된다.


func test_transition_refunds_replaced_skills_and_keeps_common_upgrade() -> void:
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var progression := player.get_node("PlayerProgression") as PlayerProgression
	var transition := player.get_node("PlayerJobTransition") as PlayerJobTransition
	var points := player.get_node("PlayerSkillPoints") as PlayerSkillPoints
	while progression.current_level < 10:
		progression.add_exp(progression.exp_to_next())
	assert_true(transition.perform_transition(&"warrior"))
	assert_true(points.try_upgrade_skill(&"강타", false))
	assert_true(points.try_upgrade_skill(&"분쇄 베기", false))
	assert_true(points.try_upgrade_skill(&"분쇄 베기", false))
	while progression.current_level < 40:
		progression.add_exp(progression.exp_to_next())
	var before := points.available_points
	assert_true(transition.perform_transition(&"gladiator"))
	assert_eq(points.available_points, before + 4, "교체 스킬 2포인트 환급 + 전직 보너스 2")
	assert_eq(points.spent_points, 1)
	assert_eq(points.get_skill_level(&"강타"), 2)
	assert_eq(points.get_skill_level(&"분쇄 베기"), 1)
	assert_eq(points.earned_points(), 43)
	assert_false(transition.perform_transition(&"gladiator"))
	assert_eq(points.available_points, before + 4, "중복 전직은 환급하지 않음")


func test_monster_group_matches_minimap_contract() -> void:
	var monster: MonsterBase = load("res://scenes/monsters/imp.tscn").instantiate()
	add_child_autofree(monster)
	assert_true(monster.is_in_group("monsters"))


func test_refund_uses_paid_ultimate_cost_even_after_balance_change() -> void:
	var points := PlayerSkillPoints.new()
	points.rule = SkillPointRule.new()
	add_child_autofree(points)
	points.available_points = 10
	assert_true(points.try_upgrade_skill(&"테스트 궁극기", true))
	assert_eq(points.spent_points, 3)
	points.rule.ultimate_upgrade_costs = PackedInt32Array([30, 30])
	points.refund_unavailable_skills([])
	assert_eq(points.available_points, 10)
	assert_eq(points.spent_points, 0)
	assert_eq(points.earned_points(), 10)
	points.refund_unavailable_skills([])
	assert_eq(points.available_points, 10, "중복 환급 없음")
