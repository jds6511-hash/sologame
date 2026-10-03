extends GutTest
const WOLF = preload("res://scenes/monsters/wolf.tscn")


func test_anchored_keeps_hit_stagger_and_damage_without_knockback() -> void:
	var source: MonsterBase = WOLF.instantiate()
	var base: MonsterStatsData = source.stats.duplicate()
	source.free()
	assert_true("anchored" in base, "고정형 설정이 필요하다")
	if not "anchored" in base:
		return
	for grade in ["약", "강"]:
		var monster: MonsterBase = WOLF.instantiate()
		monster.stats = base.duplicate()
		monster.stats.anchored = true
		add_child_autofree(monster)
		monster.process_mode = Node.PROCESS_MODE_DISABLED
		var attacker := Node2D.new()
		attacker.position = Vector2(80, 0)
		add_child_autofree(attacker)
		var before := monster.hp
		monster.take_damage(1, grade, attacker)
		assert_lt(monster.hp, before)
		assert_true(monster.is_staggered())
		assert_eq(monster.stagger_velocity(), Vector2.ZERO)


func test_default_mobile_monster_still_has_knockback() -> void:
	var monster: MonsterBase = WOLF.instantiate()
	add_child_autofree(monster)
	monster.process_mode = Node.PROCESS_MODE_DISABLED
	var attacker := Node2D.new()
	attacker.position = Vector2(80, 0)
	add_child_autofree(attacker)
	monster.take_damage(1, "약", attacker)
	assert_true(monster.is_staggered())
	assert_gt(monster.stagger_velocity().length(), 0.0)
