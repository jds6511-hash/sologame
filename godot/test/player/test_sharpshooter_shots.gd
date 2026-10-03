extends GutTest

const SHARP_SKILL := preload("res://scripts/player/sharpshooter_skill_data.gd")


class TrialBody:
	extends Node2D
	var active_distance := -1.0
	var observed_distance := -1.0

	func begin_trial_arrow(distance_tiles: float) -> void:
		active_distance = distance_tiles

	func end_trial_arrow() -> void:
		active_distance = -1.0


var shots: ArcherShotModule
var world: Node2D
var shooter: Node2D


func before_each() -> void:
	world = Node2D.new()
	add_child_autofree(world)
	shooter = Node2D.new()
	world.add_child(shooter)
	shots = ArcherShotModule.new()
	shots.setup(shooter, 16.0)
	shots.set_focus_enabled(true)


func _spec(pierce: int = 0) -> ArrowSpec:
	var spec := ArrowSpec.new()
	spec.range_tiles = 10.0
	spec.pierce_count = pierce
	return spec


func _arrows() -> Array[ArrowProjectile]:
	var result: Array[ArrowProjectile] = []
	for child in world.get_children():
		if child is ArrowProjectile and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _body() -> Node2D:
	var body := Node2D.new()
	world.add_child(body)
	return body


func _resolve_damage(_action: Resource, _body_node: Node) -> void:
	shots.confirm_valid_damage()


func test_collision_without_confirmed_damage_is_a_miss() -> void:
	assert_true(shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT))
	_arrows()[0]._on_body_entered(_body())
	shots.confirm_valid_damage()
	assert_eq(shots.focus.value, 0.0)
	shots.arrow_hit_landed.connect(_resolve_damage)
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	_arrows()[0]._on_body_entered(_body())
	assert_eq(shots.focus.value, 10.0)


func test_real_piercing_arrow_charges_once_per_cast() -> void:
	shots.arrow_hit_landed.connect(_resolve_damage)
	shots.fire(ArcherAttackStep.new(), _spec(3), Vector2.RIGHT)
	var arrow := _arrows()[0]
	var target := _body()
	arrow._on_body_entered(target)
	arrow._on_body_entered(target)
	arrow._on_body_entered(_body())
	arrow._on_body_entered(_body())
	assert_eq(shots.focus.value, 10.0)
	assert_true(arrow.is_queued_for_deletion())
	arrow._on_body_entered(_body())
	assert_eq(shots.focus.value, 10.0)


func test_range_expiry_emits_end_once_and_breaks_consecutive_hits() -> void:
	shots.arrow_hit_landed.connect(_resolve_damage)
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	_arrows()[0]._on_body_entered(_body())
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	var miss := _arrows()[0]
	watch_signals(miss)
	miss._physics_process(2.0)
	miss._physics_process(2.0)
	assert_signal_emit_count(miss, "flight_ended", 1)
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	_arrows()[0]._on_body_entered(_body())
	assert_eq(shots.focus.value, 20.0)


func test_cancelled_burst_closes_unspawned_slots_after_live_arrow_expires() -> void:
	var rapid := SHARP_SKILL.new()
	rapid.projectile_count = 3
	rapid.projectile_interval_sec = 0.12
	rapid.focus_charge_cap = 10
	assert_true(shots.fire(rapid, _spec(), Vector2.RIGHT))
	var first := _arrows()[0]
	shots.cancel_burst()
	shots.advance(1.0)
	assert_eq(_arrows().size(), 1)
	first._physics_process(2.0)
	shots.arrow_hit_landed.connect(_resolve_damage)
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	_arrows()[0]._on_body_entered(_body())
	assert_eq(shots.focus.value, 10.0)
	assert_lte(shots.focus._casts.size(), 1)


func test_burst_catchup_spawns_three_with_single_charge_cap() -> void:
	shots.arrow_hit_landed.connect(_resolve_damage)
	var rapid := SHARP_SKILL.new()
	rapid.projectile_count = 3
	rapid.projectile_interval_sec = 0.12
	rapid.focus_charge_cap = 10
	shots.fire(rapid, _spec(), Vector2.RIGHT)
	shots.advance(0.24)
	assert_eq(_arrows().size(), 3)
	for arrow in _arrows():
		arrow._on_body_entered(_body())
	assert_eq(shots.focus.value, 10.0)


