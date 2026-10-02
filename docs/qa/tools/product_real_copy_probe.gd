## Reads/writes only the runner-created QA copies. Never opens user://saves.
extends SceneTree

const ROOT := "user://product_real_copy"
var failed := false
var finished := false
var world: Node


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	failed = failed or not value
	print(label, ": ", value)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["migrate", "verify"] or args[1] not in ["1", "3"]:
		quit(2)
		return
	await inspect_copy(args[0], int(args[1]))
	check(finished, "Copy inspection completed")
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("PRODUCT_REAL_COPY_FAIL" if failed else "PRODUCT_REAL_COPY_PASS")
	quit(1 if failed else 0)


func inspect_copy(phase: String, slot: int) -> void:
	var path := ROOT.path_join("character_%02d.json" % slot)
	var before := FileAccess.get_sha256(path)
	world = load("res://scripts/world/game_product.gd").instantiate_world()
	world.set_meta("save_directory", ROOT)
	root.add_child(world)
	current_scene = world
	check(world.get_meta("save_boot_error", "") == "", "QA account accepted")
	check(world.get_node("SaveSession").load_slot(slot).ok, "QA copy loaded")
	await process_frame
	await process_frame
	world = current_scene
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var session = world.get_node("SaveSession")
	check(session.store.root == ROOT, "QA directory retained")
	check(FileAccess.get_sha256(path) == before, "Load leaves QA file unchanged")
	check(session.character.character_save_version == 6, "Product format 6")
	check(session.character.content_revision == load("res://scripts/content/game_content.gd").CURRENT_REVISION, "현행 콘텐츠 개정")
	var evidence := ROOT.path_join("expected_%02d.json" % slot)
	if phase == "migrate":
		check(session.loaded_source_version == (4 if slot == 1 else 5), "Expected legacy version")
		check(session.migration_pending, "Explicit save required")
		session.advance(181)
		check(FileAccess.get_sha256(path) == before, "Pending auto-save leaves QA file unchanged")
		world.process_mode = Node.PROCESS_MODE_INHERIT
		await create_timer(5.1).timeout
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var result: Dictionary = session.save_slot(slot)
		check(result.ok, "QA explicit migration save")
		check(FileAccess.get_sha256(path + ".bak") == before, "Legacy QA copy backed up")
		var file := FileAccess.open(evidence, FileAccess.WRITE)
		check(file != null, "QA snapshot open")
		if file != null:
			file.store_string(JSON.stringify(session.character, "", true, true))
			file.close()
	else:
		check(not session.migration_pending, "Reopened product requires no migration")
		var expected = JSON.parse_string(FileAccess.get_file_as_string(evidence))
		check(
			JSON.parse_string(JSON.stringify(session.character, "", true, true)) == expected,
			"Separate process full character restored"
		)
	finished = true
