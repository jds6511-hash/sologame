extends GutTest

const SCENES := ["rabbit", "rift_slime"]


func _spawn(kind: String) -> MonsterBase:
	var monster: MonsterBase = load("res://scenes/monsters/%s.tscn" % kind).instantiate()
	add_child_autofree(monster)
	monster.set_physics_process(false)
	return monster


func test_hit_outside_perception_approaches_attacker() -> void:
	for kind in SCENES:
		var monster := _spawn(kind)
		var attacker := Node2D.new()
		add_child_autofree(attacker)
		attacker.position = Vector2(192, 0)
		monster.take_damage(1.0, "약", attacker)
		await wait_seconds(0.4)
		monster._physics_process(0.016)
		assert_eq(monster.target, attacker, kind + " 공격자를 대상으로 설정")
		assert_gt(monster.velocity.x, 0.0, kind + " 12타일 밖 공격자에게 접근")


func test_rabbit_reaches_melee_and_keeps_retaliating_after_swing() -> void:
	var rabbit := _spawn("rabbit") as RabbitMonster
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.position = Vector2(192, 0)
	rabbit.take_damage(1.0, "약", attacker)
	await wait_seconds(0.4)
	attacker.position = Vector2(20, 0)
	rabbit._physics_process(0.016)
	assert_eq(rabbit.state, RabbitMonster.State.MELEE_SWING)
	rabbit._swing.update(2.0)
	rabbit._swing.update(2.0)
	rabbit._swing.update(2.0)
	attacker.position = Vector2(80, 0)
	rabbit._physics_process(0.016)
	assert_gt(rabbit.velocity.x, 0.0, "반격 후 도주하지 않고 추격")


func test_slime_fires_with_normal_telegraph_after_approach() -> void:
	var slime := _spawn("rift_slime") as RiftSlimeMonster
	slime.projectile_scene = null
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.position = Vector2(192, 0)
	slime.take_damage(1.0, "약", attacker)
	await wait_seconds(0.4)
	attacker.position = Vector2(64, 0)
	watch_signals(slime)
	slime._physics_process(0.016)
	assert_eq(slime.state, RiftSlimeMonster.State.AIM)
	assert_signal_not_emitted(slime, "projectile_fired")
	slime._physics_process(slime.stats.projectile_telegraph_sec + 0.01)
	assert_signal_emitted(slime, "projectile_fired")


func test_environment_damage_does_not_invent_an_attacker() -> void:
	for kind in SCENES:
		var monster := _spawn(kind)
		monster.take_damage(1.0)
		assert_null(monster.target, kind + " 공격자가 없는 피해는 추격 대상 없음")


func test_existing_species_also_target_outside_perception_attacker() -> void:
	for kind in ["wolf", "forest_spider", "shadow_forest_spider", "outlaw", "highwayman", "poacher", "imp", "imp_lord"]:
		var monster := _spawn(kind)
		var attacker := Node2D.new()
		add_child_autofree(attacker)
		attacker.position = Vector2(192, 0)
		monster.take_damage(1.0, "약", attacker)
		assert_eq(monster.target, attacker, kind + " 기존 피격 반격 유지")


func test_new_retaliators_return_when_attacker_is_freed_or_too_far() -> void:
	for kind in SCENES:
		var monster := _spawn(kind)
		var attacker := Node2D.new()
		add_child(attacker)
		attacker.position = Vector2(192, 0)
		monster.take_damage(1.0, "약", attacker)
		await wait_seconds(0.4)
		attacker.free()
		monster._physics_process(0.016)
		assert_false(monster.get("_retaliating"), kind + " 해제된 대상 추격 중단")
		var distant := Node2D.new()
		add_child_autofree(distant)
		distant.position = Vector2(300, 0)
		monster.take_damage(1.0, "약", distant)
		await wait_seconds(0.4)
		monster._physics_process(0.016)
		assert_false(monster.get("_retaliating"), kind + " 스폰 16타일 밖 추격 중단")


func test_slime_hit_during_cooldown_does_not_restart_attack() -> void:
	var slime := _spawn("rift_slime") as RiftSlimeMonster
	slime.projectile_scene = null
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.position = Vector2(64, 0)
	slime.target = attacker
	slime._start_aim()
	slime._aim.update(slime.stats.projectile_telegraph_sec)
	slime._aim.update(0.3)
	slime.take_damage(1.0, "약", attacker)
	assert_eq(slime.state, RiftSlimeMonster.State.COOLDOWN)
	assert_almost_eq(slime._aim._timer, 0.3, 0.001, "피격이 발사 대기를 초기화하지 않음")


func test_zero_damage_does_not_provoke_new_retaliators() -> void:
	for kind in SCENES:
		var monster := _spawn(kind)
		var attacker := Node2D.new()
		add_child_autofree(attacker)
		monster.take_damage(0.0, "약", attacker)
		assert_false(monster.get("_retaliating"), kind + " 실제 피해 없는 호출 제외")
