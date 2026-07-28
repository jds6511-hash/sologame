## M3 C-1 검증 — 전사 2차 전직(검투사) 경로와 승계형 슬롯 교체
## (m3-warrior-tier2-skills.md 1-1장, jobs.md 1장 "2차 전직 Lv40").
##
## 실제 player.tscn 인스턴스로 배선을 검증한다: ① Lv10 전사 전직 후 Lv40에서 2차 전직 가능
## ② 승계형 교체(공용 3종 유지 · 슬롯4/Q/E 검투사판 대체 · 궁극기/우클릭 유지 · 신규 키 0)
## ③ 계통 제약(궁수는 검투사 불가, 전사 전에는 불가, Lv40 미달 불가)
## ④ 1차 직업 선택 화면에 상위 계통이 섞이지 않음(available_jobs 불변).
##
## 공유 CombatantStats 파일 리소스가 레벨업으로 오염되지 않도록 인스턴스마다 사본으로
## 갈아 끼운다(test_adventurer_start_flow.gd와 동일 격리).
extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const WARRIOR_DEF: JobDefinition = preload("res://data/jobs/job_def_warrior.tres")
const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")
const GLADIATOR_DEF: JobDefinition = preload("res://data/jobs/job_def_gladiator.tres")
## 처형 일격은 발동 시 damage_coefficient를 런타임에 덮어쓰므로 const preload로 잡지 않는다
## (상수로 참조된 리소스는 read-only가 되어 그 쓰기가 무시된다 — 차지 강타와 동일 사정).
const EXECUTION_PATH := "res://data/player/skills/gladiator/skill_secondary_execution.tres"

const SECOND_TRANSITION_LEVEL := 40

var _execution: GladiatorSkillData = load(EXECUTION_PATH)

var _player: PlayerController
var _prog: PlayerProgression
var _points: PlayerSkillPoints
var _trans: PlayerJobTransition


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	var growth: PlayerStatGrowth = _player.get_node("PlayerStatGrowth")
	var fresh: CombatantStats = growth.combat_stats.duplicate()
	growth.combat_stats = fresh
	_player.get_node("PlayerStats").stats = fresh
	_player.get_node("AttackResolver").attacker_stats = fresh
	_prog = _player.get_node("PlayerProgression")
	_points = _player.get_node("PlayerSkillPoints")
	_trans = _player.get_node("PlayerJobTransition")


func _level_up_to(target_level: int) -> void:
	while _prog.current_level < target_level and not _prog.is_max_level():
		_prog.add_exp(_prog.exp_to_next())


# --- ① 2차 전직 임계 (Lv40) ---


func test_gladiator_definition_declares_tier2_chain() -> void:
	assert_eq(GLADIATOR_DEF.job_id, &"gladiator")
	assert_eq(GLADIATOR_DEF.display_name, "검투사")
	assert_eq(GLADIATOR_DEF.required_job_id, &"warrior", "전사 전제")
	assert_eq(GLADIATOR_DEF.transition_level(), SECOND_TRANSITION_LEVEL, "2차 전직 임계 Lv40")


func test_tier2_registered_separately_from_first_job_list() -> void:
	## 1차 직업 선택 화면은 available_jobs로 카드를 만든다 — 상위 계통이 섞이면 안 된다.
	assert_eq(_trans.available_jobs.size(), 2, "1차 선택지는 전사·궁수 둘")
	assert_eq(_trans.tier2_jobs, [GLADIATOR_DEF] as Array[JobDefinition], "검투사는 상위 계통 목록")


func test_no_second_transition_flag_before_first() -> void:
	_level_up_to(SECOND_TRANSITION_LEVEL)
	assert_eq(_prog.current_level, SECOND_TRANSITION_LEVEL)
	assert_false(_trans.is_transitioned, "1차 전직을 아직 안 했다")
	assert_false(_trans.can_transition(&"gladiator"), "전사 전에는 검투사 전직 불가")
	assert_true(_trans.can_transition(&"warrior"), "1차 전직은 여전히 가능")


func test_gladiator_unavailable_between_ten_and_forty() -> void:
	_level_up_to(10)
	assert_true(_trans.perform_transition(&"warrior"), "Lv10 전사 전직")
	assert_false(_trans.transition_available, "전직 직후에는 다음 계통 임계 미달")
	_level_up_to(39)
	assert_false(_trans.transition_available, "Lv39 2차 전직 불가")
	assert_false(_trans.can_transition(&"gladiator"))


func test_gladiator_becomes_available_at_forty() -> void:
	_level_up_to(10)
	assert_true(_trans.perform_transition(&"warrior"))
	watch_signals(_trans)
	_level_up_to(SECOND_TRANSITION_LEVEL)
	assert_true(_trans.transition_available, "Lv40 2차 전직 가능")
	assert_true(_trans.can_transition(&"gladiator"), "검투사 전직 가능")
	assert_signal_emitted(_trans, "transition_became_available")


func test_late_first_transition_flags_tier2_immediately() -> void:
	## Lv40을 넘긴 뒤 1차 전직을 하면 2차 임계가 이미 충족돼 곧바로 다시 전직 가능해야 한다.
	_level_up_to(45)
	assert_true(_trans.perform_transition(&"warrior"))
	assert_true(_trans.transition_available, "Lv45 전사 → 즉시 2차 전직 가능")
	assert_true(_trans.can_transition(&"gladiator"))


# --- ② 승계형 교체 (신규 키 0) ---


