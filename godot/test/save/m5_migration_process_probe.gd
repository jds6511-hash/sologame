extends SceneTree

const WORLD_PATH := "res://scenes/world/eastern_frontier_starting_area.tscn"
const ROOT := "user://m5_migration_process_probe"
var errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["seed", "upgrade", "verify", "cleanup"]:
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(ROOT):
			for file in DirAccess.get_files_at(ROOT):
				DirAccess.remove_absolute(ROOT.path_join(file))
			DirAccess.remove_absolute(ROOT)
	else:
		var world = load(WORLD_PATH).instantiate()
		world.set_meta("save_directory", ROOT)
		root.add_child(world)
		current_scene = world
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var session = world.get_node("SaveSession")
		world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0
		if args[0] == "seed":
			world.get_node("Player/Inventory").gold = 71
			_check(session.save_slot(1).ok, "seed")
			var old: Dictionary = session.character.duplicate(true)
			old.character_save_version = 1
			old.progress.quests = {}
			var payload := JSON.stringify(old)
			session.store._write_text(
				ROOT.path_join("character_01.json"),
				JSON.stringify(
					{
						"kind": "character",
						"version": 1,
						"payload": payload,
						"checksum": payload.sha256_text()
					}
				)
			)
			session.store._write_text(
				ROOT.path_join("original.sha"),
				FileAccess.get_sha256(ROOT.path_join("character_01.json"))
			)
		else:
			var result: Dictionary = session.load_slot(1)
			_check(result.ok, "load")
			if result.ok:
				world = current_scene
				world.process_mode = Node.PROCESS_MODE_DISABLED
				session = world.get_node("SaveSession")
				world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0
				_check(world.get_node("Player/Inventory").gold == 71, "gold")
				if args[0] == "upgrade":
					_check(session.migration_pending, "pending")
					session.advance(1000.0)
					var original := FileAccess.get_file_as_string(ROOT.path_join("original.sha"))
					_check(
						FileAccess.get_sha256(ROOT.path_join("character_01.json")) == original,
						"read_only"
					)
					_check(session.save_slot(1).ok, "manual")
					_check(not session.migration_pending, "cleared")
					_check(
						FileAccess.get_sha256(ROOT.path_join("character_01.json.bak")) == original,
						"v1_backup"
					)
				else:
					_check(not session.migration_pending, "current_format_boot")
					# This fixture targets the frozen base codec, now V4, not the old M5 V3.
					_check(
						(
							session.character.character_save_version
							== session.codec.character_version()
						),
						"current_codec_format"
					)
		world.free()
	print("M5_MIGRATION_PROCESS_PASS " + args[0] if errors.is_empty() else str(errors))
	quit(0 if errors.is_empty() else 1)


func _check(valid: bool, message: String) -> void:
	if not valid:
		errors.append(message)
