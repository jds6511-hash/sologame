extends GutTest

const Session = preload("res://scripts/save/save_session.gd")
const WORLD = preload("res://scenes/world/eastern_frontier_starting_area.tscn")
var world: Node
var session: Node
var directory: String


func before_each() -> void:
	directory = "user://m4_session_%d" % Time.get_ticks_usec()
	world = WORLD.instantiate()
	world.set_meta("save_directory", directory)
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	session = world.get_node("SaveSession")
	world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0


func after_each() -> void:
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)


func test_save_requires_safe_state_and_persists_tutorial_and_active_slot() -> void:
	var player = world.get_node("Player")
	player.is_input_locked = true
	assert_false(session.save_slot(1).ok)
	player.is_input_locked = false
	world.get_node("TutorialController").tutorial_done = true
	assert_true(session.save_slot(1).ok)
	assert_eq(session.active_slot, 1)
	assert_true(session.store.read_save("character", 1).data.tutorial.tutorial_done)
	assert_true(session.store.read_save("account").data.tutorial_completed)


func test_autosave_waits_and_never_creates_an_unselected_slot() -> void:
	session.advance(181.0)
	assert_eq(session.store.read_save("character", 1).code, "missing")
	assert_true(session.save_slot(1).ok)
	var player = world.get_node("Player")
	player.is_dashing = true
	world.get_node("Player/Inventory").gold = 57
	session.advance(181.0)
	assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 0)
	player.is_dashing = false
	session.advance(1.0)
	assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 57)


func test_death_cooldown_and_nearby_enemy_block_saving() -> void:
	var player = world.get_node("Player")
	player.get_node("PlayerStats").current_hp = 0.0
	assert_false(session.save_slot(1).ok)
	player.get_node("PlayerStats").current_hp = 100.0
	player._skills._secondary_cooldown = 2.0
	assert_false(session.save_slot(1).ok)
	player._skills._secondary_cooldown = 0.0
	var enemy := Node2D.new()
	world.get_node("MonsterSpawner").add_child(enemy)
	enemy.global_position = player.global_position
	assert_false(session.save_slot(1).ok)


func test_boss_encounter_blocks_manual_and_defers_due_autosave_until_safe() -> void:
	assert_true(session.save_slot(1).ok)
	var stats = world.get_node("Player/PlayerStats")
	world.get_node("Player/Inventory").gold = 79
	stats.start_boss_encounter()
	assert_eq(session.save_slot(2).code, "boss_encounter")
	assert_eq(session.store.read_save("character", 2).code, "missing")
	session.advance(181.0)
	assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 0)
	assert_gte(session._auto_elapsed, session.AUTO_SECONDS)
	# 거리/공격 동작과 무관하게 조우 종료 API가 호출될 때까지 잠금을 유지한다.
	session.advance(180.0)
	assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 0)
	stats.end_boss_encounter()
	stats._time_since_combat_action_sec = 0.0
	session.advance(1.0)
	assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 0)
	stats._time_since_combat_action_sec = 5.0
	session.advance(0.1)
	assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 79)
	assert_eq(session._auto_elapsed, 0.0)
	assert_true(session.save_slot(2).ok)


func test_menu_pause_ownership_and_confirmation() -> void:
	var menu = world.get_node("SaveMenu")
	menu.open_menu()
	assert_true(get_tree().paused)
	assert_true(menu.panel.visible)
	assert_eq(world.get_node("IntegratedMenu").process_mode, Node.PROCESS_MODE_DISABLED)
	menu.request_action("save")
	assert_true(menu.confirmation.visible)
	assert_eq(session.active_slot, 0)
	menu.close_menu()
	assert_false(get_tree().paused)
	assert_false(menu.confirmation.visible)


func test_failed_load_preserves_current_world_and_account() -> void:
	world.get_node("Player/Inventory").gold = 99
	var id: String = session.account.account_id
	assert_false(session.load_slot(1).ok)
	assert_eq(world.get_node("Player/Inventory").gold, 99)
	assert_eq(session.account.account_id, id)


