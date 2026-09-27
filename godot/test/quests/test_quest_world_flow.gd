extends GutTest

const WORLD = preload("res://scenes/world/eastern_frontier_starting_area.tscn")
var world: Node


func before_each() -> void:
	world = WORLD.instantiate()
	world.set_meta("save_directory", "user://m5_world_%d" % Time.get_ticks_usec())
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED


func after_each() -> void:
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()
	var directory: String = world.get_meta("save_directory")
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)


func test_actual_menu_pairs_and_external_pause() -> void:
	var save = world.get_node("SaveMenu")
	var integrated = world.get_node("IntegratedMenu")
	var dialog = world.get_node("QuestDialog")
	var opens := [
		save.open_menu, integrated.open_menu, dialog.open_dialog.bind("yeoulmok_receptionist")
	]
	var closes := [save.close_menu, integrated.close_menu, dialog.close_dialog]
	for first in 3:
		for second in 3:
			if first == second:
				continue
			opens[first].call()
			opens[second].call()
			assert_eq(
				[save.panel.visible, integrated.is_open(), dialog.panel.visible],
				[first == 0, first == 1, first == 2]
			)
			closes[second].call()
			assert_true(get_tree().paused)
			closes[first].call()
			assert_false(get_tree().paused)
	get_tree().paused = true
	for open in opens:
		open.call()
	assert_eq(
		[save.panel.visible, integrated.is_open(), dialog.panel.visible], [false, false, false]
	)


func test_job_selection_cannot_steal_dialogue_pause() -> void:
	var transition = world.get_node("Player/PlayerJobTransition")
	transition.transition_available = true
	world.get_node("QuestDialog").open_dialog("yeoulmok_receptionist")
	var selection = world.get_node("Hud/JobSelectionScreen")
	selection.open()
	assert_false(selection.visible)
	selection.close()
	assert_true(get_tree().paused)


func test_active_skill_and_dash_do_not_start_dialogue() -> void:
	var player = world.get_node("Player")
	var npc = world.get_node("QuestReceptionist")
	player.skill_state = PlayerController.AttackState.ACTIVE
	assert_false(npc.interact())
	world.get_node("QuestDialog").close_dialog()
	player.skill_state = PlayerController.AttackState.NONE
	player.is_dashing = true
	assert_false(npc.interact())
	world.get_node("QuestDialog").close_dialog()


func test_distance_wall_and_dead_player_block_npc() -> void:
	var npc = world.get_node("QuestReceptionist")
	var player = world.get_node("Player")
	player.position = Vector2(700, 700)
	assert_false(npc.interact())
	assert_eq(world.get_node("QuestController").journal.export_state()["MQ-01-01"].counts, [0, 0])
	player.position = Vector2(152, 504)
	player.get_node("PlayerStats").current_hp = 0
	assert_false(npc.interact())
	player.get_node("PlayerStats").current_hp = 100
	var wall := StaticBody2D.new()
	wall.process_mode = Node.PROCESS_MODE_ALWAYS
	wall.position = Vector2(152, 488)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 4)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	await wait_physics_frames(2)
	assert_false(npc.interact())


func test_reward_signal_cannot_save_or_change_character() -> void:
	var quests = world.get_node("QuestController")
	var session = world.get_node("SaveSession")
	quests.journal.record_event("REACH", "yeoulmok_receptionist", "", 0)
	quests.journal.record_event("TALK", "yeoulmok_receptionist", "", 0)
	var results := []
	world.get_node("Player/Inventory").gold_changed.connect(
		func(_gold):
			results.append(session.save_slot(1).code)
			results.append(session.new_character().code)
	)
	assert_eq(quests.report("MQ-01-01", "yeoulmok_receptionist"), "")
	assert_eq(results, ["reward_busy", "session_blocked"])
	assert_false(DirAccess.dir_exists_absolute(session.store.root))


func test_rejected_codec_target_does_not_change_journal() -> void:
	var session = world.get_node("SaveSession")
	var player = world.get_node("Player")
	var state: Dictionary = world.get_node("QuestController").journal.export_state()
	var snapshot: Dictionary = session.codec.capture(player, session.account.account_id)
	snapshot.progress.quests = {}
	player.get_node("Inventory").gold = 1
	assert_eq(session.codec.restore_into(player, snapshot, session.account), "target_not_fresh")
	assert_eq(world.get_node("QuestController").journal.export_state(), state)


