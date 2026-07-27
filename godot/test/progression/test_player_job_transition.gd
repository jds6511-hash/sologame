## M3 B-5 검증 — 전직 프레임워크(PlayerJobTransition, jobs.md 6장·m3-leveling-spec 3-3·8-2).
##
## 전직 트리거(Lv10 전직 가능 플래그)·다중 레벨업 중 임계 통과·전직 실행 시 ① 성장 배분
## 전환 후 스탯 재계산(소급) ② 스킬 포인트 +2 ③ 승계형 스킬 슬롯 교체 ④ 무기(콤보) 교체를
## 실제 .tres 값으로 검산한다(전사 경로). 공유 파일 리소스 오염을 피하려고 CombatantStats는
## 매 테스트 새로 만든다.
extends GutTest

const FORMULA: StatGrowthFormula = preload("res://data/progression/stat_growth_formula.tres")
const JOB_ADVENTURER: JobGrowthData = preload("res://data/progression/job_growth_adventurer.tres")
const LEVEL_CURVE: LevelCurveData = preload("res://data/progression/level_curve.tres")
const LEVEL_DIFF_CURVE: LevelDiffCurve = preload("res://data/progression/level_diff_curve.tres")
const RULE: SkillPointRule = preload("res://data/progression/skill_point_rule.tres")
const WARRIOR_DEF: JobDefinition = preload("res://data/jobs/job_def_warrior.tres")
const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

const TOL := 0.0001


## PlayerJobTransition이 부모(PlayerController)에게 로드아웃 교체를 위임하는 경로를 기록하는
## 최소 스텁 — 실제 컨트롤러 대신 슬롯/콤보 인자만 받아 둔다.
class ControllerStub:
	extends Node
	var last_slots: Dictionary = {}
	var last_combo: WarriorComboData = null
	var loadout_calls: int = 0

	func apply_transition_loadout(slots: Dictionary, combo: WarriorComboData = null) -> void:
		last_slots = slots
		last_combo = combo
		loadout_calls += 1


var _stub: ControllerStub
var _stats: CombatantStats
var _prog: PlayerProgression
var _growth: PlayerStatGrowth
var _points: PlayerSkillPoints
var _trans: PlayerJobTransition


func before_each() -> void:
	_stats = CombatantStats.new()

	_stub = ControllerStub.new()
	add_child_autofree(_stub)

	_prog = PlayerProgression.new()
	_prog.name = "PlayerProgression"
	_prog.level_curve = LEVEL_CURVE
	_prog.level_diff_curve = LEVEL_DIFF_CURVE
	_stub.add_child(_prog)

	## 모험가 성장으로 시작한다(전직 전) — 전직 시 전사 배분으로 전환됨을 확인하기 위함.
	_growth = PlayerStatGrowth.new()
	_growth.name = "PlayerStatGrowth"
	_growth.job = JOB_ADVENTURER
	_growth.formula = FORMULA
	_growth.combat_stats = _stats
	_stub.add_child(_growth)

	_points = PlayerSkillPoints.new()
	_points.name = "PlayerSkillPoints"
	_points.rule = RULE
	_stub.add_child(_points)

	## 미전직(모험가) 상태로 시작 — initial_job_id 비움.
	_trans = PlayerJobTransition.new()
	_trans.name = "PlayerJobTransition"
	var jobs: Array[JobDefinition] = [WARRIOR_DEF, ARCHER_DEF]
	_trans.available_jobs = jobs
	_stub.add_child(_trans)


## 목표 레벨 도달에 필요한 경험치 합(현재 Lv1 기준).
func _exp_to_reach(target_level: int) -> int:
	var total := 0
	for lvl in range(1, target_level):
		total += LEVEL_CURVE.req(lvl)
	return total


# --- 전직 트리거 (Lv10 전직 가능 플래그) ---


func test_starts_as_adventurer_untransitioned() -> void:
	assert_eq(_trans.current_job_id, &"adventurer", "시작 직업 = 모험가")
	assert_false(_trans.is_transitioned, "시작 시 미전직")
	assert_false(_trans.transition_available, "Lv1에서는 전직 불가")


