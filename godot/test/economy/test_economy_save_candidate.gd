extends GutTest

const Candidate = preload("res://scripts/economy/economy_environment.gd")
const Conversion = preload("res://scripts/economy/economy_save_candidate.gd")
const Codec = preload("res://scripts/save/character_save_codec.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
var codec = Codec.new()
var account: Dictionary
var source: Node2D


func before_each() -> void:
	account = codec.new_account()
	source = PLAYER.instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	source.add_child(inventory)
	add_child_autofree(source)
	source.process_mode = Node.PROCESS_MODE_DISABLED
	source.position = Vector2(152, 504)


func test_migration_source_immutable_and_idempotent() -> void:
	var conversion := Conversion.new()
	var data: Dictionary = codec.capture(source, account.account_id)
	var before := data.duplicate(true)
	var result: Dictionary = conversion.upgrade(data, account)
	assert_true(result.ok)
	assert_eq(data, before)
	assert_eq(result.data.character_save_version, 5)
	assert_eq(conversion.validate(result.data, account), "")
	assert_eq(conversion.upgrade(result.data, account).data, result.data)
	assert_eq(codec.schema.character_error(result.data, account), "unsupported_version")
	result.data.player.hp = 100000
	assert_eq(conversion.validate(result.data, account), "vitals")


func test_old_invalid_weapon_preserved_when_bag_full() -> void:
	var conversion := Conversion.new()
	var data: Dictionary = codec.capture(source, account.account_id)
	data.inventory.equipment.weapon = "WPN-GS-40-B"
	for id in codec.registry.items:
		if data.inventory.bag.size() == 30:
			break
		if id != "WPN-GS-40-B":
			data.inventory.bag.append({"item_id": id, "quantity": 1})
	assert_eq(codec.schema.character_error(data, account), "")
	var result: Dictionary = conversion.upgrade(data, account)
	assert_true(result.ok)
	assert_eq(result.data.inventory.overflow, [{"item_id": "WPN-GS-40-B", "quantity": 1}])
	assert_eq(result.data.inventory.bag, data.inventory.bag)
	var forged: Dictionary = result.data.duplicate(true)
	forged.inventory.equipment.weapon = "WPN-GS-40-B"
	assert_eq(conversion.validate(forged, account), "equipment_level")


func test_candidate_world_binding_and_no_healing_by_swapping() -> void:
	var world: Node = Candidate.instantiate_world()
	world.set_meta("save_directory", "user://m6_candidate_test")
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	assert_eq(world.get_meta("save_boot_error"), "")
	var actor = world.get_node("Player")
	var economy = actor.get_meta("economy_candidate")
	var stats = actor.get_node("PlayerStats")
	stats.current_hp = 50
	var before: float = stats.stats.attack_power
	assert_eq(economy.act("unequip", "", "weapon"), "")
	assert_lt(stats.stats.attack_power, before)
	assert_eq(economy.act("equip", "WPN-SW-01-C", "weapon"), "")
	assert_eq(stats.stats.attack_power, before)
	assert_eq(stats.current_hp, 50.0)
	var saved: Dictionary = world.get_node("SaveSession").codec.capture(actor, account.account_id)
	assert_eq(Conversion.new().validate(saved, account), "")


func test_all_levels_and_four_jobs_legacy_validation_before_conversion() -> void:
	var conversion := Conversion.new()
	var base: Dictionary = codec.capture(source, account.account_id)
	for job in ["adventurer", "warrior", "archer", "gladiator"]:
		for level in range(conversion.model.job_gate(job), 101):
			var data := base.duplicate(true)
			data.player.level = level
			data.player.job_id = job
			data.player.skill_points = level - 1 + codec.registry.tier(job) * 2
			var result: Dictionary = conversion.upgrade(data, account)
			assert_true(result.ok, "%s Lv%d" % [job, level])
			assert_eq(conversion.upgrade(result.data, account).data, result.data)
	var invalid := base.duplicate(true)
	invalid.player.hp = 999999
	assert_eq(conversion.upgrade(invalid, account).code, "vitals")
	for version in [1, 2, 3, 4]:
		var old := base.duplicate(true)
		old.character_save_version = version
		assert_true(conversion.upgrade(old, account).ok)


func test_transition_grants_once_and_level_growth_keeps_equipment() -> void:
	var world: Node = Candidate.instantiate_world()
	world.set_meta("save_directory", "user://m6_candidate_test")
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var actor = world.get_node("Player")
	var progression = actor.get_node("PlayerProgression")
	var transition = actor.get_node("PlayerJobTransition")
	var economy = actor.get_meta("economy_candidate")
	while progression.current_level < 10:
		progression.add_exp(progression.exp_to_next())
	assert_true(transition.perform_transition(&"archer"))
	var state: Dictionary = economy.state()
	assert_eq(state.equipment.weapon, transition.granted_weapon().item_id)
	assert_eq(economy.model.quantity(state.bag, "WPN-SW-01-C"), 1)
	assert_false(transition.perform_transition(&"archer"))
	assert_eq(economy.state(), state)
	progression.add_exp(progression.exp_to_next())
	assert_eq(economy.state(), state)
	var expected: CombatantStats = economy.model.stats(11, "archer", state.equipment)
	assert_eq(actor.get_node("PlayerStats").stats.attack_power, expected.attack_power)
	var captured: Dictionary = world.get_node("SaveSession").codec.capture(
		actor, account.account_id
	)
	assert_eq(Conversion.new().validate(captured, account), "")


func test_candidate_path_refuses_production_directory() -> void:
	var world := Node.new()
	world.set_meta("save_directory", "user://saves")
	autofree(world)
	var session := Candidate.CandidateSession.new()
	autofree(session)
	assert_eq(session.setup(world), "candidate_directory")


func test_candidate_file_roundtrip_content_error_blocks_without_backup() -> void:
	var directory := "user://m6_candidate_file_test"
	var store := Candidate.CandidateStore.new(directory)
	var candidate_codec := Candidate.CandidateCodec.new()
	assert_eq(candidate_codec.bind_store(store, account), "")
	var data: Dictionary = (
		candidate_codec.prepare_loaded(codec.capture(source, account.account_id), account).data
	)
	assert_true(store.write_save("character", 1, data).ok)
	assert_true(store.read_save("character", 1).ok)
	var path := directory.path_join("character_01.json")
	var digest := FileAccess.get_sha256(path)
	assert_eq(
		(
			preload("res://scripts/save/save_file_store.gd")
			. new(directory)
			. read_save("character", 1)
			. code
		),
		"unsupported_version"
	)
	candidate_codec.schema.conversion.model.catalog.prices["POT-HP-1"].buy = -1
	assert_eq(store.read_save("character", 1).code, "economy_content_error")
	assert_eq(store.write_save("character", 1, data).code, "economy_content_error")
	assert_eq(FileAccess.get_sha256(path), digest)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))


