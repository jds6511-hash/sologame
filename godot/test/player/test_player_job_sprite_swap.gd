## M3 3-A 검증 ② — 직업 전용 스프라이트 시트 스왑과 없는 상태 폴백.
##
## 배선만 해서는 궁수 스프라이트가 화면에 나오지 않는다(player.tscn은 전사 시트로 시작한다).
## 전직 시 JobDefinition.sprite_frames가 Sprite 노드에 실제로 꽂히는지, 그리고 직업마다
## 상태 구성이 달라 요청한 상태가 시트에 없을 때 종전 이름으로 안전하게 접히는지 확인한다.
## 상태별 애니메이션 이름 조립은 test_player_sprite_states.gd 담당.
extends GutTest

const WARRIOR_DEF: JobDefinition = preload("res://data/jobs/job_def_warrior.tres")
const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")
const GLADIATOR_DEF: JobDefinition = preload("res://data/jobs/job_def_gladiator.tres")

var _player: PlayerController
var _sprite: AnimatedSprite2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_sprite = _player.get_node("Sprite")
	## 조준 각도를 오른쪽으로 고정해 방향 접미사를 side로 확정한다.
	_player._facing.rotation = 0.0
	_player._last_move_direction = Vector2.RIGHT


func _played_anim() -> String:
	_player._update_visual()
	return String(_sprite.animation)


# --- 시트 스왑 ---


func test_transition_to_archer_swaps_sheet() -> void:
	## 전직이 유발하는 스탯 재계산은 씬 인스턴스 사본에만 기록된다 — Lv1 스냅샷 .tres가
	## resource_local_to_scene이라 파일 리소스가 오염되지 않는다(수동 격리 불필요,
	## test/progression/test_shared_combat_stats_isolation.gd 검증).
	var transition: PlayerJobTransition = _player.get_node("PlayerJobTransition")
	transition.transition_available = true

	assert_true(transition.perform_transition(&"archer"), "전제: 궁수 전직 성공")

	assert_eq(
		_sprite.sprite_frames.resource_path,
		"res://assets/sprites/player/player_archer_frames.tres",
		"전직 시 궁수 시트로 교체돼야 함(배선만으로는 화면에 안 나온다)"
	)
	assert_true(_sprite.sprite_frames.has_animation("rollshot_front"), "궁수 전용 상태 사용 가능")


func test_job_without_own_sheet_keeps_current_sheet() -> void:
	## 검투사(2차)는 전용 시트가 아직 없다 — 전사 시트를 계속 쓰는 것이 정상이다.
	assert_null(GLADIATOR_DEF.sprite_frames, "전제: 검투사 전용 시트 미제작")
	var before := _sprite.sprite_frames

	_player.visual.set_job_sprite_frames(GLADIATOR_DEF.sprite_frames)

	assert_eq(_sprite.sprite_frames, before, "시트가 없는 직업은 직전 시트를 유지해야 함")


func test_sheet_swap_leaves_a_valid_animation() -> void:
	## 전사 전용 상태(attack2)를 재생하던 중 궁수 시트로 갈아타도 없는 애니메이션이 남지 않아야
	## 한다(교체 직후 한 프레임의 빈 스프라이트 방지).
	_player.apply_transition_loadout(WARRIOR_DEF.skill_loadout(), WARRIOR_DEF.basic_combo)
	_player._start_attack_step(1)
	assert_eq(_played_anim(), "attack2_side")

	_player.visual.set_job_sprite_frames(ARCHER_DEF.sprite_frames)

	assert_true(
		_sprite.sprite_frames.has_animation(_sprite.animation),
		"교체 후 재생 중인 애니메이션(%s)이 새 시트에 존재해야 함" % _sprite.animation
	)


# --- 폴백: 시트에 없는 상태는 종전 이름으로 접힌다 ---


func test_missing_attack2_falls_back_to_attack() -> void:
	_player.apply_transition_loadout(ARCHER_DEF.skill_loadout(), ARCHER_DEF.basic_combo)
	_player.visual.set_job_sprite_frames(ARCHER_DEF.sprite_frames)
	_player._start_attack_step(0)
	_player._attack_step_index = 1  ## 궁수 시트에는 attack2가 없다
	assert_eq(_played_anim(), "attack_side", "attack2가 없으면 기본 공격 모션으로 접혀야 함")


func test_missing_rollshot_falls_back_to_attack() -> void:
	## 전사 시트로 궁수 DASH 스킬 모션을 요청하는 교차 상황(로드아웃 전환 과도기 안전망).
	_player.skill_state = PlayerController.AttackState.ACTIVE
	_player.active_skill = ARCHER_DEF.skill_slot_q
	assert_eq(_played_anim(), "attack_side", "rollshot이 없으면 공격 모션으로 접혀야 함")


func test_empty_sprite_frames_does_not_crash() -> void:
	_sprite.sprite_frames = SpriteFrames.new()
	_sprite.sprite_frames.remove_animation("default")
	_player._is_charging_secondary = true

	_player._update_visual()  ## 후보가 전부 없는 경우 — 아무것도 재생하지 않고 조용히 넘어간다

	assert_eq(_sprite.sprite_frames.get_animation_names().size(), 0, "애니메이션이 하나도 없는 시트")


func test_gladiator_charge_uses_dodge_pose_facing_travel_direction() -> void:
	_player.set_physics_process(false)
	_player._last_move_direction = Vector2.UP
	_player._skills.start(GLADIATOR_DEF.skill_slot_q)
	assert_eq(_played_anim(), "dodge_back", "아트 계획 5-2: 난입 강타는 이동 방향으로 몸을 낮춤")
	assert_eq(_sprite.frame, 0)
	_player._skills.process_state(GLADIATOR_DEF.skill_slot_q.startup_sec)
	assert_eq(_played_anim(), "dodge_back")
	assert_eq(_sprite.frame, 1, "돌진 판정 동안 전진 자세")
	_player._last_move_direction = Vector2.DOWN
	assert_eq(_played_anim(), "dodge_back", "돌진 도중 다른 이동 입력이 들어와도 몸은 진행 방향 유지")
	_player._skills.process_state(GLADIATOR_DEF.skill_slot_q.get_active_duration_sec())
	assert_eq(_played_anim(), "dodge_back")
	assert_eq(_sprite.frame, 2, "돌진 종료 후 착지 자세")


func test_shared_sprint_uses_dodge_on_warrior_and_archer_sheets() -> void:
	_player.set_physics_process(false)
	for definition in [WARRIOR_DEF, ARCHER_DEF]:
		_player.visual.set_job_sprite_frames(definition.sprite_frames)
		_player._skills.begin_active(definition.skill_slot_2)
		assert_eq(_played_anim(), "dodge_side", "공용 질주는 활 사격이나 검 휘두르기가 아님")


func test_dodge_cancel_restarts_same_direction_travel_animation() -> void:
	_player.set_physics_process(false)
	_player._skills.begin_active(GLADIATOR_DEF.skill_slot_q)
	_player._skills.process_state(GLADIATOR_DEF.skill_slot_q.get_active_duration_sec())
	assert_eq(_played_anim(), "dodge_side")
	assert_eq(_sprite.frame, 2, "돌진 후딜 착지 자세")
	_player._start_dash()
	assert_eq(_played_anim(), "dodge_side")
	assert_eq(_sprite.frame, 0, "같은 방향 회피로 취소해도 새 도약을 처음부터 재생")
	assert_true(_sprite.is_playing())
