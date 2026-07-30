## M3 3-A 검증 — 정식 스프라이트(직업당 9상태 x 3방향) 씬 배선과 신규 상태 재생.
##
## pixel-artist가 만든 시트(`player_warrior_v2_frames.tres` / `player_archer_frames.tres`)에는
## M2에 없던 상태가 들어 있다: 전사 attack2·charge·cast, 궁수 aim·rollshot·cast, 공통 dodge.
## 이 파일은 셋을 확인한다:
##   ① 씬이 M2 인라인 SpriteFrames가 아니라 정식 시트 .tres를 참조하는가
##   ② 각 상태가 실제로 그 이름의 애니메이션으로 재생되는가(PlayerVisualModule 이름 조립)
## 시트 스왑과 폴백은 test_player_job_sprite_swap.gd 담당.
extends GutTest

const WARRIOR_DEF: JobDefinition = preload("res://data/jobs/job_def_warrior.tres")
const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")

## 3방향 시트의 상태 1개당 애니메이션 수(front/side/back).
const DIRECTIONS := 3

var _player: PlayerController
var _sprite: AnimatedSprite2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_sprite = _player.get_node("Sprite")
	## 조준 각도를 오른쪽으로 고정해 방향 접미사를 side로 확정한다(좌우는 flip_h로 근사).
	_player._facing.rotation = 0.0
	_player._last_move_direction = Vector2.RIGHT


## 현재 상태로 애니메이션을 갱신하고 재생 중인 이름을 돌려준다.
func _played_anim() -> String:
	_player._update_visual()
	return String(_sprite.animation)


func _use_archer_loadout() -> void:
	_player.apply_transition_loadout(ARCHER_DEF.skill_loadout(), ARCHER_DEF.basic_combo)
	_player.visual.set_job_sprite_frames(ARCHER_DEF.sprite_frames)


# --- ① 씬 배선: 구 인라인 SpriteFrames가 아니라 정식 시트 .tres를 쓴다 ---


func test_player_scene_uses_official_warrior_sheet() -> void:
	assert_eq(
		_sprite.sprite_frames.resource_path,
		"res://assets/sprites/player/player_warrior_v2_frames.tres",
		"player.tscn Sprite가 M3 정식 전사 시트를 참조해야 함(M2 인라인 SpriteFrames 대체)"
	)
	assert_eq(_sprite.offset, Vector2(0, -18), "프레임 높이 36 불변 — 발밑 정렬 오프셋 유지")


func test_official_sheets_expose_nine_states_each() -> void:
	var warrior: SpriteFrames = WARRIOR_DEF.sprite_frames
	var archer: SpriteFrames = ARCHER_DEF.sprite_frames
	assert_eq(warrior.get_animation_names().size(), 9 * DIRECTIONS, "전사 9상태 x 3방향")
	assert_eq(archer.get_animation_names().size(), 9 * DIRECTIONS, "궁수 9상태 x 3방향")


func test_job_sheets_have_their_own_exclusive_states() -> void:
	var warrior: SpriteFrames = WARRIOR_DEF.sprite_frames
	var archer: SpriteFrames = ARCHER_DEF.sprite_frames
	assert_true(warrior.has_animation("attack2_side"), "전사 전용 2타 횡베기")
	assert_true(warrior.has_animation("charge_side"), "전사 전용 차지 홀드")
	assert_false(archer.has_animation("attack2_side"), "궁수 활은 단발 반복이라 2타가 없다")
	assert_true(archer.has_animation("aim_side"), "궁수 전용 조준 스탠스")
	assert_true(archer.has_animation("rollshot_side"), "궁수 전용 곡예 사격")
	assert_false(warrior.has_animation("rollshot_side"), "전사에는 곡예 사격이 없다")


# --- ② 종전 5상태 회귀 (idle/walk/attack/hit/death) ---


func test_idle_and_walk_still_play() -> void:
	assert_eq(_played_anim(), "idle_side", "정지 = 대기")
	_player._move_input = Vector2.RIGHT
	assert_eq(_played_anim(), "walk_side")


func test_hit_and_death_take_priority() -> void:
	_player._move_input = Vector2.RIGHT
	_player.is_hit_stunned = true
	assert_eq(_played_anim(), "hit_side", "피격 경직이 이동보다 우선")

	_player.is_hit_stunned = false
	## take_damage는 _die()에서 즉시 부활시켜 is_dead()가 남지 않으므로 HP를 직접 0으로 둔다.
	_player._stats.current_hp = 0.0
	assert_eq(_played_anim(), "death_side", "사망이 최우선")


