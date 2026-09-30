extends GutTest


func test_close_cursor_direction_uses_body_center_without_angle_steps() -> void:
	var shooter := Node2D.new()
	add_child_autofree(shooter)
	var body := Node2D.new()
	body.name = "CollisionShape2D"
	body.position = Vector2(0, -9)
	shooter.add_child(body)
	var facing := Node2D.new()
	facing.name = "Facing"
	facing.rotation = 0.5
	shooter.add_child(facing)
	var module := ArcherShotModule.new()
	module.setup(shooter, 16)
	assert_eq(module.shot_origin(), Vector2(0, -9))
	assert_eq(module.aim_direction(Vector2(16, -9)), Vector2.RIGHT)
	var above := module.aim_direction(Vector2(16, -9.01))
	var below := module.aim_direction(Vector2(16, -8.99))
	assert_lt(absf(above.angle_to(below)), 0.01)
	assert_almost_eq(module.aim_direction(body.global_position).angle(), 0.5, 0.001)
