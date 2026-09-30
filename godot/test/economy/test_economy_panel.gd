extends GutTest

var world: Node
var display: Node
var economy: Node


func before_each() -> void:
	world = load("res://scripts/economy/economy_environment.gd").instantiate_world("novera_gate")
	world.set_meta("save_directory", "user://m6_candidate_panel_test")
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_process_frames(8)
	var player = world.get_node("Player")
	player.position = Vector2(184, 456)
	player.get_node("Inventory").add_gold(1000)
	display = world.get_node("EconomyPanel")
	economy = player.get_meta("economy_candidate")
	display.open()


func after_each() -> void:
	display.close()
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()
	await wait_process_frames(2)


func press(text: String) -> void:
	for button in display.panel.find_children("*", "Button", true, false):
		if button.text == text and not button.disabled:
			button.pressed.emit()
			return
	fail_test("버튼을 찾을 수 없음: " + text)


func test_purchase_selection_cancel_and_result() -> void:
	assert_eq(display.mode, "shop")
	var before: Dictionary = economy.state()
	display.select_item("POT-HP-1")
	press("1개 구매 · 300 G")
	assert_eq(economy.state(), before)
	press("취소")
	assert_eq(economy.state(), before)
	press("1개 구매 · 300 G")
	press("확정")
	assert_eq(economy.state().gold, 700)
	assert_true(display.status.text.contains("구매 완료"))
	press("가방 · 장착 / 판매")
	assert_eq(display.mode, "bag")
	assert_eq(display.rows.get_child_count(), 1)
	display.select_item("POT-HP-1")
	assert_true(display.details.get_child(2).text.contains("퀵슬롯 [5]"))


func test_equipment_and_overflow_have_separate_actions() -> void:
	press("착용 장비 · 해제")
	assert_eq(display.rows.get_child_count(), 8)
	display.select_item("weapon")
	press("해제 → 가방으로")
	press("확정")
	assert_eq(economy.state().equipment.weapon, "")
	press("가방 · 장착 / 판매")
	display.select_item(economy.state().bag[0].item_id)
	press("무기에 장착")
	press("확정")
	assert_ne(economy.state().equipment.weapon, "")
	economy.overflow = [{"item_id": "POT-HP-1", "quantity": 1}]
	display.select_item("overflow:0")
	press("가방으로 회수")
	press("확정")
	assert_true(economy.overflow.is_empty())


func test_bag_outside_shop_does_not_offer_purchase() -> void:
	display.close()
	economy.player.position = Vector2(152, 504)
	display.open("bag")
	assert_eq(display.mode, "bag")
	assert_true(display.tabs.get_child(0).disabled)
	assert_true(display.rows.get_child(0).text.contains("비어"))
