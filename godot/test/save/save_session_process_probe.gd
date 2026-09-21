extends SceneTree

const WORLD_PATH := "res://scenes/world/eastern_frontier_starting_area.tscn"
const ROOT := "user://m4_session_process_probe"
const JOBS := ["adventurer", "warrior", "archer", "gladiator"]
var errors: Array[String] = []
var completed := false


func _initialize() -> void:
	_run.call_deferred()


func _new_world() -> Node:
	var world: Node = load(WORLD_PATH).instantiate()
	world.set_meta("save_directory", ROOT)
	root.add_child(world)
	current_scene = world
	world.process_mode = Node.PROCESS_MODE_DISABLED
	return world


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	match args[0]:
		"seed":
			_seed()
		"verify":
			_verify()
		"preview":
			var world := _new_world()
			var event := InputEventKey.new()
			event.keycode = KEY_F6
			event.pressed = true
			Input.parse_input_event(event)
			Input.flush_buffered_events()
			if not world.get_node("SaveMenu").panel.visible:
				errors.append("F6 did not open menu")
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../docs/qa/screenshots/m4-save-menu.png")
			world.get_node("SaveMenu").request_action("save")
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(
				"res://../docs/qa/screenshots/m4-save-confirm.png"
			)
			world.get_node("SaveMenu").close_menu()
			world.free()
			completed = true
		"cleanup":
			for file in DirAccess.get_files_at(ROOT):
				DirAccess.remove_absolute(ROOT.path_join(file))
			DirAccess.remove_absolute(ROOT)
			completed = true
		_:
			quit(2)
			return
	root.get_node("BgmManager").reset()
	await process_frame
	if not completed:
		errors.append("phase did not complete")
	print("M4_SESSION_PROCESS_PASS " + args[0] if errors.is_empty() else str(errors))
	quit(0 if errors.is_empty() else 1)


func _seed() -> void:
	var expected := []
	for index in JOBS.size():
		var world := _new_world()
		var player = world.get_node("Player")
		var session = world.get_node("SaveSession")
		var progression = player.get_node("PlayerProgression")
		var transition = player.get_node("PlayerJobTransition")
		var level := 1 if index == 0 else (40 if index == 3 else 10)
		while progression.current_level < level:
			progression.add_exp(progression.exp_to_next())
			if progression.current_level == 10:
				transition.perform_transition(&"archer" if index == 2 else &"warrior")
		if index == 3:
			transition.perform_transition(&"gladiator")
		if index > 0:
			if not player.get_node("PlayerSkillPoints").try_upgrade_skill(&"강타", false):
				errors.append("skill setup " + JOBS[index])
		progression.add_exp(int(progression.exp_to_next() * 0.4))
		player.position += Vector2(8.0, 0.0)
		var stats = player.get_node("PlayerStats")
		stats.current_hp = stats.stats.max_hp - 0.25
		stats.current_mp = stats.stats.max_mp - 0.5
		stats._time_since_combat_action_sec = 10.0
		player.get_node("Inventory").gold = 101 + index
		var ring = session.codec.registry.items["ACC-RING-10-B"]
		player.get_node("Inventory").add_to_bag(ring, 2)
		player.get_node("Inventory").equip(ring, 0)
		player.get_node("Inventory").equip(ring, 1)
		for slot in session.codec.registry.slots:
			if slot in ["ring_1", "ring_2"]:
				continue
			for item in session.codec.registry.items.values():
				if item.equip_slot == session.codec.registry.slots[slot]:
					player.get_node("Inventory").add_to_bag(item, 1)
					player.get_node("Inventory").equip(item)
					break
		world.get_node("TutorialController").tutorial_done = true
		session._play_seconds = 35.125 + index
		root.get_node("GameClock").prepare_scene_time(4, 1400.125)
		var result: Dictionary = session.save_slot(index + 1)
		if not result.ok:
			errors.append("seed %s: %s" % [JOBS[index], result.code])
		expected.append(session.character)
		world.free()
	var file := FileAccess.open(ROOT.path_join("expected.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()
	completed = true


func _verify() -> void:
	var expected: Array = JSON.parse_string(
		FileAccess.get_file_as_string(ROOT.path_join("expected.json"))
	)
	for index in JOBS.size():
		var world := _new_world()
		var result: Dictionary = world.get_node("SaveSession").load_slot(index + 1)
		if not result.ok:
			errors.append("load %s: %s" % [JOBS[index], result.code])
			world.free()
			continue
		var loaded := current_scene
		loaded.process_mode = Node.PROCESS_MODE_DISABLED
		var session = loaded.get_node("SaveSession")
		var actual: Dictionary = session.codec.capture(
			loaded.get_node("Player"), session.account.account_id, session.character
		)
		actual.tutorial = {
			"tutorial_done": loaded.get_node("TutorialController").tutorial_done,
			"hint_heal_done": loaded.get_node("TutorialController").hint_heal_done
		}
		if JSON.parse_string(JSON.stringify(actual)) != expected[index]:
			errors.append("roundtrip " + JOBS[index])
		loaded.free()
	completed = true