func test_four_jobs_candidate_restore_uses_same_stats_and_no_extra_items() -> void:
	var candidate_codec := Candidate.CandidateCodec.new()
	for job in ["adventurer", "warrior", "archer", "gladiator"]:
		var data: Dictionary = codec.capture(source, account.account_id)
		var level: int = candidate_codec.schema.conversion.model.job_gate(job)
		data.player.level = level
		data.player.job_id = job
		data.player.skill_points = level - 1 + codec.registry.tier(job) * 2
		var result: Dictionary = candidate_codec.prepare_loaded(data, account)
		assert_true(result.ok)
		var target := PLAYER.instantiate()
		var inventory := InventoryComponent.new()
		inventory.name = "Inventory"
		target.add_child(inventory)
		add_child_autofree(target)
		target.process_mode = Node.PROCESS_MODE_DISABLED
		assert_eq(candidate_codec.restore_into(target, result.data, account), "")
		assert_eq(candidate_codec.capture(target, account.account_id, result.data), result.data)
		var maximum: CombatantStats = candidate_codec.schema.conversion.model.stats(
			level, job, result.data.inventory.equipment
		)
		assert_eq(target.get_node("PlayerStats").stats.attack_power, maximum.attack_power)


func test_notifications_cannot_reenter_trade_or_save() -> void:
	var world: Node = Candidate.instantiate_world()
	world.set_meta("save_directory", "user://m6_candidate_test")
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var actor = world.get_node("Player")
	var economy = actor.get_meta("economy_candidate")
	var observed := {}
	economy.changed.connect(
		func():
			observed.action = economy.act("unequip", "", "body")
			observed.save = world.get_node("SaveSession").save_slot(1).code
	)
	assert_eq(economy.act("unequip", "", "weapon"), "")
	assert_eq(observed, {"action": "busy", "save": "transaction_busy"})
	var stats = actor.get_node("PlayerStats")
	assert_same(actor.get_node("AttackResolver").attacker_stats, stats.stats)
	stats.current_hp = 50
	for count in range(5):
		assert_eq(economy.act("unequip", "", "necklace"), "")
		assert_eq(economy.act("equip", "ACC-NECK-01-C", "necklace"), "")
	assert_eq(stats.current_hp, 50.0)
