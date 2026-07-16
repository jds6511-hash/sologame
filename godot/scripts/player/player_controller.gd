## 전사 캐릭터 컨트롤러 (CB-1) — 이동, 기본 공격(대검 2타 콤보), 회피 대시.
##
## 참조: docs/design/systems/combat.md 2~4장, docs/design/systems/m2-warrior-skills.md 2장.
## 데미지 실적용(CB-3)·피격/경직(CB-4)·스킬 슬롯(CB-2)·HitFeedback 연출(CB-7)은 이 스크립트의
## 범위 밖이며, 이후 태스크가 연동할 수 있도록 시그널과 공개 상태만 노출한다.
class_name PlayerController
extends CharacterBody2D

signal dash_started
signal dash_ended
signal attack_step_started(step_index: int, hitstop_preset: String)
signal attack_hit(step_index: int, target: Node)

enum AttackState { NONE, STARTUP, ACTIVE, RECOVERY }

@export var movement_data: PlayerMovementData
@export var combo_data: WarriorComboData

var attack_state: AttackState = AttackState.NONE
var is_dashing: bool = false
var is_dash_invincible: bool = false
var dash_charges: int = 0

var _move_input := Vector2.ZERO
var _last_move_direction := Vector2.DOWN  ## 대시 기본 방향(이동 입력 없을 시 마지막 방향 유지)
var _attack_step_index: int = -1
var _attack_phase_timer: float = 0.0
var _combo_window_timer: float = 0.0
var _queued_next_attack: bool = false
var _dash_timer: float = 0.0
var _dash_direction := Vector2.DOWN
var _dash_recharge_timers: Array[float] = []

@onready var _facing: Node2D = $Facing
@onready var _attack_hitbox: Area2D = $Facing/AttackHitbox
@onready var _attack_collision: CollisionPolygon2D = $Facing/AttackHitbox/CollisionPolygon2D
@onready var _debug_hitbox_visual: Polygon2D = $Facing/DebugHitboxVisual
@onready var _placeholder_sprite: Sprite2D = $PlaceholderSprite


func _ready() -> void:
	_setup_placeholder_sprite()
	dash_charges = movement_data.dash_charge_max
	_attack_hitbox.monitoring = false
	_debug_hitbox_visual.visible = false
	_attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	_move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _move_input.length_squared() > 0.0:
		_last_move_direction = _move_input.normalized()

	_update_dash_recharge(delta)
	_process_dodge_input()

	if is_dashing:
		_process_dash(delta)
	else:
		_process_attack_input()
		_process_attack_state(delta)
		if attack_state == AttackState.NONE:
			velocity = _move_input * movement_data.get_walk_speed_px_per_sec()
			_update_facing_to_mouse()
		else:
			velocity = Vector2.ZERO

	move_and_slide()


# --- 이동/조준 ---


func _update_facing_to_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	if mouse_pos.distance_squared_to(global_position) > 0.01:
		_facing.look_at(mouse_pos)
	if _placeholder_sprite:
		_placeholder_sprite.flip_h = mouse_pos.x < global_position.x


# --- 기본 공격 콤보 (m2-warrior-skills.md 2장 "대검 2타 콤보") ---


func _process_attack_input() -> void:
	if not Input.is_action_just_pressed("attack"):
		return
	if attack_state == AttackState.NONE:
		_start_attack_step(0)
	elif _combo_window_timer > 0.0 and _attack_step_index < combo_data.steps.size() - 1:
		_queued_next_attack = true


func _start_attack_step(step_index: int) -> void:
	_attack_step_index = step_index
	attack_state = AttackState.STARTUP
	_attack_phase_timer = 0.0
	_combo_window_timer = 0.0
	_queued_next_attack = false
	var step: WarriorAttackStep = combo_data.steps[step_index]
	attack_step_started.emit(step_index, step.hitstop_preset)


func _process_attack_state(delta: float) -> void:
	if attack_state == AttackState.NONE:
		return
	_attack_phase_timer += delta
	var step: WarriorAttackStep = combo_data.steps[_attack_step_index]
	match attack_state:
		AttackState.STARTUP:
			if _attack_phase_timer >= step.startup_sec:
				attack_state = AttackState.ACTIVE
				_attack_phase_timer = 0.0
				_enable_attack_hitbox(step)
		AttackState.ACTIVE:
			if _attack_phase_timer >= step.active_sec:
				attack_state = AttackState.RECOVERY
				_attack_phase_timer = 0.0
				_disable_attack_hitbox()
				_combo_window_timer = combo_data.combo_window_sec
		AttackState.RECOVERY:
			_combo_window_timer = max(_combo_window_timer - delta, 0.0)
			if _attack_phase_timer >= step.recovery_sec:
				if _queued_next_attack and _attack_step_index < combo_data.steps.size() - 1:
					_start_attack_step(_attack_step_index + 1)
				else:
					_end_combo()