func test_world_boot_dialog_and_codec_share_character_journal() -> void:
	assert_true(world.has_node("QuestController"))
	if not world.has_node("QuestController"):
		return
	var controller = world.get_node("QuestController")
	var npc = world.get_node("QuestReceptionist")
	var dialog = world.get_node("QuestDialog")
	var journal = controller.journal
	assert_eq(journal.export_state()["MQ-01-01"].counts, [0, 0])
	npc.update_target()
	assert_eq(journal.export_state()["MQ-01-01"].counts, [1, 0])
	assert_true(npc.interact())
	assert_eq(journal.export_state()["MQ-01-01"].state, "ready")
	world.get_node("SaveMenu").open_menu()
	world.get_node("IntegratedMenu").open_menu()
	assert_false(world.get_node("SaveMenu").panel.visible)
	assert_false(world.get_node("IntegratedMenu").is_open())
	dialog.close_dialog()
	assert_eq(world.get_node("Player/Inventory").gold, 0)
	assert_true(npc.interact())
	dialog.choose("report_first")
	assert_eq(world.get_node("Player/Inventory").gold, 20)
	assert_true(npc.interact())
	dialog.choose("accept_second")
	assert_eq(journal.export_state()["MQ-01-02"].counts, [0])
	var spawner = world.get_node("MonsterSpawner")
	var initial: int = spawner.get_child_count()
	spawner.start()
	assert_eq(spawner.get_child_count(), initial)
	var rabbits := []
	for monster in spawner.get_children():
		if monster is RabbitMonster:
			rabbits.append(monster)
	var registrations := {"drop": 0, "exp": 0, "quest": 0}
	for connection in rabbits[0].died.get_connections():
		var receiver: Object = connection.callable.get_object()
		if receiver is DropSystem:
			registrations.drop += 1
		elif receiver is PlayerProgression:
			registrations.exp += 1
		elif receiver is QuestJournal:
			registrations.quest += 1
	assert_eq(registrations, {"drop": 1, "exp": 1, "quest": 1})
	rabbits[0].take_damage(99999.0, "강")
	assert_eq(journal.export_state()["MQ-01-02"].counts, [1])
	rabbits[1].take_damage(99999.0, "강")
	assert_eq(journal.export_state()["MQ-01-02"].state, "ready")
	var session = world.get_node("SaveSession")
	var snapshot: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	assert_eq(snapshot.progress.quests, journal.export_state())


func test_saved_progress_restores_before_spawning_and_does_not_share_state() -> void:
	var session = world.get_node("SaveSession")
	var quests = world.get_node("QuestController")
	var player = world.get_node("Player")
	quests.journal.record_event("REACH", "yeoulmok_receptionist", "", 0)
	quests.journal.record_event("TALK", "yeoulmok_receptionist", "", 0)
	quests.report("MQ-01-01", "yeoulmok_receptionist")
	quests.journal.accept("MQ-01-02")
	quests.journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 10)
	player.get_node("PlayerStats")._time_since_combat_action_sec = 10
	assert_true(session.save_slot(1).ok)
	var loaded = WORLD.instantiate()
	loaded.set_meta("save_directory", session.store.root)
	loaded.set_meta(
		"save_boot", {"account": session.account, "character": session.character, "slot": 1}
	)
	add_child_autofree(loaded)
	loaded.process_mode = Node.PROCESS_MODE_DISABLED
	var other = loaded.get_node("QuestController")
	assert_ne(other.journal, quests.journal)
	assert_eq(other.journal.export_state()["MQ-01-02"].counts, [1])
	for monster in loaded.get_node("MonsterSpawner").get_children():
		if monster is RabbitMonster:
			monster.take_damage(99999.0, "강")
			break
	assert_eq(other.journal.export_state()["MQ-01-02"].state, "ready")
	assert_eq(quests.journal.export_state()["MQ-01-02"].counts, [1])


func test_respawned_rabbit_keeps_source_and_counts_once() -> void:
	var quests = world.get_node("QuestController")
	quests.journal.record_event("REACH", "yeoulmok_receptionist", "", 0)
	quests.journal.record_event("TALK", "yeoulmok_receptionist", "", 0)
	quests.report("MQ-01-01", "yeoulmok_receptionist")
	quests.journal.accept("MQ-01-02")
	var spawner = world.get_node("MonsterSpawner")
	var rabbit = spawner.get_child(0)
	var source_position: Vector2 = rabbit.global_position
	rabbit.take_damage(99999.0, "강")
	assert_eq(quests.journal.export_state()["MQ-01-02"].counts, [1])
	spawner.advance_respawn_tick(31.0)
	var replacement: MonsterBase
	for monster in spawner.get_children():
		if (
			monster is RabbitMonster
			and not monster.is_dead()
			and monster.global_position == source_position
		):
			replacement = monster
	assert_not_null(replacement)
	if replacement != null:
		assert_eq(replacement.get_meta("spawn_source_id"), "yeoulmok_rabbit_habitat")
		replacement.take_damage(99999.0, "강")
		assert_eq(quests.journal.export_state()["MQ-01-02"].state, "ready")
