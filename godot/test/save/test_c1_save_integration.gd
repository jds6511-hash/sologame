extends GutTest

const Env = preload("res://test/save/c1_candidate_environment.gd")
var directory: String


func before_each() -> void:
	directory = "user://c1_candidate_gut_%d" % Time.get_ticks_usec()


func after_each() -> void:
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)


func test_candidate_store_writes_v3_without_changing_default_store() -> void:
	var store = Env.CandidateStore.new(directory)
	assert_true(store.write_save("character", 1, {"character_save_version": 3}).ok)
	assert_true(store.read_save("character", 1).ok)
	assert_eq(Env.Store.new(directory).read_save("character", 1).code, "unsupported_version")


func test_candidate_world_uses_c1_runtime_and_v3_session_together() -> void:
	var world = Env.instantiate_world()
	world.set_meta("save_directory", directory)
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var session = world.get_node("SaveSession")
	assert_true(session.codec is Env.CandidateCodec)
	if not session.codec is Env.CandidateCodec:
		return
	assert_eq(world.get_meta("save_boot_error"), "")
	assert_eq(world.get_node("Player/PlayerProgression").level_curve.req(20), 39355)
	assert_eq(
		(
			session
			. codec
			. capture(world.get_node("Player"), session.account.account_id)
			. character_save_version
		),
		3
	)


func _boot(fixture: Dictionary) -> Node:
	var world = Env.instantiate_world()
	world.set_meta("save_directory", directory)
	world.set_meta("save_boot", {"account": fixture.account, "character": fixture.data, "slot": 1})
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("Player/PlayerStats")._time_since_combat_action_sec = 10.0
	assert_eq(world.get_meta("save_boot_error"), "")
	return world


func test_v1_v2_hold_auto_and_preserve_bytes_on_failed_manual_save() -> void:
	for version in [1, 2]:
		var fixture: Dictionary = Env.seed_files(directory, version)
		var path := directory.path_join("character_01.json")
		var digest := FileAccess.get_sha256(path)
		var world := _boot(fixture)
		var session = world.get_node("SaveSession")
		assert_eq(session.loaded_source_version, version)
		assert_true(session.migration_pending)
		assert_eq(session.character.character_save_version, 3)
		assert_eq(world.get_node("Player/PlayerProgression").current_exp, 20000)
		session.advance(180.0)
		session.advance(1000.0)
		assert_eq(FileAccess.get_sha256(path), digest)
		world.get_node("Player").is_dashing = true
		assert_false(session.save_slot(1).ok)
		world.get_node("Player").is_dashing = false
		DirAccess.make_dir_absolute(path + ".tmp")
		assert_false(session.save_slot(1).ok)
		assert_true(session.migration_pending)
		assert_eq(FileAccess.get_sha256(path), digest)
		DirAccess.remove_absolute(path + ".tmp")
		assert_true(session.save_slot(1).ok)
		assert_false(session.migration_pending)
		assert_eq(FileAccess.get_sha256(path + ".bak"), digest)
		assert_eq(int(session.store.read_save("character", 1).data.character_save_version), 3)
		world.get_node("Player/Inventory").gold = 99
		session.advance(179.0)
		assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 71)
		session.advance(1.0)
		assert_eq(int(session.store.read_save("character", 1).data.inventory.gold), 99)


func test_mixed_generations_read_without_rewriting_and_recover_old_backup() -> void:
	var fixture: Dictionary = Env.seed_files(directory)
	var codec = Env.CandidateCodec.new()
	var store = Env.CandidateStore.new(directory)
	codec.bind_store(store, fixture.account)
	var path := directory.path_join("character_01.json")
	for versions in [[2, 1], [3, 2]]:
		var main: Dictionary = fixture.data.duplicate(true)
		main.character_save_version = versions[0]
		main.player.exp = 20000 if versions[0] == 3 else 50000
		var backup: Dictionary = fixture.data.duplicate(true)
		backup.character_save_version = versions[1]
		backup.progress.quests = {} if versions[1] == 1 else backup.progress.quests
		Env.write_fixture(path, main)
		Env.write_fixture(path + ".bak", backup)
		var main_hash := FileAccess.get_sha256(path)
		var backup_hash := FileAccess.get_sha256(path + ".bak")
		var result: Dictionary = store.read_save("character", 1)
		assert_true(result.ok)
		assert_false(result.recovered)
		assert_eq(FileAccess.get_sha256(path), main_hash)
		assert_eq(FileAccess.get_sha256(path + ".bak"), backup_hash)
		# 정상 주 파일을 검사한 같은 validator에서 구 세대 백업으로 폴백한다.
		main.player.exp = 999999
		Env.write_fixture(path, main)
		main_hash = FileAccess.get_sha256(path)
		result = store.read_save("character", 1)
		assert_true(result.ok)
		assert_true(result.recovered)
		assert_eq(int(result.data.character_save_version), versions[1])
		assert_true(codec.prepare_loaded(result.data, fixture.account).ok)
		assert_eq(FileAccess.get_sha256(path), main_hash)
		assert_eq(FileAccess.get_sha256(path + ".bak"), backup_hash)


