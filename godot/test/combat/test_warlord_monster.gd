extends GutTest

const SCRIPT_PATH := "res://scripts/ai/warlord_monster.gd"
var boss: Variant
var player: Node2D
var counts: Dictionary


func _watch() -> void:
	counts = {"attack_landed": 0, "summon_requested": 0, "died": 0}
	boss.attack_landed.connect(func(_who): counts["attack_landed"] += 1)
	boss.summon_requested.connect(func(_count): counts["summon_requested"] += 1)
	boss.died.connect(func(): counts["died"] += 1)


func before_each() -> void:
	if not ResourceLoader.exists(SCRIPT_PATH):
		return
	boss = load(SCRIPT_PATH).new()
	boss.stats = MonsterStatsData.new()
	boss.stats.max_hp = 24000.0
	boss.stats.attack_power = 500.0
	boss.stats.is_boss = true
	boss.stats.groggy_gauge_hp_ratio = 0.25
	boss.stats.groggy_duration_sec = 2.0
	add_child_autofree(boss)
	boss.set_physics_process(false)
	boss.set_process(false)
	player = Node2D.new()
	add_child_autofree(player)
	player.position = Vector2(40, 0)
	boss.target = player


func test_boss_runtime_exists() -> void:
	assert_true(ResourceLoader.exists(SCRIPT_PATH), "군후 전용 패턴 런타임 필요")


func test_cone_direction_locked_and_one_hit_per_activation() -> void:
	if boss == null:
		return
	_watch()
	boss.begin_pattern("cone")
	assert_true(boss.attack_contains(Vector2(40, 0)))
	assert_false(boss.attack_contains(Vector2(-40, 0)))
	player.position = Vector2(-40, 0)
	boss.advance(0.9)
	assert_eq(counts["attack_landed"], 0)
	player.position = Vector2(40, 0)
	boss.advance(0.01)
	boss.advance(0.01)
	assert_eq(counts["attack_landed"], 1)


func test_phase_skip_summons_once_and_lethal_damage_never_summons() -> void:
	if boss == null:
		return
	_watch()
	boss.take_damage(18000)
	assert_eq(boss.phase, 3)
	assert_eq(counts["summon_requested"], 1)
	boss.take_damage(10)
	assert_eq(counts["summon_requested"], 1)
	boss.take_damage(99999)
	assert_eq(counts["died"], 1)
	assert_eq(boss.current_telegraph(), "")


func test_death_has_priority_over_phase_and_duplicate_damage() -> void:
	if boss == null:
		return
	_watch()
	boss.take_damage(99999)
	boss.take_damage(99999)
	assert_eq(counts["summon_requested"], 0)
	assert_eq(counts["died"], 1)


func test_groggy_and_suspend_cancel_telegraph_and_damage() -> void:
	if boss == null:
		return
	_watch()
	boss.begin_pattern("cone")
	boss.take_damage(6000)
	assert_true(boss.is_groggy())
	assert_eq(boss.current_telegraph(), "")
	boss.advance(2.0)
	assert_eq(counts["attack_landed"], 0)
	boss._process(2.0)
	assert_false(boss.is_groggy())
	assert_eq(boss.groggy_gauge, 0.0)
	boss.begin_pattern("disc")
	boss.suspend()
	boss.advance(10.0)
	assert_eq(counts["attack_landed"], 0)
	assert_eq(boss.current_telegraph(), "")


func test_disc_center_and_dash_width_support_are_fixed() -> void:
	if boss == null:
		return
	boss.begin_pattern("disc")
	assert_true(boss.attack_contains(Vector2(0, 95)))
	assert_false(boss.attack_contains(Vector2(0, 97)))
	boss.position = Vector2(100, 100)
	assert_true(boss.attack_contains(Vector2(0, 95)))
	boss.position = Vector2.ZERO
	boss.support_enabled = true
	boss.begin_pattern("dash")
	assert_almost_eq(boss.remaining_sec, 1.15, 0.0001)
	assert_true(boss.attack_contains(Vector2(150, 11)))
	assert_false(boss.attack_contains(Vector2(150, 13)))
	assert_false(boss.attack_contains(Vector2(161, 0)))
	var polygon: PackedVector2Array = boss.get_node("PatternTelegraph").polygon
	assert_eq(polygon, boss.attack_polygon)


func _real_player() -> PlayerController:
	var world := Node2D.new()
	add_child_autofree(world)
	var actor: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	return actor


