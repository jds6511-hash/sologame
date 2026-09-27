extends SceneTree
## Automated input/render smoke test; not director play approval.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", "user://m5_render_probe")
	root.add_child(world)
	current_scene = world
	await create_timer(0.3).timeout
	var dialog = world.get_node("QuestDialog")
	await _key(KEY_F)
	await process_frame
	_check(dialog.panel.visible, "F opens dialogue")
	await _capture("m5-01-pass-dialog.png")
	await _key(KEY_F6)
	_check(not world.get_node("SaveMenu").panel.visible, "F6 excluded during dialogue")
	await _key(KEY_ESCAPE)
	_check(not paused, "Escape releases dialogue pause")
	_check(world.get_node("Player/Inventory").gold == 0, "Escape grants no reward")
	await _key(KEY_F)
	dialog.choose("report", "MQ-01-01")
	_check(world.get_node("Player/Inventory").gold == 20, "Explicit pass reward")
	await _key(KEY_F)
	await _capture("m5-02-rabbit-offer.png")
	dialog.choose("accept", "MQ-01-02")
	await _capture("m5-03-quest-tracker.png")
	if "third" in OS.get_cmdline_user_args():
		# Synthetic goal events validate rendering, not real combat or director play.
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var journal = world.get_node("QuestController").journal
		journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 100)
		journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 101)
		dialog.open_dialog("yeoulmok_receptionist")
		dialog.choose("report", "MQ-01-02")
		dialog.open_dialog("yeoulmok_receptionist")
		await _capture("m5-04-dog-offer.png")
		dialog._box.get_child(1).pressed.emit()
		_check(journal.export_state().has("MQ-01-03"), "third accept button wired")
		await _capture("m5-05-dog-tracker.png")
		journal.record_event("KILL", "feral_dog", "yeoulmok_dog_habitat", 102)
		journal.record_event("KILL", "feral_dog", "yeoulmok_dog_habitat", 103)
		dialog.open_dialog("yeoulmok_receptionist")
		await _capture("m5-06-dog-report.png")
		dialog._box.get_child(1).pressed.emit()
		_check(world.get_node("Player/Inventory").gold == 270, "third report button reward")
		_check(not paused, "third reward releases pause")
	print("M5_QUEST_RENDER_%s" % ("FAIL" if _failed else "PASS"))
	world.free()
	root.get_node("BgmManager").reset()
	root.get_node("GameClock").reset()
	await process_frame
	quit(1 if _failed else 0)


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../docs/qa/screenshots/")
	if "third" in OS.get_cmdline_user_args():
		directory = directory.path_join("m5-third")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory.path_join(filename)) == OK, filename)


func _check(condition: bool, label: String) -> void:
	print("%s: %s" % [label, condition])
	_failed = _failed or not condition