func test_gladiator_transition_replaces_tier1_slots_only() -> void:
	_transition_to_gladiator()
	## 모험가 공용 3종은 전 티어 유지.
	assert_eq(_player.skill_slot_1, GLADIATOR_DEF.skill_slot_1, "1키 = 공용 강타 유지")
	assert_eq(_player.skill_slot_2, GLADIATOR_DEF.skill_slot_2, "2키 = 공용 질주 유지")
	assert_eq(_player.skill_slot_3, GLADIATOR_DEF.skill_slot_3, "3키 = 공용 응급 처치 유지")
	## 1차 전사 스킬 3종이 검투사 승계판으로 대체된다.
	assert_eq(_player.skill_slot_4, GLADIATOR_DEF.skill_slot_4, "4키 = 검투 선풍")
	assert_eq(_player.skill_slot_q, GLADIATOR_DEF.skill_slot_q, "Q키 = 난입 강타")
	assert_eq(_player.skill_slot_e, GLADIATOR_DEF.skill_slot_e, "E키 = 혈투의 함성")
	assert_ne(_player.skill_slot_4, WARRIOR_DEF.skill_slot_4, "분쇄 베기는 사라진다")
	assert_ne(_player.skill_slot_q, WARRIOR_DEF.skill_slot_q, "돌격은 사라진다")
	assert_ne(_player.skill_slot_e, WARRIOR_DEF.skill_slot_e, "결의의 외침은 사라진다")
	## 궁극기·우클릭은 유지(3차에서 각성 — 범위 밖).
	assert_eq(_player.skill_ultimate, WARRIOR_DEF.skill_ultimate, "R키 = 대지 분쇄 유지")
	assert_eq(_player.skill_charge, WARRIOR_DEF.skill_charge, "우클릭 = 차지 강타 유지")


func test_gladiator_adds_no_new_key() -> void:
	## 슬롯 8칸 외에 새 키가 생기지 않는다 — 4번째 스킬은 우클릭의 조건부 파생이다.
	_transition_to_gladiator()
	assert_true(_player.rage.is_active(), "분노 게이지 활성")
	assert_eq(_player.rage.finisher, _execution, "처형 일격은 우클릭 격노 파생")
	assert_eq(GLADIATOR_DEF.skill_rage_finisher, _execution, "정의가 파생 슬롯을 소유")
	assert_eq(GLADIATOR_DEF.skill_charge, WARRIOR_DEF.skill_charge, "우클릭 기본은 그대로")


func test_gladiator_keeps_greatsword_combo() -> void:
	_transition_to_gladiator()
	assert_eq(_player.combo_data, WARRIOR_DEF.basic_combo, "2차 전직은 무기 계열을 바꾸지 않는다")


func test_gladiator_transition_grants_two_skill_points() -> void:
	_level_up_to(10)
	assert_true(_trans.perform_transition(&"warrior"))
	_level_up_to(SECOND_TRANSITION_LEVEL)
	var before := _points.available_points
	assert_true(_trans.perform_transition(&"gladiator"))
	assert_eq(_points.available_points, before + 2, "2차 전직 보너스 +2 (jobs.md 6장)")


func test_gladiator_emits_job_changed() -> void:
	_level_up_to(10)
	assert_true(_trans.perform_transition(&"warrior"))
	_level_up_to(SECOND_TRANSITION_LEVEL)
	watch_signals(_trans)
	assert_true(_trans.perform_transition(&"gladiator"))
	assert_signal_emitted_with_parameters(_trans, "job_changed", [&"gladiator"])
	assert_eq(_trans.current_job_id, &"gladiator")


func test_debug_transition_key_path_reaches_gladiator() -> void:
	## 정식 2차 전직 UI가 없어 실행 경로는 F11~ 디버그 키(= request_transition_by_index)다.
	_level_up_to(10)
	assert_true(_trans.request_transition_by_index(0), "0번 = 전사")
	_level_up_to(SECOND_TRANSITION_LEVEL)
	assert_true(_trans.request_transition_by_index(0), "전직 후 0번 = 검투사(후보 목록)")
	assert_eq(_trans.current_job_id, &"gladiator")


# --- ③ 계통 제약 ---


func test_archer_cannot_transition_to_gladiator() -> void:
	_level_up_to(10)
	assert_true(_trans.perform_transition(&"archer"))
	_level_up_to(SECOND_TRANSITION_LEVEL)
	assert_false(_trans.transition_available, "궁수에게는 등록된 상위 계통이 없다")
	assert_false(_trans.can_transition(&"gladiator"), "궁수 → 검투사 불가(계통 불일치)")
	assert_false(_trans.perform_transition(&"gladiator"))
	assert_eq(_trans.current_job_id, &"archer", "거부 시 직업 불변")
	assert_eq(_player.skill_slot_4, ARCHER_DEF.skill_slot_4, "거부 시 슬롯 불변")


func test_cannot_transition_to_gladiator_twice() -> void:
	_transition_to_gladiator()
	var points_before := _points.available_points
	assert_false(_trans.perform_transition(&"gladiator"), "재전직 거부")
	assert_false(_trans.perform_transition(&"warrior"), "1차로 되돌아가기 거부")
	assert_eq(_points.available_points, points_before, "보너스 중복 지급 없음")


func test_gladiator_growth_inherits_warrior_distribution() -> void:
	## jobs.md는 2차 전직의 스탯 배분 변화를 규정하지 않았다 — 1차 배분을 승계한다.
	_transition_to_gladiator()
	var growth: PlayerStatGrowth = _player.get_node("PlayerStatGrowth")
	assert_eq(growth.job, WARRIOR_DEF.growth, "성장 배분 = 전사 그대로")


# --- 헬퍼 ---


func _transition_to_gladiator() -> void:
	_level_up_to(10)
	assert_true(_trans.perform_transition(&"warrior"), "1차 전사 전직")
	_level_up_to(SECOND_TRANSITION_LEVEL)
	assert_true(_trans.perform_transition(&"gladiator"), "2차 검투사 전직")
