## 전사 기본 공격 QoL 4종 회귀 검증 (디렉터 지시) —
##   ① 홀드 연타(콤보 자동 지속) ② 적 자동 조준 스냅 ③ 스윙 중 재조준(STARTUP만)
##   ④ 공격 중 이동 허용(속도 페널티).
## 각 기능은 player_controller.gd에 상수로 노출된 튜닝값(AUTO_AIM_CONE_HALF_DEG /
## AUTO_AIM_RANGE_TILES / ATTACK_MOVE_SPEED_MULTIPLIER)을 기준으로 검증한다.
extends GutTest


## 자동 조준 후보용 경량 더미 — Node2D + is_dead() duck typing만 있으면 충분하다
## (실제 MonsterBase를 띄우지 않고 스냅 로직만 격리 검증).
class DummyMonster:
	extends Node2D
	var dead: bool = false

	func is_dead() -> bool:
		return dead


var _player: PlayerController


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2.ZERO


func after_each() -> void:
	## 입력 상태가 다음 테스트로 새지 않도록 명시적으로 해제한다.
	for action in ["attack", "move_right", "move_left", "move_up", "move_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _make_dummy(pos: Vector2, is_dead_flag: bool = false) -> DummyMonster:
	var dummy := DummyMonster.new()
	add_child_autofree(dummy)
	dummy.global_position = pos
	dummy.dead = is_dead_flag
	return dummy


# --- ① 홀드 연타 ---


func test_hold_starts_combo_from_idle() -> void:
	assert_eq(_player.attack_state, PlayerController.AttackState.NONE)
	_player._advance_attack_from_input(true)
	assert_eq(_player.attack_state, PlayerController.AttackState.STARTUP, "홀드 시작 시 콤보가 시작되어야 한다")
	assert_eq(_player._attack_step_index, 0)


func test_hold_queues_next_during_combo_window() -> void:
	## RECOVERY + 콤보 윈도우 열림 상태에서 홀드 유지 시 다음 타 자동 예약.
	_player.attack_state = PlayerController.AttackState.RECOVERY
	_player._attack_step_index = 0
	_player._combo_window_timer = 0.3
	_player._queued_next_attack = false
	_player._advance_attack_from_input(true)
	assert_true(_player._queued_next_attack, "홀드 중 콤보 윈도우에서 다음 타가 자동 예약되어야 한다")


func test_release_does_not_queue() -> void:
	_player.attack_state = PlayerController.AttackState.RECOVERY
	_player._attack_step_index = 0
	_player._combo_window_timer = 0.3
	_player._advance_attack_from_input(false)
	assert_false(_player._queued_next_attack, "버튼을 뗀 프레임에는 예약되지 않아야 한다")


func test_hold_does_not_queue_past_last_step() -> void:
	var last := _player.combo_data.steps.size() - 1
	_player.attack_state = PlayerController.AttackState.RECOVERY
	_player._attack_step_index = last
	_player._combo_window_timer = 0.3
	_player._advance_attack_from_input(true)
	assert_false(_player._queued_next_attack, "마지막 타에서는 콤보 내 다음 타 예약이 없어야 한다")


func test_hold_restarts_combo_after_end() -> void:
	_player._end_combo()
	assert_eq(_player.attack_state, PlayerController.AttackState.NONE)
	_player._advance_attack_from_input(true)
	assert_eq(_player.attack_state, PlayerController.AttackState.STARTUP)
	assert_eq(_player._attack_step_index, 0, "콤보 종료 후 홀드 유지 시 첫 타부터 다시 시작해야 한다")


# --- ② 적 자동 조준 스냅 ---


func test_auto_aim_snaps_to_nearest_in_cone() -> void:
	var tile := _player.movement_data.tile_size_px
	var far := _make_dummy(Vector2(tile * 2.0, 0.0))
	var near := _make_dummy(Vector2(tile * 1.0, 0.0))
	_player._aim_candidates = [far, near]
	assert_eq(_player._find_auto_aim_target(Vector2.RIGHT), near, "콘 안에서 가장 가까운 적으로 스냅해야 한다")


func test_auto_aim_ignores_out_of_cone() -> void:
	var tile := _player.movement_data.tile_size_px
	## 마우스 방향(RIGHT) 기준 90° 벗어난 적(±35° 콘 밖) — 스냅 대상 아님.
	var side := _make_dummy(Vector2(0.0, tile))
	_player._aim_candidates = [side]
	assert_null(_player._find_auto_aim_target(Vector2.RIGHT), "콘(±35°) 밖의 적은 스냅하지 않는다")


func test_auto_aim_ignores_out_of_range() -> void:
	var tile := _player.movement_data.tile_size_px
	var over := (PlayerController.AUTO_AIM_RANGE_TILES + 1.0) * tile
	var far := _make_dummy(Vector2(over, 0.0))
	_player._aim_candidates = [far]
	assert_null(_player._find_auto_aim_target(Vector2.RIGHT), "사거리 밖의 적은 스냅하지 않는다")


func test_auto_aim_skips_dead() -> void:
	var tile := _player.movement_data.tile_size_px
	var dead := _make_dummy(Vector2(tile, 0.0), true)
	_player._aim_candidates = [dead]
	assert_null(_player._find_auto_aim_target(Vector2.RIGHT), "죽은 적은 스냅 대상에서 제외한다")


# --- ③ 스윙 중 재조준 (STARTUP만 갱신, ACTIVE 이후 고정) ---


func test_reaim_tracks_target_during_startup() -> void:
	var tile := _player.movement_data.tile_size_px
	## 헤드리스 환경의 마우스는 원점 근처에 있으므로, 플레이어를 원점에서 충분히 떨어뜨려
	## "커서 방향"이 결정적으로 존재하게 만든 뒤, 그 방향(콘 정중앙)에 대상을 배치한다 —
	## 자동 조준이 마우스보다 우선하므로 결과 각도가 결정적이 된다.
	_player.global_position = Vector2(200, 200)
	var aim_dir := _player.get_global_mouse_position() - _player.global_position
	aim_dir = aim_dir.normalized() if aim_dir.length_squared() > 1.0 else Vector2.LEFT
	var dummy := _make_dummy(_player.global_position + aim_dir * tile)
	_player._aim_candidates = [dummy]

	_player._apply_attack_aim()
	var rot_a := _player._facing.rotation
	assert_almost_eq(rot_a, aim_dir.angle(), 0.05, "재조준 시 Facing이 자동 조준 대상을 향해야 한다")

	## 대상을 콘 안(20°)에서 이동 → STARTUP 재조준이 따라와야 한다.
	var moved_dir := aim_dir.rotated(deg_to_rad(20.0))
	dummy.global_position = _player.global_position + moved_dir * tile
	_player._apply_attack_aim()
	var rot_b := _player._facing.rotation
	assert_almost_eq(rot_b, moved_dir.angle(), 0.05, "STARTUP 재조준이 이동한 대상을 따라가야 한다")
	assert_ne(rot_a, rot_b, "방향이 실제로 갱신되어야 한다")


func test_reaim_frozen_after_active_state() -> void:
	## ACTIVE 상태의 물리 프레임에서는 _apply_attack_aim이 호출되지 않아 방향이 고정된다.
	_player.attack_state = PlayerController.AttackState.ACTIVE
	_player._attack_step_index = 0
	_player._attack_phase_timer = 0.0
	var frozen_rot := 1.234
	_player._facing.rotation = frozen_rot
	_player._aim_candidates = [_make_dummy(Vector2(_player.movement_data.tile_size_px, 0.0))]

	await wait_physics_frames(1)

	assert_almost_eq(_player._facing.rotation, frozen_rot, 0.001, "ACTIVE 진입 이후에는 재조준이 고정되어야 한다")


# --- ④ 공격 중 이동 허용(속도 페널티) ---


func test_move_penalty_during_attack() -> void:
	Input.action_press("move_right")
	_player.attack_state = PlayerController.AttackState.STARTUP
	_player._attack_step_index = 0
	_player._attack_phase_timer = 0.0

	await wait_physics_frames(1)

	var walk := _player.movement_data.get_walk_speed_px_per_sec()
	var expected := walk * PlayerController.ATTACK_MOVE_SPEED_MULTIPLIER
	assert_almost_eq(_player.velocity.length(), expected, 1.0, "공격 중 이동 속도는 평소의 45%여야 한다")
	assert_gt(_player.velocity.length(), 0.0, "공격 중에도 이동 입력이 반영되어야 한다(정지 아님)")


func test_move_full_speed_when_not_attacking() -> void:
	Input.action_press("move_right")
	_player.attack_state = PlayerController.AttackState.NONE

	await wait_physics_frames(1)

	var walk := _player.movement_data.get_walk_speed_px_per_sec()
	assert_almost_eq(_player.velocity.length(), walk, 1.0, "비공격 시 이동은 100% 속도여야 한다(페널티 대조군)")


# --- 공격 애니메이션 재시작 회귀 (디렉터 지적: 스윙 모션이 안 보임) ---
# 콤보/홀드 내내 anim_name이 "attack_*"로 고정돼도, 각 스윙(스텝 진입)마다 애니메이션이
# 프레임0부터 다시 재생되어야 스윙 모션이 보인다(재시작 가드 우회 검증).


func test_attack_step_start_requests_anim_restart() -> void:
	_player._attack_anim_restart_requested = false
	_player._start_attack_step(0)
	assert_true(_player._attack_anim_restart_requested, "공격 스텝 진입 시 애니메이션 재시작이 요청되어야 한다")


func test_attack_step_replays_animation_from_frame0() -> void:
	var sprite: AnimatedSprite2D = _player._sprite
	## 첫 스윙 — 비주얼 반영 후 공격 애니메이션이 걸려야 한다(기본 조준 = 측면).
	_player._start_attack_step(0)
	_player._update_visual()
	assert_eq(sprite.animation, "attack_side", "공격 시작 시 attack_side가 재생되어야 한다")
	## 스윙이 끝나 마지막 프레임에 머문 상황을 모사(loop=false라 실제로도 마지막 프레임 고정).
	sprite.set_frame_and_progress(3, 0.0)
	assert_eq(sprite.frame, 3)

	## 콤보 다음 스텝(새 스윙) 진입 → 같은 anim_name이지만 프레임0부터 다시 재생돼야 한다.
	_player._start_attack_step(1)
	_player._update_visual()
	assert_eq(sprite.frame, 0, "새 스윙에서 공격 애니메이션이 프레임0부터 재생되어야 한다")
	assert_true(sprite.is_playing(), "새 스윙에서 공격 애니메이션이 재생 상태여야 한다")
	assert_false(_player._attack_anim_restart_requested, "재시작 요청은 1회성으로 소비되어야 한다")


func test_visual_does_not_restart_attack_without_request() -> void:
	## 재시작 요청이 없으면(같은 상태 지속) 프레임을 매 프레임 0으로 되감지 않아야 한다
	## (기존 재시작 가드 유지 — 불필요한 재시작 방지).
	var sprite: AnimatedSprite2D = _player._sprite
	_player._start_attack_step(0)
	_player._update_visual()
	sprite.set_frame_and_progress(2, 0.0)
	_player._attack_anim_restart_requested = false
	_player._update_visual()
	assert_eq(sprite.frame, 2, "재시작 요청이 없으면 진행 중인 공격 프레임을 되감지 않아야 한다")
