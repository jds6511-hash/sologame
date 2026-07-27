## M3 B-5 후속 검증 — 시작 직업 흐름 "모험가 시작 -> Lv10 전직"(jobs.md 1·6장, 디렉터 확정).
##
## 스텁 하니스로 프레임워크 자체를 검증하는 test_player_job_transition.gd와 달리, 여기서는
## **실제 player.tscn 인스턴스**로 배선을 검증한다: ① Lv1 모험가 시작 상태(공용 3종만 개방,
## 모험가 균등 배분) ② Lv10 도달 시 전직 가능 ③ 전직 실행 후 전사 배분 소급·슬롯 교체·스킬
## 포인트 +2 ④ 다중 레벨업으로 Lv10을 건너뛴 경우 ⑤ 디버그 직행 시작(initial_job_id).
##
## player.tscn은 AttackResolver·PlayerStats·PlayerStatGrowth가 한 CombatantStats 파일 리소스
## (warrior_lv1_combatant_stats.tres)를 공유한다. 레벨업이 그 공유 리소스를 덮어써 다른
## 테스트를 오염시키지 않도록, 인스턴스마다 duplicate()한 사본을 세 참조에 다시 꽂아 격리한다
## (공유 구조 자체는 유지 — 재계산 결과가 전투 계산으로 퍼지는 경로를 그대로 검증한다).
extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const WARRIOR_DEF: JobDefinition = preload("res://data/jobs/job_def_warrior.tres")
const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")
const SKILL_STRIKE: WarriorSkillData = preload("res://data/player/skills/skill_slot1_strike.tres")
const SKILL_SPRINT: WarriorSkillData = preload("res://data/player/skills/skill_slot2_sprint.tres")
const SKILL_FIRST_AID: WarriorSkillData = preload(
	"res://data/player/skills/skill_slot3_first_aid.tres"
)

const TOL := 0.0001

var _player: PlayerController
var _prog: PlayerProgression
var _growth: PlayerStatGrowth
var _points: PlayerSkillPoints
var _trans: PlayerJobTransition
var _stats: CombatantStats


func before_each() -> void:
	_player = _spawn_player()
	_prog = _player.get_node("PlayerProgression")
	_growth = _player.get_node("PlayerStatGrowth")
	_points = _player.get_node("PlayerSkillPoints")
	_trans = _player.get_node("PlayerJobTransition")
	_stats = _isolate_combat_stats(_player)


func _spawn_player() -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


## 공유 CombatantStats를 사본으로 갈아 끼워 파일 리소스 오염을 막는다(세 참조 모두 동일 사본).
func _isolate_combat_stats(player: PlayerController) -> CombatantStats:
	var growth: PlayerStatGrowth = player.get_node("PlayerStatGrowth")
	var fresh: CombatantStats = growth.combat_stats.duplicate()
	growth.combat_stats = fresh
	player.get_node("PlayerStats").stats = fresh
	player.get_node("AttackResolver").attacker_stats = fresh
	return fresh


## 목표 레벨 도달에 필요한 경험치 합(현재 Lv1 기준).
func _exp_to_reach(target_level: int) -> int:
	var total := 0
	for lvl in range(1, target_level):
		total += _prog.level_curve.req(lvl)
	return total


# --- ① Lv1 모험가 시작 상태 ---


func test_starts_as_untransitioned_adventurer() -> void:
	assert_eq(_prog.current_level, 1, "Lv1 시작")
	assert_eq(_trans.current_job_id, &"adventurer", "시작 직업 = 모험가")
	assert_false(_trans.is_transitioned, "미전직 상태로 시작")
	assert_false(_trans.transition_available, "Lv1에서는 전직 불가")
	assert_eq(_growth.job.job_id, &"adventurer", "성장 배분 = 모험가")


func test_starts_with_common_three_skills_only() -> void:
	assert_eq(_player.skill_slot_1, SKILL_STRIKE, "1키 = 공용 강타")
	assert_eq(_player.skill_slot_2, SKILL_SPRINT, "2키 = 공용 질주")
	assert_eq(_player.skill_slot_3, SKILL_FIRST_AID, "3키 = 공용 응급 처치")
	assert_null(_player.skill_slot_4, "4키 미개방")
	assert_null(_player.skill_slot_q, "Q키 미개방")
	assert_null(_player.skill_slot_e, "E키 미개방")
	assert_null(_player.skill_ultimate, "R키(궁극기) 미개방")
	assert_null(_player.skill_charge, "우클릭 미개방")


func test_locked_slot_cannot_be_used() -> void:
	assert_false(_player._try_use_skill("slot4", _player.skill_slot_4), "미개방 슬롯 사용 실패")
	assert_eq(_player.skill_state, PlayerController.AttackState.NONE)


