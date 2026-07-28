## M3 C-4 검증 ② — m3-archer-skills.md 2-2·5장. 궁수의 "조작감" 축을 확인한다:
## 기본 공격(활 사격, 계수 1.0·사이클 0.5초·투사체), 우클릭 조준 모드 스탠스(이동 x0.4·
## 관통 정밀 화살·사이클 0.65초), 후방 점프 회피. 스킬 4종은 test_archer_skill_slots.gd 담당.
extends GutTest

const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")

const TOL := 0.0001

var _player: PlayerController


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_player.apply_transition_loadout(ARCHER_DEF.skill_loadout(), ARCHER_DEF.basic_combo)


func after_each() -> void:
	for arrow in _spawned_arrows():
		arrow.free()


func _spawned_arrows() -> Array:
	var found: Array = []
	for child in get_tree().root.get_children():
		if child is ArrowProjectile:
			found.append(child)
	return found


# --- 기본 공격: 활 사격 (5·8장 — 계수 1.0, 사이클 0.5초, 16타일·초/5타일) ---


func test_basic_bow_shot_is_single_step_with_coefficient_one() -> void:
	assert_eq(_player.combo_data.steps.size(), 1, "활 사격은 단발 반복(전사 2타 콤보와 대비)")
	var step: WarriorAttackStep = _player.combo_data.steps[0]
	assert_almost_eq(step.damage_coefficient, 1.0, TOL)
	assert_almost_eq(step.get_total_motion_sec(), 0.5, TOL, "hipfire 사격 사이클 0.5초 = 약 2발/초")
	assert_eq(step.hitstop_preset, "약", "기본 비크리 화살 = 약(8-1장)")


func test_basic_bow_shot_fires_arrow_instead_of_melee_hitbox() -> void:
	_player._start_attack_step(0)
	_player._process_attack_state(0.2)  ## 선딜 0.2초 종료 → 발사

	assert_eq(_player.attack_state, PlayerController.AttackState.ACTIVE)
	assert_false(_player._attack_hitbox.monitoring, "원거리 기본 공격은 근접 히트박스를 열지 않아야 함")
	assert_eq(_spawned_arrows().size(), 1, "화살 1발 발사")


func test_basic_arrow_uses_basic_spec_values() -> void:
	_player._start_attack_step(0)
	_player._process_attack_state(0.2)
	var arrow: ArrowProjectile = _spawned_arrows()[0]
	## 16타일·초 x 16px = 256px/초, 사거리 5타일 x 16px = 80px, 비관통.
	assert_almost_eq(arrow._speed_px, 256.0, TOL)
	assert_almost_eq(arrow._remaining_distance, 80.0, TOL)
	assert_eq(arrow._pierce_remaining, 0)


# --- 조준 모드 (우클릭 스탠스 — 이동 x0.4 / 관통 3체 / 사거리 x1.5 / 속도 20 / 사이클 0.65초) ---


func test_aim_stance_is_recognized_on_secondary_slot() -> void:
	assert_not_null(_player._shots.aim_stance, "우클릭 슬롯이 조준 스탠스로 인식되어야 함")
	assert_almost_eq(_player._shots.aim_stance.aim_move_speed_multiplier, 0.4, TOL)
	assert_almost_eq(_player._shots.aim_stance.aim_shot_cycle_sec, 0.65, TOL)


func test_aim_stance_applies_move_speed_penalty() -> void:
	var walk := _player.movement_data.get_walk_speed_px_per_sec()
	assert_almost_eq(_player._resolve_move_speed_px(false), walk, TOL)

	_player._shots.is_aiming = true
	assert_almost_eq(_player._resolve_move_speed_px(false), walk * 0.4, TOL, "조준 중 이동 x0.4")
	assert_almost_eq(
		_player._resolve_move_speed_px(true), walk * 0.4, TOL, "조준 페널티가 공격 중 이동 페널티를 대체(곱하면 사실상 정지)"
	)


func test_aim_stance_slows_shot_cycle_to_065_sec() -> void:
	_player._shots.is_aiming = true
	var step: WarriorAttackStep = _player.combo_data.steps[0]
	assert_almost_eq(_player._attack_rate_for_step(step), 0.5 / 0.65, TOL)


func test_aim_stance_basic_shot_uses_piercing_precision_arrow() -> void:
	_player._shots.is_aiming = true
	_player._start_attack_step(0)
	## 조준 중에는 사이클이 0.65초로 늘어나므로 선딜 소요 실시간도 0.2 / (0.5/0.65) = 0.26초다
	## (부동소수 오차로 경계에서 미달할 수 있어 여유를 준다).
	_player._process_attack_state(0.27)
	assert_eq(_player.attack_state, PlayerController.AttackState.ACTIVE)

	var arrow: ArrowProjectile = _spawned_arrows()[0]
	assert_eq(arrow._pierce_remaining, 3, "조준 사격은 최대 3체 관통")
	assert_almost_eq(arrow._speed_px, 20.0 * 16.0, TOL, "정밀 사격 20타일·초")
	assert_almost_eq(arrow._remaining_distance, 7.5 * 16.0, TOL, "사거리 5.0 x 1.5 = 7.5타일")


func test_aim_stance_does_not_start_warrior_charge() -> void:
	_player._process_secondary_charge_start_input()
	assert_false(_player._is_charging_secondary, "궁수 우클릭은 차지가 아니라 스탠스")


func test_warrior_loadout_keeps_charge_path() -> void:
	## 전사 로드아웃에서는 조준 스탠스가 없어야 한다(원거리 분기가 근접에 새지 않음을 확인).
	var warrior_def: JobDefinition = load("res://data/jobs/job_def_warrior.tres")
	_player.apply_transition_loadout(warrior_def.skill_loadout(), warrior_def.basic_combo)
	assert_null(_player._shots.aim_stance)
	assert_almost_eq(_player._shots.move_speed_multiplier(), 1.0, TOL)
	assert_false(_player.combo_data.dodge_backward, "전사 대검은 입력 방향 대시 유지")


# --- 회피: 후방 점프 (2-2장 — 조준 반대 방향) ---


func test_archer_dodge_jumps_backward_from_aim_direction() -> void:
	assert_true(_player.combo_data.dodge_backward, "활 콤보는 후방 회피")
	_player._last_move_direction = Vector2.UP
	_player._facing.rotation = 0.0  ## 오른쪽 조준

	_player._start_dash()

	assert_eq(_player._dash_direction, Vector2.LEFT, "조준 반대 방향으로 튀어야 함")
