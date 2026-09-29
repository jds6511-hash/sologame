extends GutTest

const SLIME = preload("res://scenes/monsters/rift_slime.tscn")


func test_pool_creation_is_deferred_and_keeps_death_position() -> void:
	var world := Node2D.new()
	world.position = Vector2(50, 60)
	add_child_autofree(world)
	var slime = SLIME.instantiate()
	world.add_child(slime)
	slime.global_position = Vector2(200, 250)
	slime.take_damage(99999.0, "약")
	assert_eq(world.get_child_count(), 1, "충돌 콜백 안에서는 생성하지 않는다")
	await get_tree().process_frame
	var pools := world.find_children("*", "RiftSlimeAcidPool", false, false)
	assert_eq(pools.size(), 1)
	assert_eq(pools[0].global_position, Vector2(200, 250))


func test_deleted_world_does_not_emit_pool_into_next_world() -> void:
	var world := Node2D.new()
	add_child(world)
	var slime = SLIME.instantiate()
	world.add_child(slime)
	slime.take_damage(99999.0, "약")
	world.free()
	var next_world := Node2D.new()
	add_child_autofree(next_world)
	await get_tree().process_frame
	assert_eq(next_world.get_child_count(), 0)


func test_actual_body_entered_death_spawns_one_pool_without_engine_error() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var slime = SLIME.instantiate()
	world.add_child(slime)
	slime.position = Vector2(200, 200)
	var area := Area2D.new()
	var area_shape := CollisionShape2D.new()
	area_shape.shape = CircleShape2D.new()
	area.add_child(area_shape)
	var body := StaticBody2D.new()
	var body_shape := CollisionShape2D.new()
	body_shape.shape = CircleShape2D.new()
	body.add_child(body_shape)
	area.body_entered.connect(func(_body): slime.take_damage(99999.0, "약"))
	world.add_child(area)
	world.add_child(body)
	await wait_physics_frames(5)
	assert_true(slime.is_dead())
	assert_eq(world.find_children("*", "RiftSlimeAcidPool", false, false).size(), 1)