func test_future_main_and_backup_are_not_destroyed() -> void:
	var fixture: Dictionary = Env.seed_files(directory)
	var store = Env.CandidateStore.new(directory)
	var codec = Env.CandidateCodec.new()
	codec.bind_store(store, fixture.account)
	var upgraded: Dictionary = codec.prepare_loaded(fixture.data, fixture.account).data
	var future := upgraded.duplicate(true)
	future.character_save_version = 4
	var path := directory.path_join("character_01.json")
	Env.write_fixture(path, future)
	var digest := FileAccess.get_sha256(path)
	assert_eq(store.read_save("character", 1).code, "unsupported_version")
	assert_false(store.write_save("character", 1, upgraded).ok)
	assert_eq(FileAccess.get_sha256(path), digest)
	Env.write_fixture(path, fixture.data)
	Env.write_fixture(path + ".bak", future)
	assert_true(store.write_save("character", 1, upgraded).ok)
	assert_eq(FileAccess.get_sha256(path + ".bak.preserved." + digest), digest)


func test_other_slot_and_real_world_replacement_keep_candidate_runtime() -> void:
	var fixture: Dictionary = Env.seed_files(directory)
	var path := directory.path_join("character_01.json")
	var digest := FileAccess.get_sha256(path)
	var world := _boot(fixture)
	var session = world.get_node("SaveSession")
	world.get_node("SaveMenu").open_menu()
	world.get_node("SaveMenu").request_action("save")
	world.get_node("SaveMenu").close_menu()
	assert_true(session.migration_pending)
	assert_eq(FileAccess.get_sha256(path), digest)
	assert_true(session.save_slot(2).ok)
	assert_eq(FileAccess.get_sha256(path), digest)
	assert_true(session.load_slot(2).ok)
	var fresh: Node = get_children()[-1]
	autofree(fresh)
	fresh.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(fresh.get_node("SaveSession").codec is Env.CandidateCodec)
	assert_false(fresh.get_node("SaveSession").migration_pending)
	assert_eq(fresh.get_node("Player/PlayerProgression").current_exp, 20000)
	assert_eq(fresh.get_node("Player/PlayerProgression").level_curve.req(20), 39355)


func test_candidate_rejects_default_directory_and_old_runtime() -> void:
	var world = Env.instantiate_world()
	var session = Env.CandidateSession.new()
	assert_eq(session.setup(world), "candidate_directory")
	world.set_meta("save_directory", directory)
	world.get_node("Player/PlayerProgression").level_curve = Env.Codec.new().registry.CURVE
	assert_eq(session.setup(world), "candidate_runtime")
	session.free()
	world.free()


func test_corrupt_main_recovers_v2_backup_without_mutating_either_file() -> void:
	var fixture: Dictionary = Env.seed_files(directory)
	var store = Env.CandidateStore.new(directory)
	var codec = Env.CandidateCodec.new()
	codec.bind_store(store, fixture.account)
	var path := directory.path_join("character_01.json")
	Env.write_fixture(path + ".bak", fixture.data)
	store._write_text(path, "broken JSON")
	var digest := FileAccess.get_sha256(path)
	var backup_digest := FileAccess.get_sha256(path + ".bak")
	var result: Dictionary = store.read_save("character", 1)
	assert_true(result.ok)
	assert_true(result.recovered)
	assert_eq(result.main_code, "corrupt")
	assert_eq(FileAccess.get_sha256(path), digest)
	assert_eq(FileAccess.get_sha256(path + ".bak"), backup_digest)
	var prepared: Dictionary = codec.prepare_loaded(result.data, fixture.account)
	assert_true(store.write_save("character", 1, prepared.data).ok)
	assert_eq(FileAccess.get_sha256(path + ".bak"), backup_digest)


func test_candidate_content_error_blocks_fallback_and_preservation() -> void:
	var fixture: Dictionary = Env.seed_files(directory)
	var store = Env.CandidateStore.new(directory)
	var codec = Env.CandidateCodec.new()
	codec.bind_store(store, fixture.account)
	var upgraded: Dictionary = codec.prepare_loaded(fixture.data, fixture.account).data
	var path := directory.path_join("character_01.json")
	Env.write_fixture(path, upgraded)
	Env.write_fixture(path + ".bak", fixture.data)
	var digest := FileAccess.get_sha256(path)
	var backup_digest := FileAccess.get_sha256(path + ".bak")
	var definition = codec.schema.quest_catalog.definitions["MQ-01-02"].duplicate(true)
	definition.reward_exp = -1
	codec.schema.quest_catalog.definitions["MQ-01-02"] = definition
	var result: Dictionary = store.read_save("character", 1)
	assert_eq(result.code, "quest_content_error")
	assert_eq(result.backup_code, "not_checked")
	assert_eq(store.write_save("character", 1, upgraded).code, "quest_content_error")
	assert_eq(FileAccess.get_sha256(path), digest)
	assert_eq(FileAccess.get_sha256(path + ".bak"), backup_digest)
	assert_eq(DirAccess.get_files_at(directory).size(), 3)