func test_adventurer_distribution_applies_before_transition() -> void:
	_prog.add_exp(_exp_to_reach(5))  ## Lv5
	assert_eq(_prog.current_level, 5)
	## 모험가 균등 배분 Lv5(4스탯 모두 14.0) — spec 2-3 Lv5 행과 일치(1~10은 직업 무관).
	assert_almost_eq(_stats.attack_power, 44.0, TOL, "모험가 Lv5 공격력")
	assert_almost_eq(_stats.max_hp, 215.0, TOL, "모험가 Lv5 최대 HP")
	assert_almost_eq(_stats.defense, 26.5, TOL, "모험가 Lv5 방어력")
	assert_almost_eq(_stats.max_mp, 110.0, TOL, "모험가 Lv5 최대 MP")
	assert_almost_eq(_stats.agility, 14.0, TOL, "모험가 Lv5 민첩")


# --- ② Lv10 전직 가능 ---


func test_transition_available_at_level_10() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_eq(_prog.current_level, 10)
	assert_true(_trans.transition_available, "Lv10 전직 가능")
	assert_false(_trans.is_transitioned, "아직 전직 실행 전")
	assert_true(_trans.can_transition(&"warrior"), "전사 전직 가능")
	assert_true(_trans.can_transition(&"archer"), "궁수 전직 가능")


func test_not_available_at_level_9() -> void:
	_prog.add_exp(_exp_to_reach(9))
	assert_eq(_prog.current_level, 9)
	assert_false(_trans.transition_available, "Lv9 전직 불가")


# --- ③ 전직 실행 (실제 컨트롤러·공유 스탯 경로) ---


func test_transition_opens_warrior_slots_on_real_controller() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_true(_trans.perform_transition(&"warrior"), "전사 전직 성공")
	## 승계형 교체(신규 키 0): 공용 3종은 그대로 두고 직업 고유가 나머지 슬롯을 채운다.
	assert_eq(_player.skill_slot_1, SKILL_STRIKE, "1키 = 공용 강타 유지")
	assert_eq(_player.skill_slot_4, WARRIOR_DEF.skill_slot_4, "4키 = 분쇄 베기 개방")
	assert_eq(_player.skill_slot_q, WARRIOR_DEF.skill_slot_q, "Q키 = 돌격 개방")
	assert_eq(_player.skill_slot_e, WARRIOR_DEF.skill_slot_e, "E키 = 결의의 외침 개방")
	assert_eq(_player.skill_ultimate, WARRIOR_DEF.skill_ultimate, "R키 = 대지 분쇄 개방")
	assert_eq(_player.skill_charge, WARRIOR_DEF.skill_charge, "우클릭 = 차지 강타 개방")
	assert_eq(_player.combo_data, WARRIOR_DEF.basic_combo, "직업 무기(콤보) 적용")


func test_transition_grants_two_bonus_skill_points() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_eq(_points.available_points, 9, "Lv10 도달 = 레벨업 9포인트")
	assert_true(_trans.perform_transition(&"warrior"))
	assert_eq(_points.available_points, 11, "전직 보너스 +2")


func test_transition_recomputes_stats_with_warrior_distribution() -> void:
	## 전직 직후(Lv10)는 모험가/전사 배분 결과가 같으므로(직업 구간 0레벨) 값이 유지된다.
	_prog.add_exp(_exp_to_reach(10))
	assert_true(_trans.perform_transition(&"warrior"))
	assert_almost_eq(_stats.attack_power, 67.0, TOL, "전사 Lv10 공격력(모험가와 동일)")
	## 이후 레벨업분은 전사 배분(힘 +2.5/체력 +2.0)으로 벌어진다 — spec 2-3 Lv12 행.
	_prog.add_exp(_exp_to_reach(12) - _exp_to_reach(10))
	assert_eq(_prog.current_level, 12)
	assert_almost_eq(_stats.attack_power, 80.2, TOL, "전사 Lv12 공격력")
	assert_almost_eq(_stats.max_hp, 365.0, TOL, "전사 Lv12 최대 HP")
	assert_almost_eq(_stats.defense, 48.5, TOL, "전사 Lv12 방어력")
	assert_almost_eq(_stats.max_mp, 166.5, TOL, "전사 Lv12 최대 MP")


func test_transition_emits_job_changed() -> void:
	_prog.add_exp(_exp_to_reach(10))
	watch_signals(_trans)
	assert_true(_trans.perform_transition(&"warrior"))
	assert_signal_emitted_with_parameters(_trans, "job_changed", [&"warrior"])


# --- ③' 전직 실행 경로(직업 선택 인덱스 API — 전직 실행 키가 쓰는 경로) ---


func test_request_transition_by_index_selects_available_job() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_true(_trans.request_transition_by_index(0), "0번(전사) 선택 성공")
	assert_eq(_trans.current_job_id, &"warrior")


