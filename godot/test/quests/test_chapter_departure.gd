extends GutTest

const WORLD = preload("res://scenes/world/eastern_frontier_starting_area.tscn")
var world: Node
var session: Node
var quests: QuestController


func before_each() -> void:
	world = WORLD.instantiate()
	world.set_meta("save_directory", "user://chapter_test_%d" % Time.get_ticks_usec())
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("WorldInteraction").process_mode = Node.PROCESS_MODE_DISABLED
	await wait_process_frames(8)
	session = world.get_node("SaveSession")
	quests = world.get_node("QuestController")


func after_each() -> void:
	get_tree().paused = false
	await wait_process_frames(1)
	BgmManager.reset()
	GameClock.reset()
	var directory: String = world.get_meta("save_directory")
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)


func _implemented() -> bool:
	assert_true(quests.journal.catalog.definitions.has("MQ-01-05"))
	return quests.journal.catalog.definitions.has("MQ-01-05")


func _complete_previous() -> void:
	var previous := {}
	for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04"]:
		previous[id] = {
			"state": "completed",
			"counts": quests.journal.catalog.definitions[id].objective_counts.duplicate()
		}
	assert_eq(quests.journal.restore_state(previous), "")


func test_v4_preserves_v3_exp_without_modifying_source() -> void:
	assert_eq(session.codec.character_version(), 4)
	if session.codec.character_version() != 4:
		return
	var data: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	data.character_save_version = 3
	var before := data.duplicate(true)
	var result: Dictionary = session.codec.prepare_loaded(data, session.account)
	assert_true(result.ok)
	assert_eq(result.data.character_save_version, 4)
	assert_eq(result.data.player, before.player)
	assert_eq(data, before)


func test_departure_requires_previous_quests_and_reach_before_talk() -> void:
	if not _implemented():
		return
	assert_eq(quests.journal.accept("MQ-01-05"), "quest_prerequisite")
	_complete_previous()
	assert_eq(quests.journal.accept("MQ-01-05"), "")
	quests.journal.record_event("TALK", "yeoulmok_gatewarden", "", 0)
	assert_eq(quests.journal.export_state()["MQ-01-05"].counts, [0, 0])
	assert_false(world.get_node("Gatewarden").interact())
	world.get_node("Player").position = Vector2(264, 456)
	assert_true(world.get_node("Gatewarden").interact())
	assert_eq(quests.journal.export_state()["MQ-01-05"].state, "ready")
	world.get_node("QuestDialog").close_dialog()


func test_reward_reputation_and_save_validation_are_one_time() -> void:
	if not _implemented():
		return
	_complete_previous()
	quests.journal.accept("MQ-01-05")
	quests.journal.record_event("REACH", "yeoulmok_gatewarden", "", 0)
	quests.journal.record_event("TALK", "yeoulmok_gatewarden", "", 0)
	assert_eq(quests.report("MQ-01-05", "yeoulmok_receptionist"), "wrong_npc")
	assert_eq(quests.report("MQ-01-05", "yeoulmok_gatewarden"), "")
	assert_eq(quests.report("MQ-01-05", "yeoulmok_gatewarden"), "quest_not_ready")
	assert_eq(quests.journal.reputation(), 100)
	assert_eq(world.get_node("Player/Inventory").gold, 560)
	var data: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	assert_eq(data.progress.reputation, 100)
	assert_eq(session.codec.schema.character_error(data, session.account), "")
	data.progress.reputation = 200
	assert_eq(session.codec.schema.character_error(data, session.account), "reputation")


func test_unearned_region_and_old_version_new_progress_are_rejected() -> void:
	if not _implemented():
		return
	var data: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	data.world.map_id = "novera_gate"
	assert_eq(session.codec.schema.character_error(data, session.account), "region_locked")
	data.character_save_version = 3
	assert_eq(session.codec.schema.character_error(data, session.account), "unknown_map")
	assert_eq(session.travel("novera_gate").code, "region_locked")


func test_travel_rejects_distance_combat_pause_and_account_failure() -> void:
	_complete_previous()
	var states: Dictionary = quests.journal.export_state()
	states["MQ-01-05"] = {"state": "completed", "counts": [1, 1]}
	assert_eq(quests.journal.restore_state(states), "")
	assert_eq(session.travel("novera_gate").code, "gate_distance")
	world.get_node("Player").position = Vector2(264, 456)
	world.get_node("Player/PlayerStats").is_boss_encounter = true
	assert_eq(session.travel("novera_gate").code, "boss_encounter")
	world.get_node("Player/PlayerStats").is_boss_encounter = false
	get_tree().paused = true
	assert_eq(session.travel("novera_gate").code, "session_blocked")
	get_tree().paused = false
	session.account_error = "account_missing"
	assert_eq(session.travel("novera_gate").code, "account_missing")
	assert_true(is_instance_valid(world))
	assert_eq(world.map_id, "eastern_frontier_start")
	assert_false(FileAccess.file_exists(session.store.root.path_join("character_01.json")))


func test_v4_idempotence_and_v3_cannot_claim_new_quest() -> void:
	_complete_previous()
	quests.journal.accept("MQ-01-05")
	var data: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	assert_eq(session.codec.prepare_loaded(data, session.account).data, data)
	data.character_save_version = 3
	assert_eq(session.codec.schema.character_error(data, session.account), "unknown_quest")
