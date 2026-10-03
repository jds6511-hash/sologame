extends GutTest

const Content = preload("res://scripts/content/game_content.gd")
const WRAITH_PATH := "res://scenes/monsters/ruin_wraith.tscn"


class Victim:
	extends CharacterBody2D
	var health := 1000.0
	var invincible := false

	func take_damage(amount: float, _grade: String, _source: Node) -> void:
		health -= amount

	func is_dead() -> bool:
		return health <= 0.0

	func is_invincible() -> bool:
		return invincible

	func get_combat_defense() -> float:
		return 0.0


func test_scout_scene_has_real_projectile_resource() -> void:
	var variant: Dictionary = Content.MONSTER_VARIANTS.demon_scout
	var scene = load("res://scenes/monsters/" + variant.scene + ".tscn")
	var scout = scene.instantiate()
	add_child_autofree(scout)
	assert_not_null(scout.projectile_scene, "원거리 척후는 실제 투사체를 생성해야 한다")


func test_wraith_pool_fixed_telegraph_damage_and_death_cleanup() -> void:
	assert_true(ResourceLoader.exists(WRAITH_PATH), "망령 전용 장판 씬 필요")
	if not ResourceLoader.exists(WRAITH_PATH):
		return
	var world := Node2D.new()
	add_child_autofree(world)
	var wraith = load(WRAITH_PATH).instantiate()
	world.add_child(wraith)
	wraith.position = Vector2(40, 40)
	wraith.set_physics_process(false)
	var victim := Victim.new()
	victim.collision_layer = 2
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	victim.add_child(shape)
	world.add_child(victim)
	victim.position = Vector2(80, 80)
	wraith.target = victim
	assert_true(wraith.cast_hazard())
	assert_false(wraith.cast_hazard(), "동시 생성/재진입 차단")
	await get_tree().process_frame
	var pool = wraith.get_node("WraithHazard")
	pool.set_physics_process(false)
	assert_eq(pool.global_position, Vector2(80, 80))
	assert_eq(pool.get_node("CollisionShape2D").shape.radius, pool.radius_px)
	victim.position = Vector2(160, 160)
	wraith.position = Vector2(40, 40)
	assert_eq(pool.global_position, Vector2(80, 80), "예고 원점은 추적하지 않는다")
	pool._physics_process(0.5)
	assert_false(pool.monitoring)
	assert_eq(victim.health, 1000.0)
	victim.position = pool.global_position
	pool._physics_process(0.6)
	await wait_physics_frames(3)
	victim.invincible = true
	pool._apply_tick_damage(0.25)
	assert_eq(victim.health, 1000.0, "회피 무적 보존")
	victim.invincible = false
	pool._apply_tick_damage(0.25)
	assert_lt(victim.health, 1000.0, "실제 겹침 경로 피해")
	wraith.take_damage(999999.0)
	assert_true(pool.is_queued_for_deletion(), "사망 즉시 남은 장판 취소")


func test_wraith_target_death_cancels_pending_hazard() -> void:
	assert_true(ResourceLoader.exists(WRAITH_PATH))
	if not ResourceLoader.exists(WRAITH_PATH):
		return
	var wraith = load(WRAITH_PATH).instantiate()
	add_child_autofree(wraith)
	wraith.set_physics_process(false)
	var victim := Victim.new()
	add_child_autofree(victim)
	wraith.target = victim
	assert_true(wraith.cast_hazard())
	victim.health = 0.0
	await get_tree().process_frame
	assert_false(wraith.has_node("WraithHazard"))
