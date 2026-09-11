extends GutTest
## 실제 교전 오류와 히트스톱의 물리 이동 경계를 고정한다.
const PLAYER := preload("res://scenes/player/player.tscn")
const IMP := preload("res://scenes/monsters/imp.tscn")


func after_each() -> void:
	Engine.time_scale = 1.0


func test_repeated_hits_connect_death_effect_once_even_after_target_moves() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var enemy: MonsterBase = IMP.instantiate()
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy.hp = 10000.0
	var resolver := player.get_node("AttackResolver") as PlayerAttackResolver
	resolver.preset_weak = null
	resolver.preset_medium = null
	resolver.preset_strong = null
	var step := player.combo_data.steps[0]
	resolver._on_attack_hit(step, enemy)
	resolver._on_attack_hit(step, enemy)
	enemy.global_position += Vector2(16, 0)
	resolver._on_attack_hit(step, enemy)
	var own_connections := 0
	for connection in enemy.died.get_connections():
		if connection.callable.get_object() == resolver:
			own_connections += 1
	assert_eq(own_connections, 1, "위치가 변해도 사망 효과 구독은 한 번")


func test_hitstop_blocks_zero_delta_motion_and_restores_afterwards() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	var enemy: MonsterBase = IMP.instantiate()
	add_child_autofree(enemy)
	await wait_physics_frames(2)
	Engine.time_scale = 0.0
	assert_false(player._guard_finite_before_move())
	assert_false(enemy._guard_finite_before_move())
	await get_tree().create_timer(0.05, true, false, true).timeout
	assert_true(player.global_position.is_finite())
	assert_true(enemy.global_position.is_finite())
	Engine.time_scale = 1.0
	await wait_physics_frames(2)
	assert_true(player._guard_finite_before_move())
	assert_true(enemy._guard_finite_before_move())
