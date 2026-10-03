extends GutTest
## 대피 시간은 명시적 delta fixture, 적 피해는 API 검사다.
const SOURCE := "대피검사"

class Field:
	extends Node2D
	var map_id := "검사전장"
	var registered := 0

	func _on_monster_spawned(monster: MonsterBase) -> void:
		registered += 1
		monster.died.connect(func(): get_node("QuestController").journal.record_event(
			"KILL", "feral_dog", SOURCE, monster.get_instance_id()))

func fixture(kind: String = "evacuation", count: int = 0) -> Node2D:
	var world := Field.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	world.add_child(player)
	var holder := Node2D.new()
	holder.name = "MonsterSpawner"
	world.add_child(holder)
	var quests := QuestController.new()
	quests.name = "QuestController"
	var catalog := QuestCatalog.new()
	var quest := QuestData.new()
	quest.quest_id = "검사"
	quest.title = "전장 검사"
	quest.offer_text = "준비 상태"
	quest.objective_kinds = ["INTERACT" if kind == "evacuation" else "KILL"]
	quest.objective_targets = [SOURCE if kind == "evacuation" else "feral_dog"]
	quest.objective_sources = [SOURCE]
	quest.objective_counts = [1 if kind == "evacuation" else 3]
	quest.objective_labels = ["목표"]
	quest.objective_location_hints = ["현장"]
	catalog.definitions = {"검사": quest}
	quests.journal = QuestJournal.new(catalog)
	world.add_child(quests)
	add_child_autofree(world)
	quests.journal = QuestJournal.new(catalog)
	assert_eq(quests.journal.restore_state({"검사": {"state": "active", "counts": [count]}}), "")
	player.position = Vector2(320, 320)
	return world

func manager(world: Node2D, kind: String = "evacuation") -> Node:
	var path := "res://scripts/content/encounter_controller.gd"
	assert_true(ResourceLoader.exists(path), "대피·전장 런타임 필요")
	if not ResourceLoader.exists(path):
		return null
	var value: Node = load(path).new()
	world.add_child(value)
	value.setup(world, {SOURCE: {
		"kind": kind, "region": world.map_id, "quest_id": "검사", "index": 0,
		"target": SOURCE if kind == "evacuation" else "feral_dog",
		"position": Vector2(320, 320), "title": "대피 구역", "points": [Vector2(600, 320), Vector2(680, 320), Vector2(760, 320)],
		"scene": "wolf", "stats": "res://data/monsters/wolf_stats.tres",
		"content_id": "feral_dog", "max_active": 4}})
	return value

func test_evacuation_eight_seconds_and_no_rewards_or_repeat_start() -> void:
	var world := fixture()
	var value := manager(world)
	if value == null:
		return
	assert_false(value.active)
	assert_true(value.resume(SOURCE))
	assert_false(value.resume(SOURCE))
	assert_eq(world.registered, 0, "압박 적은 보상 배선 제외")
	assert_eq(world.get_node("MonsterSpawner").get_child_count(), 2)
	value.advance(7.9)
	assert_eq(world.get_node("QuestController").journal.export_state()["검사"].counts, [0])
	value.advance(0.1)
	assert_eq(world.get_node("QuestController").journal.export_state()["검사"].counts, [1])
	assert_false(value.active)
	assert_false(value.resume(SOURCE))

func test_damage_pause_leave_reset_and_suspend() -> void:
	var world := fixture()
	var value := manager(world)
	if value == null:
		return
	assert_true(value.resume(SOURCE))
	value.advance(3.0)
	value.pause_for_damage()
	value.advance(0.5)
	assert_almost_eq(value.elapsed, 3.0, 0.001)
	world.get_node("Player").position += Vector2(100, 0)
	value.advance(0.51)
	assert_eq(value.elapsed, 0.0)
	world.get_node("Player").position -= Vector2(100, 0)
	value.advance(2.0)
	get_tree().paused = true
	value.advance(2.0)
	get_tree().paused = false
	assert_almost_eq(value.elapsed, 2.0, 0.001)
	value.suspend()
	assert_false(value.active)
	assert_eq(value.elapsed, 0.0)
	value.advance(20.0)
	assert_eq(world.get_node("QuestController").journal.export_state()["검사"].counts, [0])

