## M3 모험가 소검 3타 콤보 검증 — m3-adventurer-basic-combo.md 2·7장 표를 기대값으로 삼는다.
##
## 두 축을 함께 본다: ① 데이터(.tres)가 규격과 일치하는지 ② 배선이 "모험가 시작 = 소검,
## 전직 = 직업 무기"로 성립하는지(player.tscn combo_data + JobDefinition.basic_combo 경로).
## 콤보 사이클 계수/초 2.054(대검 2.083과 의도적 동률 — 1장)는 회귀 방지 핵심 단정이다.
extends GutTest

const SWORD_COMBO: WarriorComboData = preload("res://data/player/adventurer_basic_combo.tres")
const WARRIOR_COMBO: WarriorComboData = preload("res://data/player/warrior_basic_combo.tres")
const ARCHER_COMBO: WarriorComboData = preload("res://data/player/archer_basic_combo.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const WARRIOR_DEF: JobDefinition = preload("res://data/jobs/job_def_warrior.tres")
const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")

const TOL := 0.0001

## 2장 확정 표: 계수 / 리치(타일) / 판정각(도) / 선딜 / 판정 / 후딜 / 히트스톱
const STEP_SPEC := [
	[0.65, 1.5, 70.0, 0.09, 0.07, 0.16, "약"],
	[0.65, 1.5, 70.0, 0.09, 0.07, 0.16, "약"],
	[1.0, 1.7, 100.0, 0.13, 0.10, 0.25, "중"],
]

# --- ① 데이터 규격 (m3-adventurer-basic-combo.md 2·7-2장) ---


func test_combo_has_three_steps() -> void:
	assert_eq(SWORD_COMBO.steps.size(), 3, "소검은 3타 콤보")


func test_each_step_matches_design_table() -> void:
	for i in STEP_SPEC.size():
		var spec: Array = STEP_SPEC[i]
		var step: WarriorAttackStep = SWORD_COMBO.steps[i]
		var tag := "%d타" % (i + 1)
		assert_almost_eq(step.damage_coefficient, float(spec[0]), TOL, "%s 계수" % tag)
		assert_almost_eq(step.hitbox_range_tiles, float(spec[1]), TOL, "%s 리치" % tag)
		assert_almost_eq(step.hitbox_angle_deg, float(spec[2]), TOL, "%s 판정각" % tag)
		assert_almost_eq(step.startup_sec, float(spec[3]), TOL, "%s 선딜" % tag)
		assert_almost_eq(step.active_sec, float(spec[4]), TOL, "%s 판정" % tag)
		assert_almost_eq(step.recovery_sec, float(spec[5]), TOL, "%s 후딜" % tag)
		assert_eq(step.hitstop_preset, String(spec[6]), "%s 히트스톱" % tag)


func test_step_total_motion_times() -> void:
	assert_almost_eq(SWORD_COMBO.steps[0].get_total_motion_sec(), 0.32, TOL, "1타 총 모션")
	assert_almost_eq(SWORD_COMBO.steps[1].get_total_motion_sec(), 0.32, TOL, "2타 총 모션")
	assert_almost_eq(SWORD_COMBO.steps[2].get_total_motion_sec(), 0.48, TOL, "3타 총 모션")


## 1장 핵심 설계 결정 — 사이클 총계수 2.30 / 총 시간 1.12초 → 계수/초 2.054로 대검과 동률.
func test_cycle_coefficient_per_second_matches_greatsword() -> void:
	var total_coefficient := 0.0
	var total_sec := 0.0
	for step in SWORD_COMBO.steps:
		total_coefficient += step.damage_coefficient
		total_sec += step.get_total_motion_sec()
	assert_almost_eq(total_coefficient, 2.30, TOL, "사이클 총계수")
	assert_almost_eq(total_sec, 1.12, TOL, "사이클 총 시간")
	assert_almost_eq(total_coefficient / total_sec, 2.054, 0.001, "계수/초")

	var sword_rate := total_coefficient / total_sec
	var greatsword_coefficient := 0.0
	var greatsword_sec := 0.0
	for step in WARRIOR_COMBO.steps:
		greatsword_coefficient += step.damage_coefficient
		greatsword_sec += step.get_total_motion_sec()
	var greatsword_rate := greatsword_coefficient / greatsword_sec
	## 의도적 동률(-1.4%) — 전직 시 기본 공격 화력의 계단을 만들지 않는다.
	assert_almost_eq(sword_rate / greatsword_rate, 1.0, 0.02, "대검 대비 계수/초 비율")


## 7-4장 #1 — 콤보 윈도우는 최대 후딜(3타 0.25초)보다 커야 후딜 구간 입력이 유실되지 않는다.
func test_combo_window_is_0_35_and_above_max_recovery() -> void:
	assert_almost_eq(SWORD_COMBO.combo_window_sec, 0.35, TOL, "콤보 윈도우")
	var max_recovery := 0.0
	for step in SWORD_COMBO.steps:
		max_recovery = maxf(max_recovery, step.recovery_sec)
	assert_gt(SWORD_COMBO.combo_window_sec, max_recovery, "윈도우 > 최대 후딜(입력 유실 하한)")


## 7-1장 — 모험가 회피는 표준 입력 방향 대시(후방 점프는 궁수 활 전용).
func test_dodge_is_not_backward() -> void:
	assert_false(SWORD_COMBO.dodge_backward, "모험가 회피 = 입력 방향 대시")


## 2장 — 1·2타 판정각 70°는 자동 조준 스냅 범위(±35°)와 일치해야 한다
## ("스냅이 성립한 대상은 반드시 판정에 들어온다" 보장).
func test_first_two_steps_match_auto_aim_snap_cone() -> void:
	var snap_cone_deg := PlayerController.AUTO_AIM_CONE_HALF_DEG * 2.0
	assert_almost_eq(SWORD_COMBO.steps[0].hitbox_angle_deg, snap_cone_deg, TOL, "1타 = 스냅 각")
	assert_almost_eq(SWORD_COMBO.steps[1].hitbox_angle_deg, snap_cone_deg, TOL, "2타 = 스냅 각")


# --- ② 배선: 모험가 시작 = 소검 / 전직 = 직업 무기 ---


func test_player_scene_starts_with_sword_combo() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	assert_eq(player.combo_data, SWORD_COMBO, "모험가 시작 = 소검 콤보")
	assert_eq(player.combo_data.steps.size(), 3, "시작 콤보는 3타")


func test_warrior_transition_swaps_to_greatsword() -> void:
	assert_eq(WARRIOR_DEF.basic_combo, WARRIOR_COMBO, "전사 JobDefinition = 대검 콤보")
	var player := _spawn_transitioned_player(&"warrior")
	assert_eq(player.combo_data, WARRIOR_COMBO, "전사 전직 후 대검으로 교체")
	assert_eq(player.combo_data.steps.size(), 2, "대검은 2타")
	assert_false(player.combo_data.dodge_backward, "전사 회피 = 입력 방향 대시")


func test_archer_transition_swaps_to_bow() -> void:
	assert_eq(ARCHER_DEF.basic_combo, ARCHER_COMBO, "궁수 JobDefinition = 활 콤보")
	var player := _spawn_transitioned_player(&"archer")
	assert_eq(player.combo_data, ARCHER_COMBO, "궁수 전직 후 활로 교체")
	assert_true(player.combo_data.dodge_backward, "궁수 회피 = 후방 점프")


## 전직 로드아웃 경로(디버그 직행 시작 = 실제 전직과 동일한 apply_transition_loadout)로
## 해당 직업 상태의 플레이어를 만든다. 공유 CombatantStats는 사본으로 격리한다.
func _spawn_transitioned_player(job_id: StringName) -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	var trans: PlayerJobTransition = player.get_node("PlayerJobTransition")
	trans.initial_job_id = job_id
	add_child_autofree(player)
	var growth: PlayerStatGrowth = player.get_node("PlayerStatGrowth")
	var fresh: CombatantStats = growth.combat_stats.duplicate()
	growth.combat_stats = fresh
	player.get_node("PlayerStats").stats = fresh
	player.get_node("AttackResolver").attacker_stats = fresh
	return player
