extends GutTest

const SOURCE := "yeoulmok_defense_wave_1"


class Field:
	extends Node2D
	var map_id := "yeoulmok_defense"
	var registered := 0

	func _on_monster_spawned(monster: MonsterBase) -> void:
		registered += 1
		monster.died.connect(
			func():
				get_node("QuestController").journal.record_event(
					"KILL",
					str(monster.get_meta("content_id")),
					str(monster.get_meta("spawn_source_id")),
					monster.get_instance_id()
				)
		)


func fixture(count: int = 0) -> Node2D:
	var world := Field.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Node = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	world.add_child(player)
	var holder := Node2D.new()
	holder.name = "MonsterSpawner"
	world.add_child(holder)
	var controller := QuestController.new()
	controller.name = "QuestController"
	var catalog := QuestCatalog.new()
	var quest := QuestData.new()
	quest.quest_id = "MQ-03-03"
	quest.title = "방어 테스트"
	quest.offer_text = "명시적 fixture"
	quest.objective_kinds = ["KILL", "KILL", "INTERACT"]
	quest.objective_targets = ["feral_dog", "feral_dog", "yeoulmok_defense_confirm"]
	quest.objective_sources = [SOURCE, "yeoulmok_defense_wave_2", "yeoulmok_defense_confirm"]
	quest.objective_counts = [3, 3, 1]
	quest.objective_labels = ["첫 무리", "다음 무리", "확인"]
	quest.objective_location_hints = ["전장", "전장", "전장"]
	catalog.definitions = {quest.quest_id: quest}
	controller.journal = QuestJournal.new(catalog)
	world.add_child(controller)
	add_child_autofree(world)
	controller.journal = QuestJournal.new(catalog)
	assert_eq(
		controller.journal.restore_state(
			{quest.quest_id: {"state": "active", "counts": [count, 0, 0]}}
		),
		""
	)
	return world


func manager(world: Node2D) -> Node:
	var path := "res://scripts/content/defense_spawner.gd"
	assert_true(ResourceLoader.exists(path), "명시 재개 방어 런타임 필요")
	if not ResourceLoader.exists(path):
		return null
	var value: Node = load(path).new()
	world.add_child(value)
	value.start(world)
	return value


func test_entry_does_not_spawn_and_repeat_resume_does_not_duplicate() -> void:
	var world := fixture()
	var spawner := manager(world)
	if spawner == null:
		return
	assert_eq(world.registered, 0)
	assert_true(spawner.resume())
	assert_eq(world.registered, 3)
	assert_false(spawner.resume())
	assert_eq(world.registered, 3)
	for monster in world.get_node("MonsterSpawner").get_children():
		assert_same(monster.target, world.get_node("Player"))
		assert_eq(monster.get_meta("spawn_source_id"), SOURCE)
		assert_eq(MonsterDropRegistry.table_for(monster).monster_level, 12)


func test_partial_fixture_resumes_only_missing_and_recreated_manager_counts_living() -> void:
	var world := fixture(1)
	var spawner := manager(world)
	if spawner == null:
		return
	assert_true(spawner.resume())
	assert_eq(world.registered, 2)
	spawner.free()
	spawner = manager(world)
	assert_false(spawner.resume())
	assert_eq(world.registered, 2)


func test_kills_require_new_resume_for_next_source() -> void:
	var world := fixture()
	var spawner := manager(world)
	if spawner == null:
		return
	spawner.resume()
	for monster in world.get_node("MonsterSpawner").get_children():
		monster.hp = 0
		monster.died.emit()
	assert_eq(world.registered, 3)
	assert_true(spawner.resume())
	assert_eq(world.registered, 6)
	assert_false(spawner.resume())


