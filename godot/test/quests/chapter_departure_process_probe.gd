extends SceneTree

const ROOT := "user://chapter_departure_probe"
var errors: Array[String] = []
var finished := false
var render := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if (
		args.is_empty()
		or args[0] not in ["cleanup", "seed", "depart", "verify", "return", "unsaved", "legacy"]
	):
		quit(2)
		return
	render = args.size() == 2 and args[1] == "render"
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(ROOT):
			for file in DirAccess.get_files_at(ROOT):
				DirAccess.remove_absolute(ROOT.path_join(file))
			DirAccess.remove_absolute(ROOT)
		finished = true
	else:
		await _phase(args[0])
	_check(finished, "final checks reached")
	root.get_node("BgmManager").reset()
	await process_frame
	print("CHAPTER_DEPARTURE_PASS " + args[0] if errors.is_empty() else str(errors))
	quit(0 if errors.is_empty() else 1)


func _phase(phase: String) -> void:
	var world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", ROOT)
	root.add_child(world)
	current_scene = world
	_freeze(world)
	for frame in 8:
		await process_frame
	var session = world.get_node("SaveSession")
	if phase in ["unsaved", "legacy"]:
		await _special(world, phase)
		return
	if phase != "seed":
		var loaded: Dictionary = session.load_slot(1)
		_check(loaded.ok, "load prior process")
		if not loaded.ok:
			world.free()
			return
		world = current_scene
		session = world.get_node("SaveSession")
		_freeze(world)
		for frame in 8:
			await process_frame
	var quests = world.get_node("QuestController")
	var player = world.get_node("Player")
	var journal = quests.journal
	if phase == "seed":
		var states := {}
		for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04"]:
			states[id] = {
				"state": "completed",
				"counts": journal.catalog.definitions[id].objective_counts.duplicate()
			}
		_check(journal.restore_state(states) == "", "previous quest fixture")
		_check(journal.accept("MQ-01-05") == "", "accept final quest")
		player.position = Vector2(152, 536)
		_check(session.save_slot(2).ok, "independent slot")
		_check(session.save_slot(1).ok, "seed save")
		var file := FileAccess.open(ROOT.path_join("slot2.sha"), FileAccess.WRITE)
		file.store_string(FileAccess.get_sha256(ROOT.path_join("character_02.json")))
		file.close()
	elif phase == "depart":
		_check(world.map_id == "eastern_frontier_start", "start map")
		player.position = Vector2(264, 456)
		world.get_node("WorldInteraction").refresh()
		_check(world.get_node("Gatewarden").interact(), "gate reach and dialogue")
		var dialog = world.get_node("QuestDialog")
		await _capture("departure-dialog")
		dialog.choose("report", "MQ-01-05")
		world = current_scene
		_check(world.map_id == "novera_gate", "report travels to second region")
		_freeze(world)
		session = world.get_node("SaveSession")
		await _capture("novera-arrival")
		_check(session.save_slot(1).ok, "save destination")
	elif phase in ["verify", "return"]:
		_check(world.map_id == "novera_gate", "destination restored")
		_check(player.position == Vector2(144, 440), "destination position restored")
		_check(journal.reputation() == 100, "reputation restored")
		_check(player.get_node("Inventory").gold == 560, "reward once")
		_check(
			quests.report("MQ-01-05", "yeoulmok_gatewarden") == "quest_not_ready",
			"no repeated reward"
		)
		if phase == "return":
			var before: Dictionary = session.codec.capture(
				player, session.account.account_id, session.character
			)
			_check(session.travel("eastern_frontier_start").ok, "return trip")
			world = current_scene
			_freeze(world)
			var returned_session = world.get_node("SaveSession")
			var after: Dictionary = returned_session.codec.capture(
				world.get_node("Player"),
				returned_session.account.account_id,
				returned_session.character
			)
			for field in ["character_id", "player", "inventory", "progress"]:
				_check(before[field] == after[field], "return snapshot " + field)
			_check(world.map_id == "eastern_frontier_start", "return map")
			_check(world.get_node("Player").position == Vector2(248, 456), "return arrival")
			_check(
				world.get_node("QuestController").journal.reputation() == 100,
				"return keeps reputation"
			)
			await _capture("yeoulmok-return")
	if phase != "seed":
		_check(
			(
				FileAccess.get_sha256(ROOT.path_join("character_02.json"))
				== FileAccess.get_file_as_string(ROOT.path_join("slot2.sha"))
			),
			"other slot unchanged"
		)
	world.free()
	finished = true


func _special(world: Node, phase: String) -> void:
	var session = world.get_node("SaveSession")
	var quests = world.get_node("QuestController")
	var states := {}
	for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04"]:
		states[id] = {
			"state": "completed",
			"counts": quests.journal.catalog.definitions[id].objective_counts.duplicate()
		}
	_check(quests.journal.restore_state(states) == "", "special fixture")
	var path := ROOT.path_join("character_01.json")
	var digest := ""
	if phase == "legacy":
		world.get_node("Player").position = Vector2(152, 536)
		_check(session.save_slot(1).ok, "legacy seed account")
		var old: Dictionary = session.character.duplicate(true)
		old.character_save_version = 3
		var payload := JSON.stringify(old)
		_check(
			(
				session.store._write_text(
					path,
					JSON.stringify(
						{
							"kind": "character",
							"version": 3,
							"payload": payload,
							"checksum": payload.sha256_text()
						}
					)
				)
				== OK
			),
			"legacy envelope"
		)
		digest = FileAccess.get_sha256(path)
		_check(session.load_slot(1).ok, "legacy load")
		world = current_scene
		_freeze(world)
		session = world.get_node("SaveSession")
		quests = world.get_node("QuestController")
	quests.journal.accept("MQ-01-05")
	world.get_node("Player").position = Vector2(264, 456)
	_check(world.get_node("Gatewarden").interact(), "special gate")
	var account_id: String = session.account.account_id
	world.get_node("QuestDialog").choose("report", "MQ-01-05")
	world = current_scene
	_freeze(world)
	session = world.get_node("SaveSession")
	_check(world.map_id == "novera_gate", "special travel")
	_check(session.account.account_id == account_id, "account identity retained")
	var character_id: String = session.character.character_id
	if phase == "legacy":
		_check(
			session.migration_pending and session.loaded_source_version == 3,
			"old-save hold carried across travel"
		)
		session.advance(1000.0)
		_check(FileAccess.get_sha256(path) == digest, "old file untouched by travel/autosave")
	else:
		_check(
			session.active_slot == 0 and not FileAccess.file_exists(path),
			"unsaved travel creates no character file"
		)
	_check(session.save_slot(1).ok, "explicit save after travel")
	_check(not session.migration_pending, "explicit save releases hold")
	_check(session.load_slot(1).ok, "reload destination")
	world = current_scene
	_freeze(world)
	_check(world.map_id == "novera_gate", "special restored map")
	_check(
		world.get_node("SaveSession").character.character_id == character_id,
		"character identity retained"
	)
	_check(world.get_node("Player/Inventory").gold == 560, "special reward once")
	world.free()
	finished = true


func _capture(label: String) -> void:
	if not render:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../docs/qa/screenshots/m5-chapter")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(
		root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK,
		"capture " + label
	)


func _freeze(world: Node) -> void:
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("WorldInteraction").process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0


func _check(condition: bool, label: String) -> void:
	if not condition:
		errors.append(label)
