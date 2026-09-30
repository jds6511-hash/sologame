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
	assert_eq(economy.state(), before)
	press("1개 구매 · 300 G")
	assert_eq(economy.state().gold, 700)
	assert_true(display.status.text.contains("구매 완료"))
	display._switch("bag")
	assert_eq(display.mode, "bag")
	assert_eq(display.bag_rows.get_child_count(), 30)
	display.select_item("POT-HP-1")
	assert_true(display.details.get_child(2).text.contains("퀵슬롯 [5]"))


func test_equipment_and_overflow_have_separate_actions() -> void:
	display._switch("gear")
	assert_eq(display.gear_rows.find_children("*", "Button", false, false).size(), 8)
	display.select_item("weapon")
	press("해제 → 가방으로")
	assert_eq(economy.state().equipment.weapon, "")
	display._switch("bag")
	display.select_item(economy.state().bag[0].item_id)
	press("무기에 장착")
	assert_ne(economy.state().equipment.weapon, "")
	economy.overflow = [{"item_id": "POT-HP-1", "quantity": 1}]
	display.select_item("overflow:0")
	press("가방으로 회수")
	assert_true(economy.overflow.is_empty())


func test_equipment_ignores_recharge_while_save_remains_blocked() -> void:
	var player = economy.player
	player._dash_recharge_timers.append(10.0)
	var before: Dictionary = economy.state()
	assert_true(get_tree().paused)
	assert_ne(player.save_block_reason(), "")
	display._switch("gear")
	display.select_item("weapon")
	press("해제 → 가방으로")
	assert_eq(economy.state().equipment.weapon, "")
	display._switch("bag")
	display.select_item(before.equipment.weapon)
	press("무기에 장착")
	assert_eq(economy.state(), before)
	assert_ne(player.save_block_reason(), "")
	assert_eq(player._dash_recharge_timers[0], 10.0)


func test_equipment_rejects_death_and_input_lock_without_mutation() -> void:
	var before: Dictionary = economy.state()
	economy.player.is_input_locked = true
	assert_eq(economy.act("unequip", "", "weapon"), "player_unavailable")
	assert_eq(economy.state(), before)
	economy.player.is_input_locked = false
	economy.player.get_node("PlayerStats").current_hp = 0
	assert_eq(economy.act("unequip", "", "weapon"), "player_unavailable")
	assert_eq(economy.state(), before)


func test_candidate_hint_does_not_cover_escape_menu() -> void:
	display.close()
	var hints: Array = []
	for child in display.get_children():
		if child is Label:
			hints.append(child)
	assert_eq(hints.size(), 1)
	assert_true(hints[0].visible)
	var menu = world.get_node("IntegratedMenu")
	menu.open_settings()
	assert_true(menu.is_open())
	assert_false(hints[0].visible)
	menu._on_tab_shortcut(IntegratedMenu.Tab.CHARACTER)
	assert_false(hints[0].visible)
	menu.close_menu()
	assert_true(hints[0].visible)
	assert_false(get_tree().paused)


func test_bag_outside_shop_does_not_offer_purchase() -> void:
	display.close()
	economy.player.position = Vector2(152, 504)
	display.open("bag")
	assert_eq(display.mode, "bag")
	assert_false(display.rows.get_parent().visible)
	assert_true(display.bag_rows.get_child(0).text.contains("비어"))


func test_quantity_purchase_cancel_sell_and_affordability() -> void:
	display.select_item("POT-HP-1")
	display.set_quantity(3)
	assert_eq(economy.state().gold, 1000)
	assert_eq(economy.model.quantity(economy.state().bag, "POT-HP-1"), 0)
	press("3개 구매 · 900 G")
	assert_eq(economy.state().gold, 100)
	assert_eq(economy.model.quantity(economy.state().bag, "POT-HP-1"), 3)
	assert_eq(display.quantity, 0)
	display._switch("sell")
	display.select_item("POT-HP-1")
	display.set_quantity(2)
	var price: int = economy.model.catalog.prices["POT-HP-1"].sell
	press("2개 판매 · %d G" % (price * 2))
	assert_eq(economy.state().gold, 100)
	press("취소")
	assert_eq(economy.model.quantity(economy.state().bag, "POT-HP-1"), 3)
	press("2개 판매 · %d G" % (price * 2))
	press("2개 판매")
	assert_eq(economy.state().gold, 100 + price * 2)
	assert_eq(economy.model.quantity(economy.state().bag, "POT-HP-1"), 1)