func _end_combo() -> void:
	attack_state = AttackState.NONE
	_attack_step_index = -1
	_combo_window_timer = 0.0
	_queued_next_attack = false


func _enable_attack_hitbox(step: WarriorAttackStep) -> void:
	var radius_px := step.hitbox_range_tiles * movement_data.tile_size_px
	var polygon := _build_sector_polygon(radius_px, step.hitbox_angle_deg)
	_attack_collision.polygon = polygon
	_debug_hitbox_visual.polygon = polygon
	_attack_hitbox.monitoring = true
	_debug_hitbox_visual.visible = true


func _disable_attack_hitbox() -> void:
	_attack_hitbox.monitoring = false
	_debug_hitbox_visual.visible = false


## 부채꼴 판정 범위를 근사하는 다각형 생성(로컬 +X가 정면). segments가 클수록 매끄럽다.
func _build_sector_polygon(
	radius_px: float, angle_deg: float, segments: int = 8
) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var half_angle := deg_to_rad(angle_deg) * 0.5
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := -half_angle + t * (half_angle * 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * radius_px)
	return points


func _on_attack_hitbox_body_entered(body: Node) -> void:
	# 데미지 계산(CB-3)·히트스톱 연출(CB-7)은 이후 태스크 담당 — 여기서는 판정 성립만 알린다.
	attack_hit.emit(_attack_step_index, body)


# --- 회피 대시 (combat.md 4장) ---


func _process_dodge_input() -> void:
	if not Input.is_action_just_pressed("dodge"):
		return
	if is_dashing or dash_charges <= 0:
		return
	_start_dash()


func _start_dash() -> void:
	if attack_state != AttackState.NONE:
		_disable_attack_hitbox()
		_end_combo()
	dash_charges -= 1
	_dash_recharge_timers.append(movement_data.dash_recharge_sec)
	_dash_direction = _last_move_direction
	is_dashing = true
	is_dash_invincible = false
	_dash_timer = 0.0
	dash_started.emit()


func _process_dash(delta: float) -> void:
	_dash_timer += delta
	is_dash_invincible = (
		_dash_timer >= movement_data.dash_invincibility_start_sec
		and _dash_timer <= movement_data.get_dash_invincibility_end_sec()
	)
	if _dash_timer >= movement_data.dash_duration_sec:
		is_dashing = false
		is_dash_invincible = false
		velocity = Vector2.ZERO
		dash_ended.emit()
		return
	velocity = _dash_direction * movement_data.get_dash_speed_px_per_sec()


func _update_dash_recharge(delta: float) -> void:
	for i in range(_dash_recharge_timers.size() - 1, -1, -1):
		_dash_recharge_timers[i] -= delta
		if _dash_recharge_timers[i] <= 0.0:
			_dash_recharge_timers.remove_at(i)
			dash_charges = mini(dash_charges + 1, movement_data.dash_charge_max)


# --- 임시 플레이스홀더 비주얼 ---
# TODO(pixel-artist AR-1 완료 시 교체): godot/assets/sprites/player/ 에 대검 전사
# idle/walk/attack/hit/death(32x32, 3방향) 스프라이트가 준비되면 이 Sprite2D를
# AnimatedSprite2D + SpriteFrames로 교체하고, 아래 절차적 placeholder 생성 로직은 제거한다.
func _setup_placeholder_sprite() -> void:
	if not _placeholder_sprite:
		return
	if _placeholder_sprite.texture != null:
		return
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.75, 1.0))
	_placeholder_sprite.texture = ImageTexture.create_from_image(image)


# --- 디버그 HUD 연동용 상태 조회 ---


func get_debug_state_text() -> String:
	if is_dashing:
		return "회피 대시%s" % (" (무적)" if is_dash_invincible else "")
	match attack_state:
		AttackState.STARTUP:
			return "공격 %d타 - 선딜" % (_attack_step_index + 1)
		AttackState.ACTIVE:
			return "공격 %d타 - 판정" % (_attack_step_index + 1)
		AttackState.RECOVERY:
			return "공격 %d타 - 후딜" % (_attack_step_index + 1)
		_:
			return "이동" if _move_input.length_squared() > 0.0 else "대기"