func test_load_replaces_world_and_new_character_keeps_account() -> void:
	world.get_node("Player/Inventory").gold = 71
	world.get_node("TutorialController").tutorial_done = true
	GameClock.prepare_scene_time(4, 1400.125)
	assert_true(session.save_slot(2).ok)
	var character_id: String = session.character.character_id
	var account_id: String = session.account.account_id
	var parent := world.get_parent()
	assert_true(session.load_slot(2).ok)
	var loaded: Node
	for child in parent.get_children():
		if child != world and child is EasternFrontierStartingArea:
			loaded = child
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.get_node("Player/Inventory").gold, 71)
	assert_eq(loaded.get_node("SaveSession").character.character_id, character_id)
	assert_true(loaded.get_node("TutorialController").tutorial_done)
	assert_false(GameClock.is_day)
	assert_true(loaded.get_node("SaveSession").new_character().ok)
	for child in parent.get_children():
		if child != world and child != loaded and child is EasternFrontierStartingArea:
			assert_eq(child.get_node("SaveSession").account.account_id, account_id)
			assert_eq(child.get_node("Player/Inventory").gold, 0)
			assert_false(child.get_node("TutorialController").tutorial_done)
			assert_eq(child.get_node("SaveSession").active_slot, 0)
			child.queue_free()
	await get_tree().process_frame


func test_autosave_does_not_replace_corrupt_or_foreign_slot() -> void:
	assert_true(session.save_slot(1).ok)
	assert_true(session.save_slot(1).ok)
	var path: String = directory.path_join("character_01.json")
	session.store._write_text(path, "broken")
	session.advance(181.0)
	assert_eq(FileAccess.get_file_as_string(path), "broken")
	var foreign: Dictionary = session.character.duplicate(true)
	foreign.character_id = "f".repeat(32)
	assert_true(session.store.write_save("character", 1, foreign).ok)
	session.advance(181.0)
	assert_eq(session.store.read_save("character", 1).data.character_id, foreign.character_id)


func test_failed_character_write_does_not_change_active_slot_or_progress() -> void:
	assert_true(session.save_slot(1).ok)
	var id: String = session.character.character_id
	# 임시 파일 자리에 디렉터리를 두어 캐릭터 파일 생성만 실패시킨다.
	var obstacle := directory.path_join("character_02.json.tmp")
	DirAccess.make_dir_absolute(obstacle)
	world.get_node("Player/Inventory").gold = 43
	assert_false(session.save_slot(2).ok)
	assert_eq(session.active_slot, 1)
	assert_eq(session.character.character_id, id)
	assert_eq(world.get_node("Player/Inventory").gold, 43)
	assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 0)
	DirAccess.remove_absolute(obstacle)


func test_missing_account_with_existing_character_is_not_recreated() -> void:
	assert_true(session.save_slot(1).ok)
	DirAccess.remove_absolute(directory.path_join("account.json"))
	assert_false(session.save_slot(2).ok)
	assert_false(session.new_character().ok)
	assert_false(FileAccess.file_exists(directory.path_join("account.json")))
	assert_eq(session.active_slot, 1)


func test_failed_boot_restores_clock_pause_and_existing_world() -> void:
	assert_true(session.save_slot(1).ok)
	var data: Dictionary = session.character.duplicate(true)
	data.player.level = -1
	GameClock.prepare_scene_time(5, 1500.0)
	var menu = world.get_node("SaveMenu")
	menu.open_menu()
	assert_false(session._replace_world(session.account, data, 1, "test").ok)
	assert_true(get_tree().paused)
	assert_true(menu.panel.visible)
	assert_false(world.is_queued_for_deletion())
	assert_eq(GameClock.day_number, 5)
	assert_eq(GameClock._elapsed_real_sec_in_day, 1500.0)
	menu.close_menu()


func test_account_failure_keeps_main_and_backup_causes() -> void:
	assert_true(session.save_slot(1).ok)
	session.store._write_text(directory.path_join("account.json"), "broken")
	var result: Dictionary = session.load_slot(1)
	assert_false(result.ok)
	assert_eq(result.file_kind, "account")
	assert_eq(result.main_code, "corrupt")
	assert_eq(result.backup_code, "missing")