func test_npc_names_have_korean_font() -> void:
	for npc in world.find_children("*", "Node2D", true, false):
		if npc.has_method("style_name") and npc.has_node("Name"):
			var label: Label = npc.get_node("Name")
			assert_true(label.has_theme_font_override("font"))
			assert_true(label.get_theme_font("font").has_char("가".unicode_at(0)))
			assert_true(label.get_theme_font("font").multichannel_signed_distance_field)
			assert_eq(label.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)


func test_trade_during_recharge_and_duplicate_purchase_guard() -> void:
	economy.player._dash_recharge_timers.append(10.0)
	display.select_item("POT-HP-1")
	press("1개 구매 · 300 G")
	press("1개 구매 · 300 G")
	assert_eq(economy.state().gold, 700)
	assert_eq(economy.model.quantity(economy.state().bag, "POT-HP-1"), 1)
	assert_ne(economy.player.save_block_reason(), "")
	economy.player.position = Vector2.ZERO
	var before: Dictionary = economy.state()
	assert_eq(economy.act("buy", "POT-HP-1"), "merchant_distance")
	assert_eq(economy.state(), before)


func test_pause_save_return_and_direct_save_close() -> void:
	display.close()
	var menu = world.get_node("IntegratedMenu")
	var save = world.get_node("SaveMenu")
	menu.open_settings()
	menu._open_save()
	assert_true(save.panel.visible)
	assert_false(menu.is_open())
	assert_true(get_tree().paused)
	save.close_menu()
	assert_true(menu.is_open())
	assert_eq(menu.screen, "pause")
	assert_true(get_tree().paused)
	menu.close_menu()
	save.open_menu()
	save.close_menu()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)


func test_character_equipment_and_bag_share_pause_owner() -> void:
	display.close()
	var menu = world.get_node("IntegratedMenu")
	menu._on_tab_shortcut(IntegratedMenu.Tab.CHARACTER)
	menu._open_equipment()
	assert_true(display.panel.visible)
	assert_eq(display.mode, "gear")
	assert_false(menu.is_open())
	assert_true(get_tree().paused)
	display.close()
	menu._on_tab_shortcut(IntegratedMenu.Tab.INVENTORY)
	assert_eq(display.mode, "bag")
	assert_true(display.panel.visible)
	assert_false(menu.is_open())
	assert_true(get_tree().paused)


func test_shop_bag_and_equipment_actions_are_separate() -> void:
	assert_true(display.rows.get_parent().visible)
	assert_false(display.bag_rows.get_parent().visible)
	assert_false(display.gear_rows.visible)
	display._switch("bag")
	assert_false(display.rows.get_parent().visible)
	assert_true(display.bag_rows.get_parent().visible)
	assert_false(display.gear_rows.visible)
	press("장비 보기")
	assert_true(display.gear_rows.visible)
	assert_false(display.bag_rows.get_parent().visible)
	press("가방으로")
	assert_eq(display.mode, "bag")
	display._switch("shop")
	display.select_item("WPN-SW-01-C")
	for button in display.details.find_children("*", "Button", true, false):
		assert_false(button.text.contains("장착"))
	display._switch("sell")
	assert_true(display.bag_rows.get_child(0).text.contains("판매할 물건"))


func test_equipment_slot_replacement_uses_selected_ring_only() -> void:
	var previous: String = economy.state().equipment.ring_1
	world.get_node("Hud/DebugLevelKeys").grant_levels(9)
	economy.player.get_node("Inventory").add_gold(5000)
	var id: String = economy.model.catalog.supply["10"]["ACC-RING"]
	assert_eq(economy.act("buy", id), "")
	display._switch("gear")
	display.select_item("ring_2")
	press("기본 반지 · Lv10")
	assert_eq(display.mode, "equip_choice")
	assert_eq(display.gear_target, "ring_2")
	press("반지 2에 장착")
	assert_eq(economy.state().equipment.ring_1, previous)
	assert_eq(economy.state().equipment.ring_2, id)
	assert_eq(economy.model.quantity(economy.state().bag, id), 0)
	assert_eq(economy.model.quantity(economy.state().bag, previous), 1)