func test_queued_monsters_and_dead_player_do_not_duplicate() -> void:
	var world := fixture()
	var spawner := manager(world)
	if spawner == null:
		return
	spawner.resume()
	world.get_node("MonsterSpawner").get_child(0).queue_free()
	assert_false(spawner.resume(), "삭제 대기 중 같은 프레임 재생성 금지")
	world.get_node("Player/PlayerStats").current_hp = 0
	assert_false(spawner.resume())
	assert_eq(world.registered, 3)
	world.get_node("Player/PlayerStats").current_hp = 1
	assert_false(spawner.resume(), "부활 뒤 남아 있는 개체를 중복 생성하지 않는다")
	assert_eq(world.registered, 3)


func test_ready_completed_wrong_region_and_freed_world_cannot_spawn() -> void:
	var world := fixture()
	var spawner := manager(world)
	if spawner == null:
		return
	world.map_id = "yeoulmok"
	assert_false(spawner.resume())
	world.map_id = "yeoulmok_defense"
	var journal: QuestJournal = world.get_node("QuestController").journal
	for state in ["ready", "completed"]:
		assert_eq(journal.restore_state({"MQ-03-03": {"state": state, "counts": [3, 3, 1]}}), "")
		assert_false(spawner.resume())
	assert_eq(world.registered, 0)
	world.queue_free()
	assert_false(spawner.resume())


func test_wrong_source_event_does_not_advance_and_dead_body_does_not_reserve_slot() -> void:
	var world := fixture()
	var spawner := manager(world)
	if spawner == null:
		return
	var journal: QuestJournal = world.get_node("QuestController").journal
	journal.record_event("KILL", "feral_dog", "unrelated_source", 999)
	assert_eq(journal.export_state()["MQ-03-03"].counts, [0, 0, 0])
	spawner.resume()
	var monster: MonsterBase = world.get_node("MonsterSpawner").get_child(0)
	monster.hp = 0
	monster.died.emit()
	assert_false(spawner.resume())
	assert_eq(world.registered, 3)
	assert_eq(journal.export_state()["MQ-03-03"].counts, [1, 0, 0])


func test_rally_requires_range_and_unlocked_player_and_consumes_once() -> void:
	var world := fixture()
	var spawner := manager(world)
	var rally: Node2D = load("res://scripts/content/defense_rally.gd").new()
	world.add_child(rally)
	var player: PlayerController = world.get_node("Player")
	rally.setup(player, world.get_node("QuestController"), null, null)
	rally.configure(spawner)
	assert_eq(rally.interaction_id(), "defense_rally")
	rally.position = player.position + Vector2(50, 0)
	assert_false(rally.interact())
	rally.position = player.position
	player.is_input_locked = true
	assert_false(rally.interact())
	player.is_input_locked = false
	assert_true(rally.interact())
	assert_false(rally.interact())
	assert_eq(world.registered, 3)


func test_elite_registers_single_level_thirteen_elite() -> void:
	var world := fixture()
	var controller: QuestController = world.get_node("QuestController")
	var quest: QuestData = controller.journal.catalog.definitions["MQ-03-03"].duplicate()
	quest.quest_id = "MQ-03-04"
	quest.objective_kinds = ["KILL"]
	quest.objective_targets = ["rift_slime"]
	quest.objective_sources = ["yeoulmok_defense_elite"]
	quest.objective_counts = [1]
	quest.objective_labels = ["정예"]
	quest.objective_location_hints = ["전장"]
	controller.journal.catalog.definitions = {quest.quest_id: quest}
	assert_eq(
		controller.journal.restore_state({quest.quest_id: {"state": "active", "counts": [0]}}), ""
	)
	var spawner := manager(world)
	assert_true(spawner.resume())
	assert_eq(world.registered, 1)
	var monster: MonsterBase = world.get_node("MonsterSpawner").get_child(0)
	assert_true(monster.stats.is_elite)
	assert_eq(MonsterDropRegistry.table_for(monster).monster_level, 13)
	assert_eq(MonsterDropRegistry.table_for(monster).tier, DropTableData.MonsterTier.ELITE)
	monster.hp = 0
	monster.died.emit()
	assert_false(spawner.resume())
