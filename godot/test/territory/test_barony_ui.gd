extends GutTest
const Product = preload("res://scripts/world/game_product.gd")
const Model = preload("res://scripts/territory/territory_model.gd")
var world: Node


func before_each() -> void:
	world = Product.instantiate_world()
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.set_meta(
		"territory_state",
		Model.initial({"MQ-03-05": {"state": "completed"}, "MQ-08-04": {"state": "completed"}})
	)
	world.get_node("Player/Inventory").gold = 1000000
	world.get_node("Player").position = Vector2(320, 488)


func after_each() -> void:
	world.free()
	BgmManager.reset()
	get_tree().paused = false
	await get_tree().process_frame


func test_remote_selection_cannot_invest_in_local_holding() -> void:
	var panel: CanvasLayer = world.get_node("TerritoryPanel")
	assert_true(panel.open())
	assert_eq(panel.selected_holding, "yeoulmok")
	panel._select_holding("jaetgol")
	assert_true(_button(panel, "시장 건설").disabled)
	assert_true("141400G" in _button(panel, "시장 건설").text)
	var before: Dictionary = world.get_meta("territory_state").duplicate(true)
	panel._act("market")
	assert_eq(world.get_meta("territory_state"), before)
	panel._select_holding("yeoulmok")
	assert_false(_button(panel, "시장 건설").disabled)
	panel._act("market")
	assert_eq(world.get_meta("territory_state").holdings.yeoulmok.facilities, ["market"])
	assert_eq(world.get_node("Player/Inventory").gold, 987400)
	panel.close()


func test_jaetgol_local_workshop_and_restore_use_jaetgol_prices() -> void:
	# 새 지역 콘텐츠와 독립적으로 현장 ID에 따른 런타임 연결을 검증한다.
	world.map_id = "jaetgol"
	var runtime: Node = world.get_node("TerritoryRuntime")
	assert_eq(runtime.onsite(), "jaetgol")
	assert_eq(runtime.act("workshop"), "")
	assert_eq(world.get_node("TerritoryWorkshop/Name").text, "잿골 공방")
	assert_eq(runtime.act("develop"), "")
	assert_eq(world.get_node("TerritoryRestoration").level, 1)
	assert_eq(world.get_node("Player/Inventory").gold, 505100)
	assert_eq(runtime.state().holdings.yeoulmok.facilities, [])
	var panel: CanvasLayer = world.get_node("TerritoryPanel")
	assert_true(panel.open())
	assert_eq(panel.selected_holding, "jaetgol")
	assert_true(_button(panel, "공방 건설").disabled)
	panel.close()


func _button(panel: CanvasLayer, prefix: String) -> Button:
	for child in panel.box.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
	return null