func test_no_flag_before_level_10() -> void:
	_prog.add_exp(_exp_to_reach(9))  ## Lv9
	assert_eq(_prog.current_level, 9)
	assert_false(_trans.transition_available, "Lv9 전직 불가")
	assert_false(_trans.can_transition(&"warrior"), "Lv9 전사 전직 불가")


func test_flag_set_at_level_10() -> void:
	_prog.add_exp(_exp_to_reach(10))  ## Lv10
	assert_eq(_prog.current_level, 10)
	assert_true(_trans.transition_available, "Lv10 전직 가능")
	assert_false(_trans.is_transitioned, "아직 전직 실행 전")
	assert_true(_trans.can_transition(&"warrior"), "전사 전직 가능")


func test_became_available_signal_emitted_at_ten() -> void:
	watch_signals(_trans)
	_prog.add_exp(_exp_to_reach(10))
	assert_signal_emitted(_trans, "transition_became_available")


# --- 다중 레벨업 중 전직 임계 통과 (spec 3-3·8-2) ---


func test_multi_level_up_crossing_ten_flags_available() -> void:
	## 단일 획득으로 Lv1 -> Lv12 (임계 Lv10을 건너뛴다).
	_prog.add_exp(_exp_to_reach(12))
	assert_eq(_prog.current_level, 12, "다중 레벨업으로 Lv12")
	assert_true(_trans.transition_available, "임계를 건너뛰어도 전직 가능 플래그가 선다")
	assert_true(_trans.can_transition(&"warrior"))


# --- 전직 실행: ① 성장 배분 전환 후 스탯 재계산(소급) ---


func test_transition_swaps_growth_job() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_true(_trans.perform_transition(&"warrior"))
	assert_eq(_growth.job.job_id, &"warrior", "성장 배분이 전사로 전환")


func test_transition_recomputes_stats_with_job_distribution() -> void:
	## Lv12까지 모험가로 올린 뒤(다중 레벨업) 전사 전직 → 전사 배분으로 소급 재계산.
	_prog.add_exp(_exp_to_reach(12))
	## 전직 전(모험가 Lv12): 공격력 = 무기 27.2 + 힘 24.5 x2 = 76.2.
	assert_almost_eq(_stats.attack_power, 76.2, TOL, "전직 전 모험가 배분 공격력")

	assert_true(_trans.perform_transition(&"warrior"))
	## 전직 후(전사 Lv12, spec 2-3): 공격 80.2 / HP 365 / 방어 48.5 / MP 166.5.
	assert_almost_eq(_stats.attack_power, 80.2, TOL, "전사 배분 공격력(소급)")
	assert_almost_eq(_stats.max_hp, 365.0, TOL, "전사 Lv12 최대 HP")
	assert_almost_eq(_stats.defense, 48.5, TOL, "전사 Lv12 방어력")
	assert_almost_eq(_stats.max_mp, 166.5, TOL, "전사 Lv12 최대 MP")


# --- 전직 실행: ② 스킬 포인트 +2 (spec 6-1) ---


func test_transition_grants_two_skill_points() -> void:
	_prog.add_exp(_exp_to_reach(10))  ## Lv10 도달 = 9포인트(Lv2~10)
	assert_eq(_points.available_points, 9, "Lv10 레벨업 포인트")
	assert_true(_trans.perform_transition(&"warrior"))
	assert_eq(_points.available_points, 11, "전직 보너스 +2 = 11")
	assert_eq(_points.earned_points(), 11, "(10-1) + 2 x 1전직")


# --- 전직 실행: ③ 승계형 스킬 슬롯 교체 + ④ 무기(콤보) 교체 ---


func test_transition_applies_inheritance_loadout() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_true(_trans.perform_transition(&"warrior"))
	assert_eq(_stub.loadout_calls, 1, "로드아웃 교체 1회 위임")
	## 공용 3종은 유지(slot_1~3), 직업 고유가 slot_4/Q/E/궁극기/우클릭을 채운다(신규 키 0).
	assert_eq(_stub.last_slots["slot_1"], WARRIOR_DEF.skill_slot_1, "1키=공용 강타 유지")
	assert_eq(_stub.last_slots["slot_4"], WARRIOR_DEF.skill_slot_4, "4키=분쇄 베기 개방")
	assert_eq(_stub.last_slots["slot_q"], WARRIOR_DEF.skill_slot_q, "Q키=돌격 개방")
	assert_eq(_stub.last_slots["ultimate"], WARRIOR_DEF.skill_ultimate, "R키=대지 분쇄 개방")
	assert_eq(_stub.last_slots["charge"], WARRIOR_DEF.skill_charge, "우클릭=차지 강타 개방")
	assert_eq(_stub.last_combo, WARRIOR_DEF.basic_combo, "무기 콤보(대검) 교체")


