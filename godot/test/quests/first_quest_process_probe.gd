extends SceneTree

const WORLD := "res://scenes/world/eastern_frontier_starting_area.tscn"
const ROOT := "user://m5_first_quest_probe"
const NPC := "yeoulmok_receptionist"
var errors: Array[String] = []
var completed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if (
		args.size() != 1
		or args[0] not in ["cleanup", "seed", "active", "ready", "completed", "legacy"]
	):
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(ROOT):
			for file in DirAccess.get_files_at(ROOT):
				DirAccess.remove_absolute(ROOT.path_join(file))
			DirAccess.remove_absolute(ROOT)
		completed = true
	elif args[0] == "seed":
		_seed()
	else:
		_verify(args[0])
	_check(completed, "phase reached final checks")
	var bgm := root.get_node_or_null("BgmManager")
	if bgm == null or not bgm.has_method("reset"):
		_check(false, "audio cleanup unavailable: BgmManager.reset")
	else:
		bgm.call("reset")
	await process_frame
	print("M5_FIRST_QUEST_PROCESS_PASS " + args[0] if errors.is_empty() else str(errors))
	quit(0 if errors.is_empty() else 1)


func _world() -> Node:
	var world: Node = load(WORLD).instantiate()
	world.set_meta("save_directory", ROOT)
	root.add_child(world)
	current_scene = world
	world.process_mode = Node.PROCESS_MODE_DISABLED
	# Deterministic data probe, not live movement/combat or save-safety QA.
	world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0
	return world


func _first(controller: Node) -> void:
	controller.journal.record_event("REACH", NPC, "", 0)
	controller.journal.record_event("TALK", NPC, "", 0)
	_check(controller.report("MQ-01-01", NPC) == "", "first reward")
	_check(controller.journal.accept("MQ-01-02") == "", "accept second")


func _kill(journal: RefCounted, token: int) -> void:
	journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", token)


func _snapshot(world: Node) -> Dictionary:
	var session = world.get_node("SaveSession")
	return session.codec.capture(
		world.get_node("Player"), session.account.account_id, session.character
	)


func _seed() -> void:
	for slot in range(1, 5):
		var world := _world()
		var controller: Node = world.get_node("QuestController")
		var session = world.get_node("SaveSession")
		if slot < 4:
			_first(controller)
			_kill(controller.journal, 1)
			if slot >= 2:
				_kill(controller.journal, 2)
			if slot == 3:
				_check(controller.report("MQ-01-02", NPC) == "", "second reward")
		else:
			var progression = world.get_node("Player/PlayerProgression")
			progression.add_exp(progression.exp_to_next())
			var inventory = world.get_node("Player/Inventory")
			var ring = session.codec.registry.items["ACC-RING-10-B"]
			_check(inventory.add_to_bag(ring, 1), "legacy bag")
			_check(inventory.equip(ring), "legacy equip")
		_check(session.save_slot(slot).ok, "save slot %d" % slot)
		_write("expected_%d.json" % slot, JSON.stringify(session.character))
		if slot == 4:
			var old: Dictionary = session.character.duplicate(true)
			old.character_save_version = 1
			old.progress.quests = {}
			var payload := JSON.stringify(old)
			_write(
				"character_04.json",
				JSON.stringify(
					{
						"kind": "character",
						"version": 1,
						"payload": payload,
						"checksum": payload.sha256_text()
					}
				)
			)
		world.free()
	var hashes := {}
	for slot in range(1, 5):
		var name := "character_%02d.json" % slot
		hashes[name] = FileAccess.get_sha256(ROOT.path_join(name))
	_write("hashes.json", JSON.stringify(hashes))
	completed = true


func _verify(phase: String) -> void:
	var slot: int = {"active": 1, "ready": 2, "completed": 3, "legacy": 4}[phase]
	var expected := _read_fixture("expected_%d.json" % slot)
	var hashes := _read_fixture("hashes.json")
	if expected.is_empty() or hashes.is_empty():
		return
	var world := _world()
	var result: Dictionary = world.get_node("SaveSession").load_slot(slot)
	_check(result.ok, "load " + phase)
	if not result.ok:
		world.free()
		return
	world = current_scene
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var before := _snapshot(world)
	_check(JSON.parse_string(JSON.stringify(before)) == expected, "full restored payload " + phase)
	var controller: Node = world.get_node("QuestController")
	if phase != "legacy":
		var quest: Dictionary = controller.journal.export_state()["MQ-01-02"]
		_check(quest.state == phase, "explicit restored quest state")
		_check(quest.counts == ([1] if phase == "active" else [2]), "explicit restored counts")
		var progression = world.get_node("Player/PlayerProgression")
		var earned: int = progression.current_exp
		for level in range(1, progression.current_level):
			earned += progression.level_curve.req(level)
		_check(earned == (400 if phase == "completed" else 75), "quest-only EXP total")
	if phase == "legacy":
		_check(world.get_node("SaveSession").migration_pending, "legacy pending")
		_first(controller)
		_check(
			controller.journal.export_state()["MQ-01-02"].state == "active", "legacy quest start"
		)
		_check(
			_snapshot(world).inventory.equipment == before.inventory.equipment,
			"legacy gear retained"
		)
	elif phase == "completed":
		_check(controller.report("MQ-01-02", NPC) == "quest_not_ready", "duplicate reward rejected")
		_check(_snapshot(world) == before, "duplicate reward leaves all state unchanged")
	else:
		if phase == "active":
			_kill(controller.journal, 700)
		_check(controller.report("MQ-01-02", NPC) == "", "restored reward")
		_check(world.get_node("Player/Inventory").gold == 120, "reward gold")
		var inventory = world.get_node("Player/Inventory")
		_check(inventory.get_bag_quantity("POT-HP-1") == 2, "reward potions")
		var after := _snapshot(world)
		_check(controller.report("MQ-01-02", NPC) == "quest_not_ready", "repeat report")
		_check(_snapshot(world) == after, "repeat unchanged")
	world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0
	_check(world.get_node("SaveSession").save_slot(5).ok, "save progressed character to other slot")
	for name in hashes:
		_check(
			FileAccess.get_sha256(ROOT.path_join(name)) == hashes[name],
			"original/other slot unchanged " + name
		)
	world.free()
	completed = true


func _read_fixture(name: String) -> Dictionary:
	var path := ROOT.path_join(name)
	if not FileAccess.file_exists(path):
		_check(false, "fixture missing: " + name + " (run seed first)")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.is_empty():
		_check(false, "fixture invalid or empty: " + name)
		return {}
	return parsed


func _write(name: String, value: String) -> void:
	var file := FileAccess.open(ROOT.path_join(name), FileAccess.WRITE)
	if file == null:
		_check(false, "fixture write " + name)
		return
	file.store_string(value)
	file.close()


func _check(valid: bool, message: String) -> void:
	if not valid:
		errors.append(message)