func test_first_combo_step_plays_base_attack() -> void:
	_player.apply_transition_loadout(WARRIOR_DEF.skill_loadout(), WARRIOR_DEF.basic_combo)
	_player._start_attack_step(0)
	assert_eq(_played_anim(), "attack_side", "1타는 내려베기(attack)")


# --- ③ 신규 상태 재생 (핵심) ---


func test_second_combo_step_plays_attack2() -> void:
	_player.apply_transition_loadout(WARRIOR_DEF.skill_loadout(), WARRIOR_DEF.basic_combo)
	_player._start_attack_step(1)
	assert_eq(_played_anim(), "attack2_side", "전사 2타는 횡베기 전용 모션이어야 함")


func test_charge_hold_plays_charge_not_attack() -> void:
	_player.apply_transition_loadout(WARRIOR_DEF.skill_loadout(), WARRIOR_DEF.basic_combo)
	_player._is_charging_secondary = true
	assert_eq(_played_anim(), "charge_side", "차지 홀드는 attack으로 접히지 않아야 함(M2 회귀 지점)")


func test_buff_skill_plays_cast() -> void:
	_player.apply_transition_loadout(WARRIOR_DEF.skill_loadout(), WARRIOR_DEF.basic_combo)
	_player.skill_state = PlayerController.AttackState.STARTUP
	_player.active_skill = WARRIOR_DEF.skill_slot_e  ## 결의의 외침 = BUFF_HEAL
	assert_eq(_player.active_skill.skill_type, WarriorSkillData.SkillType.BUFF_HEAL, "전제: 버프 스킬")
	assert_eq(_played_anim(), "cast_side", "버프·힐 스킬은 시전(포효) 모션")


func test_attack_skill_still_plays_attack() -> void:
	_player.apply_transition_loadout(WARRIOR_DEF.skill_loadout(), WARRIOR_DEF.basic_combo)
	_player.skill_state = PlayerController.AttackState.ACTIVE
	_player.active_skill = WARRIOR_DEF.skill_slot_4  ## 분쇄 베기 = INSTANT
	assert_eq(_played_anim(), "attack_side", "판정 스킬은 종전대로 공격 모션")


func test_dodge_dash_plays_dodge() -> void:
	_player.is_dashing = true
	assert_eq(_played_anim(), "dodge_side", "회피 대시는 도약 모션")


func test_archer_aim_stance_plays_aim() -> void:
	_use_archer_loadout()
	_player._shots.is_aiming = true
	assert_eq(_played_anim(), "aim_side", "조준 스탠스는 사격 사이클 사이에 조준 자세")


func test_archer_aim_stance_faces_aim_direction_while_moving() -> void:
	_use_archer_loadout()
	_player._shots.is_aiming = true
	_player._facing.rotation = -PI / 2.0  ## 위쪽 조준
	_player._move_input = Vector2.RIGHT  ## 오른쪽으로 곁걸음
	assert_eq(_played_anim(), "aim_back", "조준 스탠스는 이동 방향이 아니라 조준 방향을 향해야 함")


func test_archer_shooting_plays_attack_not_aim() -> void:
	_use_archer_loadout()
	_player._shots.is_aiming = true
	_player._start_attack_step(0)
	assert_eq(_played_anim(), "attack_side", "조준 중 사격 순간은 사격 모션")


func test_archer_acrobatic_shot_plays_rollshot() -> void:
	_use_archer_loadout()
	_player.skill_state = PlayerController.AttackState.ACTIVE
	_player.active_skill = ARCHER_DEF.skill_slot_q  ## 곡예 사격 = 궁수 DASH
	assert_eq(_player.active_skill.skill_type, WarriorSkillData.SkillType.DASH, "전제: 이동 사격")
	assert_eq(_played_anim(), "rollshot_side", "곡예 사격은 구르며 사격 모션")


func test_archer_backward_dodge_faces_aim_direction() -> void:
	_use_archer_loadout()
	_player._facing.rotation = 0.0  ## 오른쪽(적) 조준
	_player._start_dash()  ## 후방 점프 — 실제 이동은 왼쪽
	assert_eq(_player._dash_direction, Vector2.LEFT, "전제: 조준 반대로 튄다")
	assert_eq(_played_anim(), "dodge_side", "후방 점프도 dodge 시트")
	assert_false(_sprite.flip_h, "적을 계속 겨눈 채 뒤로 뛰므로 몸은 조준(오른쪽)을 향한다")


func test_archer_hawk_eye_plays_cast() -> void:
	_use_archer_loadout()
	_player.skill_state = PlayerController.AttackState.STARTUP
	_player.active_skill = ARCHER_DEF.skill_slot_e  ## 매의 눈 = BUFF_HEAL
	assert_eq(_played_anim(), "cast_side", "궁수 자가 버프도 시전 모션")