func test_field_exit_ends_flight_and_late_damage_after_reset_is_ignored() -> void:
	shots.arrow_hit_landed.connect(_resolve_damage)
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	var old := _arrows()[0]
	shots.reset_focus()
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	old._on_body_entered(_body())
	assert_eq(shots.focus.value, 0.0)
	var fresh := _arrows()[0]
	watch_signals(fresh)
	world.remove_child(fresh)
	assert_signal_emit_count(fresh, "flight_ended", 1)
	fresh.free()
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	_arrows()[0]._on_body_entered(_body())
	assert_eq(shots.focus.value, 10.0)


func test_r_rejects_insufficient_focus_and_spends_only_after_valid_spawn() -> void:
	var pierce := SHARP_SKILL.new()
	pierce.focus_cost = 50
	pierce.focus_charge_cap = 0
	assert_false(shots.fire(pierce, _spec(3), Vector2.RIGHT))
	assert_eq(_arrows().size(), 0)
	shots.focus.value = 50.0
	assert_false(shots.fire(pierce, _spec(3), Vector2.ZERO))
	assert_eq(shots.focus.value, 50.0)
	assert_true(shots.fire(pierce, _spec(3), Vector2.RIGHT))
	assert_eq(shots.focus.value, 0.0)
	shots.arrow_hit_landed.connect(_resolve_damage)
	_arrows()[0]._on_body_entered(_body())
	assert_eq(shots.focus.value, 0.0)


func test_breathing_changes_only_aim_movement_for_exactly_six_seconds() -> void:
	var stance := ArcherSkillData.new()
	stance.is_aim_stance = true
	shots.refresh_stance(stance)
	shots.is_aiming = true
	var breath := SHARP_SKILL.new()
	breath.grants_breathing = true
	breath.buff_duration_sec = 6.0
	shots.apply_buff(breath, 2.0)
	assert_eq(shots.move_speed_multiplier(), 0.8)
	assert_eq(shots.crit_chance_bonus, 0.0)
	assert_eq(shots.attack_speed_bonus, 0.0)
	assert_eq(shots.attack_range_bonus_tiles, 0.0)
	assert_eq(shots.focus.value, 0.0)
	shots.advance(6.0)
	assert_eq(shots.move_speed_multiplier(), 0.4)


func test_disabled_focus_retains_archer_damage_without_charge() -> void:
	shots.set_focus_enabled(false)
	shots.arrow_hit_landed.connect(_resolve_damage)
	watch_signals(shots)
	var action := ArcherAttackStep.new()
	var target := _body()
	assert_true(shots.fire(action, _spec(), Vector2.RIGHT))
	_arrows()[0]._on_body_entered(target)
	assert_signal_emitted_with_parameters(shots, "arrow_hit_landed", [action, target])
	assert_eq(shots.focus.value, 0.0)


func test_invalid_spawn_never_creates_cast_or_spends_focus() -> void:
	shots.focus.value = 50.0
	assert_false(shots.fire(ArcherAttackStep.new(), null, Vector2.RIGHT))
	assert_false(shots.fire(ArcherAttackStep.new(), _spec(), Vector2(INF, 0.0)))
	var bad := _spec()
	bad.speed_tiles_per_sec = 0.0
	assert_false(shots.fire(ArcherAttackStep.new(), bad, Vector2.RIGHT))
	assert_eq(shots.focus._casts.size(), 0)
	assert_eq(shots.focus.value, 50.0)


func test_disabling_job_cancels_remaining_burst_and_invalidates_live_hits() -> void:
	shots.arrow_hit_landed.connect(_resolve_damage)
	var rapid := SHARP_SKILL.new()
	rapid.projectile_count = 3
	rapid.projectile_interval_sec = 0.12
	shots.fire(rapid, _spec(), Vector2.RIGHT)
	shots.set_focus_enabled(false)
	shots.set_focus_enabled(true)
	shots.advance(0.5)
	assert_eq(_arrows().size(), 1)
	_arrows()[0]._on_body_entered(_body())
	assert_eq(shots.focus.value, 0.0)