func test_request_transition_by_index_out_of_range_rejected() -> void:
	_prog.add_exp(_exp_to_reach(10))
	assert_false(_trans.request_transition_by_index(9), "목록 범위 밖 거부")
	assert_false(_trans.request_transition_by_index(-1), "음수 인덱스 거부")
	assert_false(_trans.is_transitioned, "거부 시 미전직 유지")


func test_request_transition_before_level_10_rejected() -> void:
	assert_false(_trans.request_transition_by_index(0), "Lv1 전직 실행 거부")
	assert_null(_player.skill_slot_4, "거부 시 슬롯 미개방 유지")


# --- ④ 다중 레벨업으로 Lv10을 건너뛴 경우 (spec 3-3·8-2) ---


func test_multi_level_up_skipping_ten_still_allows_transition() -> void:
	_prog.add_exp(_exp_to_reach(12))  ## 단일 획득으로 Lv1 -> Lv12
	assert_eq(_prog.current_level, 12, "임계를 건너뛴 다중 레벨업")
	assert_true(_trans.transition_available, "건너뛰어도 전직 가능 플래그")
	## 전직 전에는 모험가 배분이 계속 적용된다(공격력 = 무기 27.2 + 힘 24.5 x 2).
	assert_almost_eq(_stats.attack_power, 76.2, TOL, "전직 전 모험가 배분")

	assert_true(_trans.perform_transition(&"warrior"))
	## 전직 순간 현재 레벨로 재계산 = 전사 배분 소급(spec 3-3).
	assert_almost_eq(_stats.attack_power, 80.2, TOL, "전사 배분 소급 공격력")
	assert_almost_eq(_stats.max_hp, 365.0, TOL, "전사 배분 소급 최대 HP")
	assert_eq(_points.available_points, 13, "레벨업 11 + 전직 보너스 2")


# --- ⑤ 디버그 직행 시작 (initial_job_id) ---


func test_debug_initial_job_id_starts_as_warrior() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	## _ready 전에 지정해야 직행 시작 경로를 탄다(디버그 씬의 씬 오버라이드와 동일).
	var trans: PlayerJobTransition = player.get_node("PlayerJobTransition")
	trans.initial_job_id = &"warrior"
	add_child_autofree(player)
	_isolate_combat_stats(player)

	assert_true(trans.is_transitioned, "직행 시작 — 이미 전직 상태")
	assert_eq(trans.current_job_id, &"warrior")
	assert_false(trans.transition_available, "전직 가능 플래그 없음")
	var growth: PlayerStatGrowth = player.get_node("PlayerStatGrowth")
	assert_eq(growth.job.job_id, &"warrior", "성장 배분도 전사")
	assert_eq(player.skill_slot_4, WARRIOR_DEF.skill_slot_4, "전사 고유 슬롯 개방")
	assert_eq(player.skill_charge, WARRIOR_DEF.skill_charge, "우클릭 차지 강타 개방")
	var points: PlayerSkillPoints = player.get_node("PlayerSkillPoints")
	assert_eq(points.available_points, 0, "직행 시작은 전직 보너스 미지급")


## 디버그 씬은 Lv1 전사 스킬 세트를 전제로 손맛을 검증하는 도구다(F1~F3 몬스터 소환).
## 씬 오버라이드(initial_job_id = warrior)가 유지되는지 실제 씬으로 확인한다.
func test_debug_scenes_start_as_warrior_directly() -> void:
	for scene_path in [
		"res://scenes/debug/debug_combat_arena.tscn", "res://scenes/player/player_debug.tscn"
	]:
		var scene: PackedScene = load(scene_path)
		var root: Node = scene.instantiate()
		add_child_autofree(root)
		var player: PlayerController = root.get_node("Player")
		var trans: PlayerJobTransition = player.get_node("PlayerJobTransition")
		assert_eq(trans.current_job_id, &"warrior", "%s — 전사 직행 시작" % scene_path)
		assert_not_null(player.skill_ultimate, "%s — 궁극기 개방" % scene_path)
		assert_not_null(player.skill_charge, "%s — 우클릭 차지 강타 개방" % scene_path)


func test_debug_initial_job_id_archer_opens_common_only() -> void:
	## 궁수 고유 스킬은 C-4 소관 — 직행 시작도 공용 3종만 열리는 것이 정상이다.
	var player: PlayerController = PLAYER_SCENE.instantiate()
	var trans: PlayerJobTransition = player.get_node("PlayerJobTransition")
	trans.initial_job_id = &"archer"
	add_child_autofree(player)
	_isolate_combat_stats(player)

	assert_eq(trans.current_job_id, &"archer")
	assert_eq(player.skill_slot_1, ARCHER_DEF.skill_slot_1, "공용 강타 유지")
	assert_null(player.skill_slot_4, "궁수 고유 슬롯 미개방(C-4)")