func test_wave_uses_remaining_counts_and_deleting_bodies_occupy_capacity() -> void:
	var world := fixture("wave", 1)
	var value := manager(world, "wave")
	if value == null:
		return
	assert_true(value.resume(SOURCE))
	assert_eq(world.registered, 2)
	assert_false(value.resume(SOURCE))
	value.suspend()
	assert_false(value.resume(SOURCE), "삭제 대기가 끝나기 전 재생성하지 않는다")

func test_player_death_cancels_evacuation_and_revive_can_restart_after_cleanup() -> void:
	var world := fixture()
	var value := manager(world)
	if value == null:
		return
	assert_true(value.resume(SOURCE))
	value.advance(7.0)
	var stats = world.get_node("Player/PlayerStats")
	stats.take_damage(stats.current_hp + 1.0)
	assert_false(value.active)
	value.advance(10.0)
	assert_eq(world.get_node("QuestController").journal.export_state()["검사"].counts, [0])
	assert_false(value.resume(SOURCE))
	for child in world.get_node("MonsterSpawner").get_children():
		assert_true(child.is_queued_for_deletion())
		assert_false(child.is_physics_processing())
	# 실제 부활 입력이 아닌 동일 월드 재개 조건 fixture.
	stats.current_hp = stats.stats.max_hp
	for child in world.get_node("MonsterSpawner").get_children():
		child.free()
	world.get_node("Player").is_input_locked = false
	assert_true(value.resume(SOURCE))
	assert_eq(value.elapsed, 0.0)

func test_wave_completes_once_with_normal_registration() -> void:
	var world := fixture("wave", 1)
	var value := manager(world, "wave")
	if value == null:
		return
	assert_true(value.resume(SOURCE))
	for monster in world.get_node("MonsterSpawner").get_children():
		monster.take_damage(monster.effective_max_hp() * 10.0)
		monster.take_damage(monster.effective_max_hp() * 10.0)
	assert_eq(world.get_node("QuestController").journal.export_state()["검사"].counts, [3])
	assert_false(value.active)
	assert_false(value.resume(SOURCE))
	assert_eq(world.registered, 2)

func test_global_capacity_counts_other_sources_and_queued_living_enemies() -> void:
	var world := fixture("wave")
	var value := manager(world, "wave")
	if value == null:
		return
	for index in 4:
		var blocker: MonsterBase = load("res://scenes/monsters/wolf.tscn").instantiate()
		world.get_node("MonsterSpawner").add_child(blocker)
		blocker.queue_free()
	assert_false(value.resume(SOURCE))
	assert_eq(world.registered, 0)

func test_partial_capacity_wave_allows_next_explicit_resume() -> void:
	var world := fixture("wave")
	var value := manager(world, "wave")
	if value == null:
		return
	for index in 3:
		var blocker: MonsterBase = load("res://scenes/monsters/wolf.tscn").instantiate()
		world.get_node("MonsterSpawner").add_child(blocker)
	assert_true(value.resume(SOURCE))
	assert_eq(value.targets().size(), 1)
	value.targets()[0].take_damage(100000.0)
	assert_false(value.active, "정원 탓에 나눠 생성한 무리가 끝나면 재개 가능")
	assert_eq(world.get_node("QuestController").journal.export_state()["검사"].counts, [1])
	for child in value.targets():
		child.free()
	assert_true(value.resume(SOURCE))
	assert_eq(world.registered, 2)

func test_summons_never_register_rewards_or_quest_events() -> void:
	var world := fixture()
	var value := manager(world)
	if value == null:
		return
	assert_true(value.resume(SOURCE))
	value._spawn_summons(2, value._generation)
	assert_eq(value.targets().size(), 4)
	assert_eq(world.registered, 0, "압박·소환은 정상 드롭/EXP 배선 제외")
	for monster in value.targets():
		assert_false(monster.has_meta("kill_exp_profile"))
		monster.take_damage(100000.0)
	assert_eq(world.get_node("QuestController").journal.export_state()["검사"].counts, [0])

func test_deferred_summon_is_cancelled_by_suspend_generation() -> void:
	var world := fixture()
	var value := manager(world)
	if value == null:
		return
	assert_true(value.resume(SOURCE))
	var generation: int = value._generation
	value.suspend()
	for monster in value.targets():
		monster.free()
	assert_true(value.resume(SOURCE))
	value._spawn_summons(2, generation)
	assert_eq(value.targets().size(), 2, "이전 회차 소환이 재개 뒤 섞이지 않는다")
