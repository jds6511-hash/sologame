class_name WarlordMonster
extends MonsterBase
## 예고 다각형의 고정 월드 좌표를 실제 판정에도 사용한다.

signal summon_requested(count: int)

const Content := preload("res://scripts/content/game_content.gd")
const SPEC: Dictionary = Content.BOSS_PATTERNS.warlord
const PATTERNS := {"cone": SPEC.slash, "dash": SPEC.dash, "disc": SPEC.shockwave}

var support_enabled := false
var phase := 1
var remaining_sec := 0.0
var attack_polygon := PackedVector2Array()
var _state := "idle"
var _pattern := "cone"
var _pattern_index := 0
var _summoned := false
var _suspended := false
var _origin := Vector2.ZERO
var _direction := Vector2.RIGHT
var _dash_travel := 0.0
var _hit_targets: Dictionary = {}
var _telegraph: Polygon2D


func _ready() -> void:
	super._ready()
	single_hit_per_activation = true
	_telegraph = Polygon2D.new()
	_telegraph.name = "PatternTelegraph"
	_telegraph.color = MELEE_TELEGRAPH_COLOR
	_telegraph.show_behind_parent = true
	add_child(_telegraph)
	_telegraph.top_level = true
	_telegraph.global_position = Vector2.ZERO
	_telegraph.hide()
	groggy_started.connect(_cancel_pattern)


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _suspended or is_dead() or is_groggy() or delta <= 0.0:
		return
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	if target.has_method("is_dead") and target.is_dead():
		suspend()
		return
	if _state == "idle":
		var sequence: Array = ["cone"]
		if phase == 2:
			sequence = ["cone", "dash"]
		elif phase == 3:
			sequence = ["cone", "dash", "disc"]
		var next: String = sequence[_pattern_index % sequence.size()]
		var reach: float = SPEC.dash.length if next == "dash" else PATTERNS[next].radius
		if global_position.distance_to(target.global_position) > reach * 0.8:
			velocity = move_toward_point(target.global_position, stats.combat_move_speed_tiles)
			if _guard_finite_before_move():
				move_and_slide()
			return
		begin_pattern(next)
		_pattern_index += 1
		return
	if _state == "active":
		if _pattern == "dash":
			_advance_dash(minf(delta, remaining_sec))
		else:
			_try_hit()
	remaining_sec = maxf(0.0, remaining_sec - delta)
	if remaining_sec > 0.0:
		return
	match _state:
		"telegraph":
			_state = "active"
			remaining_sec = (
				float(SPEC.dash.length) / float(SPEC.dash.speed)
				if _pattern == "dash"
				else float(PATTERNS[_pattern].active)
			)
			current_attack_multiplier = PATTERNS[_pattern].damage_multiplier
			_telegraph.color = Color(1.0, 0.3, 0.05, 0.48)
			if _pattern != "dash":
				_try_hit()
		"active":
			_state = "recovery"
			remaining_sec = PATTERNS[_pattern]["recovery"]
			current_attack_multiplier = 1.0
			_telegraph.hide()
		"recovery":
			_state = "idle"


func begin_pattern(pattern: String) -> void:
	if _suspended or is_dead() or is_groggy() or not PATTERNS.has(pattern):
		return
	_cancel_pattern()
	_pattern = pattern
	_origin = global_position
	var offset := target.global_position - _origin if is_instance_valid(target) else Vector2.RIGHT
	_direction = offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
	attack_polygon = _make_polygon(pattern)
	_telegraph.polygon = attack_polygon
	_telegraph.color = MELEE_TELEGRAPH_COLOR
	_telegraph.show()
	_state = "telegraph"
	remaining_sec = PATTERNS[pattern]["telegraph"]
	if pattern == "dash" and support_enabled:
		remaining_sec += SPEC.dash.support_bonus


func attack_contains(point: Vector2) -> bool:
	return attack_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(point, attack_polygon)


func current_telegraph() -> String:
	if _state != "telegraph" and _state != "active":
		return ""
	return {"cone": "전방 베기", "dash": "직선 돌진", "disc": "충격환"}[_pattern]


func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	if _suspended:
		return
	super.take_damage(amount, hit_grade, attacker)
	if is_dead():
		return
	var ratio := hp / effective_max_hp()
	var next_phase := 3 if ratio <= 0.30 else (2 if ratio <= 0.65 else 1)
	if next_phase <= phase:
		return
	phase = next_phase
	_cancel_pattern()
	_groggy_remaining_sec = 0.0
	reset_groggy_gauge()
	_state = "recovery"
	remaining_sec = SPEC.transition_recovery
	_pattern_index = 0
	if not _summoned:
		_summoned = true
		summon_requested.emit(2)


func _ignores_stagger(_hit_grade: String, _attacker: Node2D) -> bool:
	return true


func suspend() -> void:
	_suspended = true
	_cancel_pattern()
	_groggy_remaining_sec = 0.0
	reset_groggy_gauge()


func _die() -> void:
	_cancel_pattern()
	_groggy_remaining_sec = 0.0
	super._die()


func _cancel_pattern() -> void:
	_state = "idle"
	remaining_sec = 0.0
	velocity = Vector2.ZERO
	current_attack_multiplier = 1.0
	_dash_travel = 0.0
	_hit_targets.clear()
	attack_polygon = PackedVector2Array()
	if is_instance_valid(_telegraph):
		_telegraph.hide()


func _make_polygon(pattern: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	if pattern == "dash":
		var half_width: float = SPEC.dash.width * 0.5
		var length: float = SPEC.dash.length
		for point in [
			Vector2(0, -half_width),
			Vector2(length, -half_width),
			Vector2(length, half_width),
			Vector2(0, half_width)
		]:
			points.append(_origin + point.rotated(_direction.angle()))
		return points
	if pattern == "cone":
		points.append(_origin)
		for i in range(33):
			var arc: float = SPEC.slash.arc_degrees
			var angle := _direction.angle() + deg_to_rad(-arc * 0.5 + arc * i / 32.0)
			points.append(_origin + Vector2.from_angle(angle) * float(SPEC.slash.radius))
	else:
		for i in range(64):
			points.append(
				_origin + Vector2.from_angle(TAU * i / 64.0) * float(SPEC.shockwave.radius)
			)
	return points


func _advance_dash(delta: float) -> void:
	var start := _dash_travel
	var distance := minf(float(SPEC.dash.length) - _dash_travel, float(SPEC.dash.speed) * delta)
	var before := global_position
	var collision := move_and_collide(_direction * distance)
	_dash_travel += before.distance_to(global_position)
	# 실제 전진한 구간만 타격한다. 벽 뒤의 예고 영역에는 피해를 주지 않는다.
	var along := (target.global_position - _origin).dot(_direction)
	if along >= start and along <= _dash_travel:
		_try_hit()
	if collision != null or _dash_travel >= float(SPEC.dash.length):
		remaining_sec = 0.0


func _try_hit() -> void:
	if _state != "active" or _suspended or is_dead() or not is_instance_valid(target):
		return
	var id := target.get_instance_id()
	if _hit_targets.has(id) or not attack_contains(target.global_position):
		return
	_hit_targets[id] = true
	attack_landed.emit(target)