func _boss_body() -> void:
	boss.collision_layer = 4
	boss.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 9.0
	shape.height = 24.0
	collision.shape = shape
	collision.position = Vector2(0, -10)
	boss.add_child(collision)


func test_real_melee_overlap_reaches_boss_damage_resolver() -> void:
	if boss == null:
		return
	_boss_body()
	var actor := _real_player()
	actor.position = Vector2(-20, 0)
	actor.get_node("Facing").rotation = 0.0
	await wait_physics_frames(2)
	actor._advance_attack_from_input(true)
	actor._process_attack_state(0.5)
	await wait_physics_frames(5)
	assert_lt(boss.hp, 24000.0, "실제 근접 Area2D → attack_hit → resolver")
	actor._disable_attack_hitbox()
	Engine.time_scale = 1.0


func test_real_arrow_flight_reaches_boss_damage_resolver() -> void:
	if boss == null:
		return
	_boss_body()
	var actor := _real_player()
	boss.global_position = actor.get_global_mouse_position()
	actor.global_position = boss.global_position - Vector2(48, 0)
	actor.combo_data = load("res://data/player/archer_basic_combo.tres")
	await wait_physics_frames(2)
	actor._advance_attack_from_input(true)
	actor._process_attack_state(0.5)
	await wait_seconds(0.4)
	assert_lt(boss.hp, 24000.0, "실제 화살 비행 → attack_hit → resolver")
	Engine.time_scale = 1.0


func test_boss_pattern_hits_actual_player_and_dodge_prevents_damage() -> void:
	if boss == null:
		return
	var actor := _real_player()
	actor.position = Vector2(40, 0)
	boss.target = actor
	boss.stats.attack_power = 25.0
	var resolver := MonsterAttackResolver.new()
	resolver.monster_path = NodePath("..")
	resolver.formula_data = load("res://data/combat/damage_formula.tres")
	boss.add_child(resolver)
	var vitals: PlayerStatsComponent = actor.get_node("PlayerStats")
	var before := vitals.current_hp
	actor._start_dash()
	boss.begin_pattern("cone")
	boss.advance(0.9)
	assert_eq(vitals.current_hp, before, "회피 무적은 실제 리졸버에서 피해 거부")
	actor.is_dashing = false
	actor.is_dash_invincible = false
	boss.begin_pattern("disc")
	boss.advance(1.2)
	assert_lt(vitals.current_hp, before, "보스 실제 판정 → PlayerStats HP")


func test_dash_waits_for_supported_telegraph_and_hits_once_when_crossing() -> void:
	if boss == null:
		return
	_watch()
	boss.support_enabled = true
	boss.begin_pattern("dash")
	boss.advance(1.0)
	assert_eq(boss.position, Vector2.ZERO)
	assert_eq(counts.attack_landed, 0)
	boss.advance(0.15)
	boss.advance(0.3)
	assert_eq(counts.attack_landed, 1)
	player.position = Vector2(70, 0)
	boss.advance(0.3)
	assert_eq(counts.attack_landed, 1)
	assert_almost_eq(boss.position.x, 96.0, 0.01)


func test_dash_wall_stops_before_target_behind_wall() -> void:
	if boss == null:
		return
	_boss_body()
	_watch()
	var wall := StaticBody2D.new()
	wall.position = Vector2(80, -10)
	wall.collision_layer = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 100)
	collision.shape = shape
	wall.add_child(collision)
	add_child_autofree(wall)
	player.position = Vector2(130, 0)
	await wait_physics_frames(2)
	boss.begin_pattern("dash")
	boss.advance(0.9)
	boss.advance(1.0)
	assert_lt(boss.position.x, 75.0)
	assert_eq(counts.attack_landed, 0)
	assert_eq(boss.current_telegraph(), "")


func test_phase_thresholds_cancel_active_attack_without_healing() -> void:
	if boss == null:
		return
	_watch()
	boss.begin_pattern("disc")
	boss.take_damage(8400)
	assert_eq(boss.phase, 2)
	assert_eq(boss.hp, 15600.0)
	assert_eq(boss.current_telegraph(), "")
	assert_false(boss.is_groggy(), "전환 회복은 피해 그로기를 대신한다")
	boss.advance(0.79)
	assert_eq(boss.current_telegraph(), "")
	boss.take_damage(8400)
	assert_eq(boss.phase, 3)
	assert_eq(counts.summon_requested, 1)
	assert_eq(boss.hp, 7200.0)
