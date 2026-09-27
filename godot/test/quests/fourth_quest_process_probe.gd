extends SceneTree

const ROOT := "user://m5_fourth_process"
const NPC := "yeoulmok_receptionist"
var errors: Array[String] = []
var completed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if (
		args.size() != 1
		or args[0] not in ["cleanup", "seed", "active", "reach", "ready", "completed"]
	):
		quit(2)
		return
	var phase: String = args[0]
	if phase == "cleanup":
		if DirAccess.dir_exists_absolute(ROOT):
			for name in DirAccess.get_files_at(ROOT):
				DirAccess.remove_absolute(ROOT.path_join(name))
			DirAccess.remove_absolute(ROOT)
		completed = true
	else:
		_check_phase(phase)
	_check(completed, "phase reached final checks")
	root.get_node("BgmManager").reset()
	await process_frame
	print("M5_FOURTH_PROCESS_PASS " + phase if errors.is_empty() else str(errors))
	quit(0 if errors.is_empty() else 1)


func _world() -> Node:
	var world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", ROOT)
	root.add_child(world)
	current_scene = world
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("WorldInteraction").process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0
	return world


func _check_phase(phase: String) -> void:
	var world := _world()
	var session = world.get_node("SaveSession")
	if phase != "seed":
		var result: Dictionary = session.load_slot(1)
		_check(result.ok, "load")
		if not result.ok:
			world.free()
			return
		world = current_scene
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.get_node("WorldInteraction").process_mode = Node.PROCESS_MODE_DISABLED
		session = world.get_node("SaveSession")
		world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0
	var quests = world.get_node("QuestController")
	var before: Dictionary = quests.journal.export_state()
	if phase == "seed":
		_check(
			(
				quests.journal.restore_state(
					{
						"MQ-01-01": {"state": "completed", "counts": [1, 1]},
						"MQ-01-02": {"state": "completed", "counts": [2]},
						"MQ-01-03": {"state": "completed", "counts": [2]}
					}
				)
				== ""
			),
			"restore previous content"
		)
		_check(session.save_slot(2).ok, "independent slot")
		_check(session.save_slot(1).ok, "seed current")
		# 구 V2 3의뢰 저장을 실제 파일로 다시 포장한다. Lv1/EXP0은 두 곡선에 유효하다.
		var old: Dictionary = session.character.duplicate(true)
		old.character_save_version = 2
		var payload := JSON.stringify(old)
		_write(
			"character_01.json",
			JSON.stringify(
				{
					"kind": "character",
					"version": 2,
					"payload": payload,
					"checksum": payload.sha256_text()
				}
			)
		)
		_write("slot2.sha", FileAccess.get_sha256(ROOT.path_join("character_02.json")))
	elif phase == "active":
		_check(not before.has("MQ-01-04"), "V2 does not auto accept fourth")
		_check(quests.journal.accept("MQ-01-04") == "", "accept")
	elif phase == "reach":
		_check(before["MQ-01-04"].counts == [0, 0], "active restore")
		quests.journal.record_event(
			"REACH", "yeoulmok_old_rift_entrance", "yeoulmok_old_rift_site", 0
		)
	elif phase == "ready":
		_check(before["MQ-01-04"].counts == [1, 0], "reach restore")
		quests.journal.record_event("INTERACT", "yeoulmok_rift_mark", "yeoulmok_old_rift_site", 0)
	elif phase == "completed":
		_check(before["MQ-01-04"].state in ["ready", "completed"], "ready/completed restore")
		if before["MQ-01-04"].state == "ready":
			_check(quests.report("MQ-01-04", NPC) == "", "report")
		_check(quests.report("MQ-01-04", NPC) == "quest_not_ready", "duplicate blocked")
		_check(world.get_node("Player/Inventory").gold == 300, "exact gold once")
		var progression = world.get_node("Player/PlayerProgression")
		_check(progression.current_level == 4 and progression.current_exp == 489, "exact EXP once")
	if phase != "seed":
		_check(session.save_slot(1).ok, "save current")
		_check(session.character.character_save_version == 3, "current version")
		_check(
			(
				FileAccess.get_sha256(ROOT.path_join("character_02.json"))
				== FileAccess.get_file_as_string(ROOT.path_join("slot2.sha"))
			),
			"other slot unchanged"
		)
	world.free()
	completed = true


func _write(name: String, value: String) -> void:
	var file := FileAccess.open(ROOT.path_join(name), FileAccess.WRITE)
	if file == null:
		_check(false, "write " + name)
		return
	file.store_string(value)
	file.close()


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
