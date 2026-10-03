extends GutTest

const Product = preload("res://scripts/economy/economy_product.gd")
const Candidate = preload("res://scripts/economy/economy_environment.gd")
const TEST_ROOT := "user://m6_product_test"


func before_each() -> void:
	DirAccess.remove_absolute(TEST_ROOT.path_join("account.json"))


func after_each() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(TEST_ROOT.path_join("account.json"))


func test_default_root_is_production_without_opening_user_files() -> void:
	var world: Node = Product.instantiate_world()
	assert_eq(world.get_meta("save_directory", ""), "user://saves")
	world.free()


func test_product_world_installs_v7_and_equipment_ui() -> void:
	var world: Node = Product.instantiate_world()
	world.set_meta("save_directory", TEST_ROOT)
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	assert_eq(world.get_meta("save_boot_error", ""), "")
	if world.get_meta("save_boot_error", "") != "":
		return
	var session = world.get_node("SaveSession")
	assert_eq(session.codec.character_version(), 7)
	assert_eq(session.store.root, TEST_ROOT)
	assert_true(world.has_node("EconomyPanel"))
	assert_true(world.get_node("Player").has_meta("economy_candidate"))
	for label in world.get_node("EconomyPanel").find_children("*", "Label", true, false):
		assert_false(label.text.begins_with("M6 후보"))
	for destination in ["eastern_frontier_start", "novera_gate"]:
		session._destination = destination
		var next: Node = session._instantiate_world()
		assert_eq(next.get_script(), world.get_script(), "월드 교체에서도 제품 배선")
		assert_eq(next.map_id, destination, "제품 스크립트 교체 뒤에도 요청 지역 유지")
		next.free()


func test_candidate_still_refuses_production_root() -> void:
	var owner := Node.new()
	owner.set_meta("save_directory", "user://saves")
	var session := Candidate.CandidateSession.new()
	assert_eq(session.setup(owner), "candidate_directory")
	session.free()
	owner.free()


func test_invalid_account_keeps_save_error_menu_usable() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_ROOT)
	var path := TEST_ROOT.path_join("account.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	var world: Node = Product.instantiate_world()
	world.set_meta("save_directory", TEST_ROOT)
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var session = world.get_node("SaveSession")
	assert_false(session.account_error.is_empty())
	assert_false(world.get_node("Player").has_meta("economy_candidate"))
	world.get_node("SaveMenu").open_menu()
	assert_true(world.get_node("SaveMenu").panel.visible)
	assert_eq(session.save_slot(1).code, session.account_error)
	world.get_node("SaveMenu").close_menu()
	assert_eq(FileAccess.get_file_as_string(path), "{}")
	DirAccess.remove_absolute(path)
