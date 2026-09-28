extends SceneTree

const DIRECTORY := "user://c1_candidate_process_probe"
var errors: Array[String] = []
var environment: Script


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# SceneTree 스크립트 preload 시점에는 오토로드 전역 이름이 아직 준비되지 않는다.
	environment = load("res://test/save/c1_candidate_environment.gd")
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "seed", "hold", "save", "verify"]:
		quit(2)
		return
	var phase: String = args[0]
	var world: Node
	if phase == "cleanup":
		if DirAccess.dir_exists_absolute(DIRECTORY):
			for file in DirAccess.get_files_at(DIRECTORY):
				DirAccess.remove_absolute(DIRECTORY.path_join(file))
			DirAccess.remove_absolute(DIRECTORY)
	elif phase == "seed":
		environment.seed_files(DIRECTORY)
		var file := FileAccess.open(DIRECTORY.path_join("original.sha256"), FileAccess.WRITE)
		file.store_string(FileAccess.get_sha256(DIRECTORY.path_join("character_01.json")))
		file.close()
	else:
		world = _boot(phase)
	if is_instance_valid(world):
		world.free()
	var bgm := root.get_node_or_null("BgmManager")
	if bgm != null:
		bgm.reset()
	await process_frame
	await process_frame
	print("C1_SESSION_PROCESS_PASS " + phase if errors.is_empty() else str(errors))
	quit(0 if errors.is_empty() else 1)


func _boot(phase: String) -> Node:
	var path := DIRECTORY.path_join("character_01.json")
	var hash_path := DIRECTORY.path_join("original.sha256")
	if not FileAccess.file_exists(hash_path):
		errors.append("seed fixture missing")
		return null
	var digest := FileAccess.get_file_as_string(hash_path)
	var store = environment.Store.new(DIRECTORY)
	var account: Dictionary = store.read_save("account")
	if not account.ok:
		errors.append("account read failed")
		return null
	var codec = environment.Codec.new()
	codec.bind_store(store, account.data)
	var read: Dictionary = store.read_save("character", 1)
	if not read.ok:
		errors.append("character read failed")
		return null
	var world: Node = load(environment.WORLD_PATH).instantiate()
	world.set_meta("save_directory", DIRECTORY)
	world.set_meta("save_boot", {"account": account.data, "character": read.data, "slot": 1})
	root.add_child(world)
	current_scene = world
	world.process_mode = Node.PROCESS_MODE_DISABLED
	if world.get_meta("save_boot_error") != "":
		errors.append("world boot failed")
		return world
	var session = world.get_node("SaveSession")
	var player = world.get_node("Player")
	player.get_node("PlayerStats")._time_since_combat_action_sec = 10.0
	_check(player.get_node("PlayerProgression").current_exp == 20000, "converted exp")
	_check(player.get_node("PlayerProgression").level_curve.req(20) == 39355, "C1 runtime")
	if phase in ["hold", "save"]:
		_check(session.loaded_source_version == 2 and session.migration_pending, "pending V2")
		session.advance(181.0)
		_check(FileAccess.get_sha256(path) == digest, "auto preserved original")
		if phase == "save":
			player.position += Vector2(8, 0)
			player.get_node("Inventory").gold = 99
			_check(session.save_slot(1).ok, "manual save")
			_check(not session.migration_pending, "pending cleared")
			_check(FileAccess.get_sha256(path + ".bak") == digest, "V2 backup retained")
	else:
		_check(session.loaded_source_version == 4 and not session.migration_pending, "V4 restart")
		_check(player.position == Vector2(168, 504), "moved position restored")
		_check(player.get_node("Inventory").gold == 99, "gold restored")
		_check(FileAccess.get_sha256(path + ".bak") == digest, "backup hash after restart")
		_check(
			(
				environment.LegacyStore.new(DIRECTORY).read_save("character", 1).code
				== "unsupported_version"
			),
			"legacy file contract refuses V3"
		)
	return world


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
