## M3 B-3 검증 — 스킬 포인트 경제(m3-leveling-spec.md 6장·SkillPointRule).
## 포인트 획득(레벨당 +1·전직 +2), 강화 비용([1,1,2,4]/궁극기[3,3]), 계수 상승(+8%/레벨),
## 잔여 포인트 부족 시 강화 거부를 실제 .tres 값으로 확인한다.
extends GutTest

const RULE: SkillPointRule = preload("res://data/progression/skill_point_rule.tres")
const LEVEL_CURVE: LevelCurveData = preload("res://data/progression/level_curve.tres")
const LEVEL_DIFF_CURVE: LevelDiffCurve = preload("res://data/progression/level_diff_curve.tres")

const TOL := 0.0001

var _root: Node
var _prog: PlayerProgression
var _points: PlayerSkillPoints


func before_each() -> void:
	_root = Node.new()
	add_child_autofree(_root)

	_prog = PlayerProgression.new()
	_prog.name = "PlayerProgression"
	_prog.level_curve = LEVEL_CURVE
	_prog.level_diff_curve = LEVEL_DIFF_CURVE
	_root.add_child(_prog)

	_points = PlayerSkillPoints.new()
	_points.name = "PlayerSkillPoints"
	_points.rule = RULE
	_root.add_child(_points)


## 임의 레벨까지 올리는 데 필요한 경험치 합(현재 Lv1 기준).
func _exp_to_reach(target_level: int) -> int:
	var total := 0
	for lvl in range(1, target_level):
		total += LEVEL_CURVE.req(lvl)
	return total


# --- 포인트 지급 (spec 6-1) ---


func test_level_up_grants_one_point_per_level() -> void:
	_prog.add_exp(LEVEL_CURVE.req(1))  ## Lv1 -> Lv2
	assert_eq(_points.available_points, 1, "레벨업 1회 = +1 포인트")


func test_multi_level_up_grants_point_each_level() -> void:
	_prog.add_exp(_exp_to_reach(4))  ## Lv1 -> Lv4 (3레벨업)
	assert_eq(_prog.current_level, 4)
	assert_eq(_points.available_points, 3, "3레벨업 = +3 포인트")


func test_transition_grants_two_points() -> void:
	_points.grant_transition_points()
	assert_eq(_points.available_points, 2, "전직 1회 = +2 포인트")


func test_combined_earned_points_matches_spec_formula() -> void:
	## spec 6-1 예: Lv15 전직 완료 = (15-1) + 2 = 16 포인트.
	_prog.add_exp(_exp_to_reach(15))  ## Lv1 -> Lv15 (14레벨업)
	_points.grant_transition_points()
	assert_eq(_prog.current_level, 15)
	assert_eq(_points.earned_points(), 16, "(level-1) + 2 x 전직횟수")
	assert_eq(_points.available_points, 16, "미사용 시 잔여 = 획득")


# --- 강화 비용 (spec 6-2) ---


func test_normal_skill_upgrade_costs_1_1_2_4() -> void:
	_points.available_points = 8
	var id := &"강타"
	assert_true(_points.try_upgrade_skill(id, false), "Lv1->2 비용 1")
	assert_eq(_points.available_points, 7)
	assert_true(_points.try_upgrade_skill(id, false), "Lv2->3 비용 1")
	assert_eq(_points.available_points, 6)
	assert_true(_points.try_upgrade_skill(id, false), "Lv3->4 비용 2")
	assert_eq(_points.available_points, 4)
	assert_true(_points.try_upgrade_skill(id, false), "Lv4->5 비용 4")
	assert_eq(_points.available_points, 0)
	assert_eq(_points.get_skill_level(id), 5)
	assert_eq(_points.spent_points, 8, "풀업 총비용 8")


func test_normal_skill_cannot_exceed_max_level() -> void:
	_points.available_points = 100
	var id := &"강타"
	for i in range(4):
		_points.try_upgrade_skill(id, false)
	assert_eq(_points.get_skill_level(id), 5, "일반 스킬 만렙 Lv5")
	assert_false(_points.try_upgrade_skill(id, false), "Lv5에서 추가 강화 거부")
	assert_eq(_points.available_points, 92, "만렙 강화 실패 시 포인트 미차감")


func test_ultimate_upgrade_costs_3_3() -> void:
	_points.available_points = 6
	var id := &"대지 분쇄"
	assert_true(_points.try_upgrade_skill(id, true), "Lv1->2 비용 3")
	assert_eq(_points.available_points, 3)
	assert_true(_points.try_upgrade_skill(id, true), "Lv2->3 비용 3")
	assert_eq(_points.available_points, 0)
	assert_eq(_points.get_skill_level(id), 3, "궁극기 만렙 Lv3")
	assert_false(_points.try_upgrade_skill(id, true), "Lv3에서 추가 강화 거부")


func test_upgrade_rejected_when_insufficient_points() -> void:
	var id := &"강타"
	## Lv3까지 올려 다음 단계 비용을 2로 만든 뒤, 잔여 1로 거부되는지 확인.
	_points.available_points = 2
	_points.try_upgrade_skill(id, false)  ## Lv1->2 (1)
	_points.try_upgrade_skill(id, false)  ## Lv2->3 (1) → 잔여 0
	_points.available_points = 1  ## Lv3->4 비용은 2
	assert_false(_points.try_upgrade_skill(id, false), "잔여 1 < 비용 2 → 거부")
	assert_eq(_points.get_skill_level(id), 3, "거부 시 레벨 불변")
	assert_eq(_points.available_points, 1, "거부 시 포인트 불변")


func test_fresh_skill_upgrade_rejected_with_zero_points() -> void:
	assert_false(_points.try_upgrade_skill(&"강타", false), "포인트 0 → 강화 불가")
	assert_eq(_points.get_skill_level(&"강타"), 1)


# --- 계수 상승 (spec 6-2, +8%/레벨) ---


func test_coefficient_multiplier_steps() -> void:
	assert_almost_eq(RULE.coefficient_multiplier(1), 1.0, TOL, "Lv1 = 1.0")
	assert_almost_eq(RULE.coefficient_multiplier(2), 1.08, TOL, "Lv2 = 1.08")
	assert_almost_eq(RULE.coefficient_multiplier(3), 1.16, TOL, "Lv3 = 1.16")


func test_effective_coefficient_matches_spec_example() -> void:
	## spec 6-2 예: 강타 base 1.3, Lv3 → 1.3 x 1.16 = 1.508.
	_points.available_points = 8
	var id := &"강타"
	_points.try_upgrade_skill(id, false)  ## Lv2
	_points.try_upgrade_skill(id, false)  ## Lv3
	assert_almost_eq(_points.effective_coefficient(1.3, id), 1.508, TOL)


func test_effective_coefficient_unchanged_at_level_one() -> void:
	assert_almost_eq(_points.effective_coefficient(1.8, &"강타"), 1.8, TOL, "미강화 = base")


# --- 시그널 (spec 6-2, B-4 HUD 구독용) ---


func test_signals_emitted_on_grant_and_upgrade() -> void:
	watch_signals(_points)
	_prog.add_exp(LEVEL_CURVE.req(1))  ## 레벨업 → points_changed
	assert_signal_emitted(_points, "points_changed")

	_points.available_points = 8
	_points.try_upgrade_skill(&"강타", false)
	assert_signal_emitted_with_parameters(_points, "skill_upgraded", [&"강타", 2])
