## 실제 피격으로만 시련 목표를 기록한다. 월드 보상/드롭 배선에는 등록하지 않는다.
extends MonsterBase

signal objective_met(source: String, instance: Node)

var trial_source := ""
var credited := false
var _phase := 0.0
var _charge := Vector2.ZERO
var _struck := false
var _arrow_context: Array = []


func begin_trial_arrow(distance_tiles: float) -> void:
	_arrow_context.append([has_meta("trial_arrow_distance"), get_meta("trial_arrow_distance", -1.0)])
	set_meta("trial_arrow_distance", distance_tiles * 16.0)


func end_trial_arrow() -> void:
	if _arrow_context.is_empty():
		return
	var previous: Array = _arrow_context.pop_back()
	if previous[0]:
		set_meta("trial_arrow_distance", previous[1])
	else:
		remove_meta("trial_arrow_distance")


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	shape.position = Vector2(0, -9)
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7
	capsule.height = 20
	shape.shape = capsule
	add_child(shape)
	super._ready()


func take_damage(amount: float, grade: String = "약", attacker: Node2D = null) -> void:
	if is_dead() or credited or amount <= 0 or attacker != target:
		return
	var previous := hp
	super.take_damage(amount, grade, attacker)
	if hp >= previous:
		return
	var valid := false
	match trial_source:
		"trial_war_heavy":
			valid = hp <= 0 and grade == "강"
		"trial_war_guard", "trial_arc_moving":
			valid = hp <= 0
		"trial_arc_near":
			var distance: float = get_meta("trial_arrow_distance", -1.0)
			valid = distance >= 0 and distance <= 64
		"trial_arc_far":
			valid = float(get_meta("trial_arrow_distance", -1.0)) >= 128
	if valid:
		credited = true
		objective_met.emit(trial_source, self)
		queue_free()


func _physics_process(delta: float) -> void:
	if is_dead() or not is_instance_valid(target):
		return
	if target.get_node("PlayerStats").is_dead():
		velocity = Vector2.ZERO
		return
	_phase += delta
	if trial_source == "trial_arc_moving":
		velocity = Vector2(45 if sin(_phase * 1.5) > 0 else -45, 0)
		if absf(global_position.x - home_position.x) > 80:
			velocity.x = signf(home_position.x - global_position.x) * 45
	elif trial_source in ["trial_war_heavy", "trial_war_guard"]:
		# 0.8초 방향 고정 예고 → 0.5초 돌진 → 1.2초 회복. 접촉 피해는 한 번.
		if _phase < 0.8:
			_charge = (target.global_position - global_position).normalized()
			velocity = Vector2.ZERO
		elif _phase < 1.3:
			velocity = _charge * (150 if trial_source == "trial_war_guard" else 75)
			if not _struck and global_position.distance_to(target.global_position) < 20:
				_struck = true
				attack_landed.emit(target)
		else:
			velocity = Vector2.ZERO
			if _phase >= 2.5:
				_phase = 0
				_struck = false
	else:
		velocity = Vector2.ZERO
	if _guard_finite_before_move():
		move_and_slide()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, -9), 9, Color("c0a477"))
	draw_arc(Vector2(0, -9), 5, 0, TAU, 16, Color("663931"), 2)
	if trial_source.begins_with("trial_war") and _phase < 0.8:
		draw_line(Vector2.ZERO, _charge * 75, Color("ff5260"), 3)
