extends GutTest
const Product = preload("res://scripts/world/game_product.gd")
const Model = preload("res://scripts/territory/territory_model.gd")
var world: Node


func before_each() -> void:
	world = Product.instantiate_world()
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var journal: QuestJournal = world.get_node("QuestController").journal
	var states := {}
	for id in journal.catalog.ordered_ids():
		if id.begins_with("MQ-04-") or id.begins_with("SQ-CH04-"):
			continue
		states[id] = {
			"state": "completed", "counts": Array(journal.catalog.definitions[id].objective_counts)
		}
	assert_eq(journal.restore_state(states), "")
	world.get_node("TerritoryRuntime")._sync()
	world.get_node("Player/Inventory").gold = 200000


func after_each() -> void:
	world.free()
	BgmManager.reset()
	get_tree().paused = false


func test_remote_write_rejected_and_onsite_build_installs_live_merchant() -> void:
	var runtime: Node = world.get_node("TerritoryRuntime")
	var initial: Dictionary = runtime.state().duplicate(true)
	assert_eq(runtime.act("market"), "onsite")
	assert_eq(runtime.state(), initial)
	world.get_node("Player").position = runtime.DESK
	assert_eq(runtime.act("workshop"), "")
	assert_not_null(world.get_node_or_null("TerritoryWorkshop"))
	assert_eq(world.get_node("Player/Inventory").gold, 181100)
	assert_eq(runtime.act("workshop"), "facility_limit")
	assert_eq(world.get_node("Player/Inventory").gold, 181100)
	assert_eq(runtime.act("develop"), "")
	assert_eq(world.get_node("TerritoryRestoration").level, 1)


func test_capture_restore_does_not_duplicate_claim_and_ui_owns_pause() -> void:
	var runtime: Node = world.get_node("TerritoryRuntime")
	world.get_node("Player").position = runtime.DESK
	Model.advance(runtime.state(), Model.DAY_MS)
	var session: Node = world.get_node("SaveSession")
	var saved: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id
	)
	var total := int(saved.inventory.gold) + int(saved.progress.territory.treasury)
	assert_eq(runtime.act("collect"), "")
	assert_eq(world.get_node("Player/Inventory").gold + runtime.state().treasury, total)
	# 저장 사본을 복원했을 때의 금고+보유액은 수령 이전 총액 그대로다.
	assert_eq(int(saved.inventory.gold) + int(saved.progress.territory.treasury), total)
	var panel: CanvasLayer = world.get_node("TerritoryPanel")
	assert_true(panel.open())
	assert_true(get_tree().paused)
	panel.close()
	assert_false(get_tree().paused)