# --- 거부 규칙 ---


func test_cannot_transition_before_level_10() -> void:
	_prog.add_exp(_exp_to_reach(9))  ## Lv9 = 8포인트
	assert_false(_trans.perform_transition(&"warrior"), "Lv9 전직 거부")
	assert_false(_trans.is_transitioned)
	assert_eq(_points.available_points, 8, "거부 시 포인트 미지급")
	assert_eq(_growth.job.job_id, &"adventurer", "거부 시 성장 배분 불변")
	assert_eq(_stub.loadout_calls, 0, "거부 시 로드아웃 미교체")


func test_cannot_transition_twice() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_true(_trans.perform_transition(&"warrior"))
	assert_false(_trans.perform_transition(&"archer"), "이미 전직 — 재전직 거부")
	assert_false(_trans.perform_transition(&"warrior"), "같은 직업 재전직도 거부")
	assert_eq(_points.available_points, 11, "전직 보너스 중복 지급 없음")
	assert_eq(_stub.loadout_calls, 1, "로드아웃 교체 1회만")


func test_unknown_job_rejected() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_false(_trans.perform_transition(&"mage"), "미등록 직업 거부")
	assert_false(_trans.is_transitioned)


# --- 궁수 연결 훅(프레임워크 일반화) ---


func test_archer_hook_transitions_growth_and_common_skills() -> void:
	## 궁수 스킬 구현은 C-4지만, 프레임워크는 궁수도 그대로 받는다(성장 배분·공용 3종 개방).
	_prog.add_exp(_exp_to_reach(10))
	assert_true(_trans.perform_transition(&"archer"), "궁수 전직 성공")
	assert_eq(_growth.job.job_id, &"archer", "민첩 배분(궁수)으로 전환")
	assert_eq(_stub.last_slots["slot_1"], ARCHER_DEF.skill_slot_1, "공용 강타 유지")
	assert_null(_stub.last_slots["slot_4"], "궁수 고유 슬롯은 C-4까지 미개방(null)")


# --- initial_job_id: M2 전사 직행(이미 전직 상태) 호환 ---


func test_initial_job_id_starts_already_transitioned() -> void:
	var node := PlayerJobTransition.new()
	node.name = "PreTransitioned"
	var jobs: Array[JobDefinition] = [WARRIOR_DEF]
	node.available_jobs = jobs
	node.initial_job_id = &"warrior"
	_stub.add_child(node)
	assert_true(node.is_transitioned, "initial_job_id 지정 시 이미 전직 상태")
	assert_eq(node.current_job_id, &"warrior")
	## 이미 전직 상태이므로 Lv10에 도달해도 전직 가능 플래그가 서지 않고 재전직도 거부된다.
	_prog.add_exp(_exp_to_reach(10))
	assert_false(node.transition_available, "이미 전직 — Lv10 전직 가능 플래그 없음")
	assert_false(node.perform_transition(&"warrior"), "재전직 거부")


# --- 실제 PlayerController 로드아웃 교체 경로(널 슬롯 처리 포함) ---


func test_real_controller_apply_loadout_handles_null_slots() -> void:
	var player: Node = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	## 궁수 로드아웃(공용 3 + 고유 슬롯 null)을 실제 컨트롤러에 적용.
	player.apply_transition_loadout(ARCHER_DEF.skill_loadout(), null)
	assert_eq(player.skill_slot_1, ARCHER_DEF.skill_slot_1, "공용 강타 배선")
	assert_null(player.skill_slot_4, "null 슬롯은 미개방으로 비워짐")
	assert_null(player.skill_ultimate, "null 궁극기 슬롯 미개방")
	assert_null(player.skill_charge, "null 우클릭 슬롯 미개방")
