extends GutTest

const Store = preload("res://scripts/save/save_file_store.gd")
const Codec = preload("res://scripts/save/character_save_codec.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
var codec: RefCounted
var account: Dictionary


func before_each() -> void:
	codec = Codec.new()
	account = codec.new_account()
	GameClock.reset()


func after_each() -> void:
	GameClock.reset()


func _player() -> Node2D:
	var player := PLAYER.instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	return player


func test_four_jobs_roundtrip_without_reward_replay() -> void:
	for job in ["adventurer", "warrior", "archer", "gladiator"]:
		var source := _player()
		var progression = source.get_node("PlayerProgression")
		var transition = source.get_node("PlayerJobTransition")
		var target_level := 1 if job == "adventurer" else (40 if job == "gladiator" else 10)
		while progression.current_level < target_level:
			progression.add_exp(progression.exp_to_next())
			if job == "gladiator" and progression.current_level == 10:
				transition.perform_transition(&"warrior")
		if job in ["warrior", "archer"]:
			transition.perform_transition(&"archer" if job == "archer" else &"warrior")
		if job == "gladiator":
			transition.perform_transition(&"gladiator")
		if target_level > 1:
			source.get_node("PlayerSkillPoints").try_upgrade_skill(&"강타", false)
		source.position = Vector2(101.25, 45.5)
		var data: Dictionary = codec.capture(source, account.account_id)
		assert_eq(codec.schema.character_error(data, account), "", job)
		var restored := _player()
		watch_signals(restored.get_node("PlayerProgression"))
		assert_eq(codec.restore_into(restored, data, account), "", job)
		assert_signal_not_emitted(restored.get_node("PlayerProgression"), "leveled_up")
		var again: Dictionary = codec.capture(restored, account.account_id, data)
		assert_eq(again, data, job + " roundtrip")


func test_inventory_including_both_rings_roundtrip() -> void:
	var source := _player()
	var inventory = source.get_node("Inventory")
	for slot in codec.registry.slots:
		for item in codec.registry.items.values():
			if item.equip_slot == codec.registry.slots[slot]:
				inventory.add_to_bag(item, 1)
				inventory.equip(item, 1 if slot == "ring_2" else 0)
				break
	inventory.add_gold(123)
	var data: Dictionary = codec.capture(source, account.account_id)
	var restored := _player()
	assert_eq(codec.restore_into(restored, data, account), "")
	assert_eq(codec.capture(restored, account.account_id, data), data)
	assert_ne(data.inventory.equipment.ring_1, "")
	assert_ne(data.inventory.equipment.ring_2, "")


func test_invalid_data_never_mutates_target() -> void:
	var target := _player()
	var baseline: Dictionary = codec.capture(target, account.account_id)
	for field in ["level", "exp", "hp", "skill_points"]:
		var bad := baseline.duplicate(true)
		bad.player[field] = -1
		assert_ne(codec.restore_into(target, bad, account), "")
		assert_eq(codec.capture(target, account.account_id, baseline), baseline)
	var foreign := account.duplicate(true)
	foreign.account_id = "f".repeat(32)
	assert_ne(codec.restore_into(target, baseline, foreign), "")


func test_unknown_ids_pending_and_nonfinite_values_rejected() -> void:
	var data: Dictionary = codec.capture(_player(), account.account_id)
	var bad := data.duplicate(true)
	bad.inventory.bag = [{"item_id": "unknown", "quantity": 1}]
	assert_ne(codec.schema.character_error(bad, account), "")
	bad = data.duplicate(true)
	bad.world.position[0] = INF
	assert_ne(codec.schema.character_error(bad, account), "")
	bad = data.duplicate(true)
	bad.pending_transfer = {"transfer_id": "unfinished"}
	assert_eq(codec.schema.character_error(bad, account), "pending_transfer")


func test_new_characters_have_distinct_ids_and_no_account_aliasing() -> void:
	var first: Dictionary = codec.capture(_player(), account.account_id)
	var second: Dictionary = codec.capture(_player(), account.account_id)
	assert_ne(first.character_id, second.character_id)
	first.progress.quests["changed"] = true
	assert_eq(second.progress.quests, {})
	assert_eq(account.clear_count, 0)


func test_schema_rejects_bad_types_slots_and_budget() -> void:
	var data: Dictionary = codec.capture(_player(), account.account_id)
	for key in ["player", "inventory", "world", "progress", "tutorial"]:
		for invalid in [null, [], 1, "text"]:
			var bad := data.duplicate(true)
			bad[key] = invalid
			assert_ne(codec.schema.character_error(bad, account), "", key)
	var bad := data.duplicate(true)
	bad.player.skill_points = 99
	assert_eq(codec.schema.character_error(bad, account), "skill_budget")
	bad = data.duplicate(true)
	bad.inventory.equipment.ring_1 = "WPN-GS-01-B"
	assert_eq(codec.schema.character_error(bad, account), "equipment_item")
	bad = data.duplicate(true)
	bad.player.job_id = "archer"
	assert_eq(codec.schema.character_error(bad, account), "job_level")


func test_restore_clock_derives_night_and_does_not_alias_metadata() -> void:
	var data: Dictionary = codec.capture(_player(), account.account_id)
	data.world.day_number = 7
	data.world.elapsed_real_sec_in_day = 1400.125
	var target := _player()
	assert_eq(codec.restore_into(target, data, account), "")
	assert_eq(GameClock.day_number, 7)
	assert_false(GameClock.is_day)
	assert_eq(GameClock._elapsed_real_sec_in_day, 1400.125)
	assert_eq(codec.restore_into(target, data, account), "target_not_fresh")


func test_store_pending_cannot_fallback_or_overwrite() -> void:
	var store = Store.new("user://m4_codec_%d" % Time.get_ticks_usec())
	var data: Dictionary = codec.capture(_player(), account.account_id)
	assert_true(store.write_save("character", 1, data).ok)
	data.pending_transfer = {"transfer_id": "unfinished"}
	assert_true(store.write_save("character", 1, data).ok)
	assert_eq(codec.bind_store(store, account), "")
	assert_eq(store.read_save("character", 1).code, "pending_transfer")
	data.pending_transfer = null
	assert_eq(store.write_save("character", 1, data).code, "pending_transfer")
	for file in DirAccess.get_files_at(store.root):
		DirAccess.remove_absolute(store.root.path_join(file))
	DirAccess.remove_absolute(store.root)


func test_impossible_skill_cost_and_missing_target_job_are_rejected() -> void:
	var source := _player()
	var progression = source.get_node("PlayerProgression")
	while progression.current_level < 10:
		progression.add_exp(progression.exp_to_next())
	source.get_node("PlayerJobTransition").perform_transition(&"warrior")
	var data: Dictionary = codec.capture(source, account.account_id)
	data.player.skill_levels = {"skill_slot1_strike": 5}
	data.player.skill_costs = {"skill_slot1_strike": 1}
	data.player.spent_points = 1
	data.player.skill_points = 10
	assert_eq(codec.schema.character_error(data, account), "skill_cost")
	data = codec.capture(source, account.account_id)
	var target := _player()
	target.get_node("PlayerJobTransition").available_jobs.clear()
	assert_eq(codec.restore_into(target, data, account), "target_job_unavailable")
	assert_eq(target.get_node("PlayerProgression").current_level, 1)


func test_repeated_json_roundtrip_and_account_isolation() -> void:
	var data: Dictionary = codec.capture(_player(), account.account_id)
	data.tutorial.tutorial_done = true
	data.play_seconds = 35.125
	for iteration in range(3):
		var decoded: Dictionary = JSON.parse_string(JSON.stringify(data))
		var target := _player()
		assert_eq(codec.restore_into(target, decoded, account), "")
		var again: Dictionary = codec.capture(target, account.account_id, decoded)
		assert_eq(JSON.parse_string(JSON.stringify(again)), JSON.parse_string(JSON.stringify(data)))
		data = again
	assert_false(account.tutorial_completed)


func test_capture_refreshes_clock_in_existing_character_metadata() -> void:
	var player := _player()
	var data: Dictionary = codec.capture(player, account.account_id)
	GameClock.advance_time(1320.5)
	var next: Dictionary = codec.capture(player, account.account_id, data)
	assert_eq(next.character_id, data.character_id)
	assert_eq(next.world.elapsed_real_sec_in_day, 1320.5)
	assert_eq(data.world.elapsed_real_sec_in_day, 0.0)


func test_delayed_transition_clamps_vitals_and_remains_saveable() -> void:
	for job in [&"warrior", &"archer"]:
		var player := _player()
		var progression = player.get_node("PlayerProgression")
		while progression.current_level < 40:
			progression.add_exp(progression.exp_to_next())
		var stats = player.get_node("PlayerStats")
		var hp_before: float = stats.current_hp
		var mp_before: float = stats.current_mp
		assert_true(player.get_node("PlayerJobTransition").perform_transition(job))
		assert_eq(stats.current_hp, minf(hp_before, stats.stats.max_hp))
		assert_eq(stats.current_mp, minf(mp_before, stats.stats.max_mp))
		assert_eq(
			codec.schema.character_error(codec.capture(player, account.account_id), account), ""
		)


func test_transition_does_not_heal_wounded_player() -> void:
	var player := _player()
	var progression = player.get_node("PlayerProgression")
	while progression.current_level < 10:
		progression.add_exp(progression.exp_to_next())
	var stats = player.get_node("PlayerStats")
	stats.current_hp = 10.0
	stats.current_mp = 5.0
	player.get_node("PlayerJobTransition").perform_transition(&"warrior")
	assert_eq(stats.current_hp, 10.0)
	assert_eq(stats.current_mp, 5.0)


func test_storage_shape_and_transfer_history_code() -> void:
	assert_eq(account.storage, {})
	account.applied_transfer_ids = ["old_transfer"]
	assert_eq(codec.schema.account_error(account), "unsupported_transfer_history")


func test_transfer_history_blocks_main_backup_and_overwrite() -> void:
	var store = Store.new("user://m4_history_%d" % Time.get_ticks_usec())
	var data: Dictionary = codec.capture(_player(), account.account_id)
	data.applied_transfer_ids = ["already_applied"]
	store.write_save("character", 1, data)
	store.write_save("character", 1, data)
	codec.bind_store(store, account)
	assert_eq(store.read_save("character", 1).code, "unsupported_transfer_history")
	data.applied_transfer_ids = []
	assert_eq(store.write_save("character", 1, data).code, "unsupported_transfer_history")
	store._write_text(store.root.path_join("character_01.json"), "broken")
	assert_eq(store.read_save("character", 1).code, "unsupported_transfer_history")
	assert_eq(store.write_save("character", 1, data).code, "unsupported_transfer_history")
	for file in DirAccess.get_files_at(store.root):
		DirAccess.remove_absolute(store.root.path_join(file))
	DirAccess.remove_absolute(store.root)
