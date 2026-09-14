## 근접 공격의 검 궤적을 그리는 플레이어 전용 시각 효과.
class_name PlayerMeleeSwingVfx
extends Node2D

const ARC_HALF_ANGLE := deg_to_rad(72.0)
const ARC_SEGMENTS := 10
const INNER_RADIUS := 18.0
const OUTER_RADIUS := 25.0
const TRAIL_COLOR := Color("2ce8f5")
const EDGE_COLOR := Color("b4f7ff")
const RECOVERY_VISIBLE_RATIO := 0.55

var _player: PlayerController = null
var _facing: Node2D = null
var _trail_points := PackedVector2Array()
var _trail_alpha := 0.0


func _ready() -> void:
	_player = get_parent() as PlayerController
	if _player != null:
		_facing = _player.get_node_or_null("Facing") as Node2D
	visible = false


func _process(_delta: float) -> void:
	var phase := _current_melee_phase()
	if phase == PlayerController.AttackState.NONE:
		_hide_trail()
		return

	var progress := _player.get_action_phase_progress()
	var reveal := 1.0
	match phase:
		PlayerController.AttackState.STARTUP:
			_hide_trail()
			return
		PlayerController.AttackState.ACTIVE:
			## 짧은 판정 시간 안에서도 궤적의 선두가 전진해 검이 순간이동하지 않게 한다.
			reveal = lerpf(0.35, 1.0, progress)
			_trail_alpha = 1.0
		PlayerController.AttackState.RECOVERY:
			if progress >= RECOVERY_VISIBLE_RATIO:
				_hide_trail()
				return
			reveal = 1.0
			_trail_alpha = 1.0 - progress / RECOVERY_VISIBLE_RATIO

	_build_arc(reveal)
	visible = _trail_points.size() >= 2
	queue_redraw()


func _draw() -> void:
	if _trail_points.size() < 2 or _trail_alpha <= 0.0:
		return
	var edge := EDGE_COLOR
	edge.a = 0.9 * _trail_alpha
	var glow := TRAIL_COLOR
	glow.a = 0.38 * _trail_alpha
	draw_polyline(_trail_points, glow, 4.0, false)
	draw_polyline(_trail_points, edge, 1.25, false)


func _current_melee_phase() -> PlayerController.AttackState:
	if _player == null:
		return PlayerController.AttackState.NONE
	if _player.skill_state != PlayerController.AttackState.NONE:
		if _player.active_skill is ArcherSkillData:
			return PlayerController.AttackState.NONE
		return _player.skill_state
	if _player.attack_state == PlayerController.AttackState.NONE:
		return PlayerController.AttackState.NONE
	if _player.combo_data == null or _player._attack_step_index < 0:
		return PlayerController.AttackState.NONE
	if _player._attack_step_index >= _player.combo_data.steps.size():
		return PlayerController.AttackState.NONE
	if _player.combo_data.steps[_player._attack_step_index] is ArcherAttackStep:
		return PlayerController.AttackState.NONE
	return _player.attack_state


func _build_arc(reveal: float) -> void:
	_trail_points.clear()
	var facing_angle := _facing.rotation if _facing != null else 0.0
	var sweep_sign := -1.0 if _player._attack_step_index % 2 == 1 else 1.0
	var start_angle := facing_angle - ARC_HALF_ANGLE * sweep_sign
	var sweep_angle := ARC_HALF_ANGLE * 2.0 * reveal * sweep_sign
	var point_count := maxi(2, ceili(ARC_SEGMENTS * reveal) + 1)
	for index in range(point_count):
		var ratio := float(index) / float(point_count - 1)
		var angle := start_angle + sweep_angle * ratio
		var radius := lerpf(INNER_RADIUS, OUTER_RADIUS, ratio)
		_trail_points.append(Vector2.RIGHT.rotated(angle) * radius + Vector2(0.0, -10.0))


func _hide_trail() -> void:
	if not visible and _trail_points.is_empty():
		return
	visible = false
	_trail_alpha = 0.0
	_trail_points.clear()
	queue_redraw()
