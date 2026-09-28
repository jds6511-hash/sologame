extends GutTest

const Codec = preload("res://scripts/save/character_save_codec.gd")
const Store = preload("res://scripts/save/save_file_store.gd")
const Rules = preload("res://scripts/save/save_progression_rules.gd")
const CURVE = preload("res://data/progression/level_curve.tres")
const Env = preload("res://test/save/c1_candidate_environment.gd")


func after_each() -> void:
	BgmManager.reset()
	GameClock.reset()


func test_product_curve_matches_all_c1_requirements() -> void:
	var rules = Rules.for_version(3)
	var total := 0
	for level in range(1, 100):
		assert_eq(CURVE.req(level), rules.req(level), "제품 REQ(%d)" % level)
		total += CURVE.req(level)
	assert_eq(total, 61860102)


func test_product_file_and_codec_versions_are_v4() -> void:
	var store = Store.new("user://c1_product_unused")
	assert_eq(store.current_version("character"), 4)
	assert_eq(store.supported_versions("character"), [1, 2, 3, 4])
	assert_eq(Codec.new().character_version(), 4)


func test_restore_requires_conversion_before_applying_legacy_exp() -> void:
	var directory := "user://c1_candidate_restore_%d" % Time.get_ticks_usec()
	var fixture: Dictionary = Env.seed_files(directory)
	var world = load(Env.WORLD_PATH).instantiate()
	world.set_meta("save_directory", directory)
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player = world.get_node("Player")
	var codec = Codec.new()
	assert_eq(codec.restore_into(player, fixture.data, fixture.account), "migration_required")
	assert_eq(player.get_node("PlayerProgression").current_level, 1)
	var prepared: Dictionary = codec.prepare_loaded(fixture.data, fixture.account)
	assert_true(prepared.ok)
	assert_eq(codec.restore_into(player, prepared.data, fixture.account), "")
	assert_eq(player.get_node("PlayerProgression").current_exp, 20000)
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