func test_trial_distance_is_from_launch_collision_centers_not_impact() -> void:
	var target := TrialBody.new()
	world.add_child(target)
	target.add_to_group("monsters")
	var center := CollisionShape2D.new()
	center.name = "CollisionShape2D"
	target.add_child(center)
	target.position = Vector2(100.0, 0.0)
	center.position = Vector2(28.0, 0.0)
	shots.arrow_hit_landed.connect(
		func(_action: Resource, body: Node) -> void: body.observed_distance = body.active_distance
	)
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	target.position = Vector2(4.0, 0.0)
	_arrows()[0]._on_body_entered(target)
	assert_eq(target.observed_distance, 8.0)
	assert_eq(target.active_distance, -1.0)


func test_breathing_movement_lasts_after_one_time_hit_bonus_is_consumed() -> void:
	var stance := ArcherSkillData.new()
	stance.is_aim_stance = true
	shots.refresh_stance(stance)
	shots.is_aiming = true
	var breath := SHARP_SKILL.new()
	breath.grants_breathing = true
	shots.apply_buff(breath, 1.0)
	shots.arrow_hit_landed.connect(_resolve_damage)
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	_arrows()[0]._on_body_entered(_body())
	assert_eq(shots.focus.value, 30.0)
	assert_eq(shots.move_speed_multiplier(), 0.8)
	shots.fire(ArcherAttackStep.new(), _spec(), Vector2.RIGHT)
	_arrows()[0]._on_body_entered(_body())
	assert_eq(shots.focus.value, 45.0)
	shots.advance(6.0)
	assert_eq(shots.move_speed_multiplier(), 0.4)


func test_new_arrow_wall_stops_flight_once_and_does_not_damage_target_behind() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector2(40, 0)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 40)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	world.add_child(wall)
	var enemy := StaticBody2D.new()
	enemy.collision_layer = 4
	enemy.collision_mask = 0
	enemy.position = Vector2(80, 0)
	var enemy_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	enemy_shape.shape = circle
	enemy.add_child(enemy_shape)
	world.add_child(enemy)
	var hp := {"value": 100}
	shots.arrow_hit_landed.connect(
		func(_action: Resource, _body_node: Node) -> void:
			hp.value -= 10
			shots.confirm_valid_damage()
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var skill := SHARP_SKILL.new()
	assert_true(shots.fire(skill, _spec(3), Vector2.RIGHT))
	var arrow := _arrows()[0]
	watch_signals(arrow)
	arrow._physics_process(1.0)
	assert_almost_eq(arrow.global_position.x, 36.0, 0.01)
	assert_true(arrow.is_queued_for_deletion())
	arrow._physics_process(1.0)
	assert_signal_emit_count(arrow, "flight_ended", 1)
	assert_eq(shots.focus.value, 0.0)
	assert_eq(shots.focus._casts[shots.focus._last_id].outcome, 0)
	assert_eq(shots.focus._casts[shots.focus._last_id].pending, 0)
	await get_tree().physics_frame
	assert_eq(hp.value, 100)
	# 실제 적 충돌이 활성화된 대조: 벽을 치우면 같은 사격이 피해를 준다.
	wall.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(shots.fire(skill, _spec(3), Vector2.RIGHT))
	for frame in 30:
		await get_tree().physics_frame
	assert_eq(hp.value, 90)
	assert_eq(shots.focus.value, 10.0)


func test_large_step_cannot_move_past_remaining_range() -> void:
	assert_true(shots.fire(SHARP_SKILL.new(), _spec(), Vector2.RIGHT))
	var arrow := _arrows()[0]
	arrow._physics_process(2.0)
	assert_almost_eq(arrow.global_position.x, 160.0, 0.001)
	assert_true(arrow.is_queued_for_deletion())
