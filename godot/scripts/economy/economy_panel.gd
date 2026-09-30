## 후보 상점/가방/착용 장비를 분리한다. 모든 변경은 EconomyRuntime.act를 통한다.
extends CanvasLayer

const View = preload("res://scripts/economy/economy_presentation.gd")

const SLOT_NAMES := {
	"weapon": "무기",
	"body": "갑옷",
	"legs": "하의",
	"head": "모자",
	"feet": "신발",
	"ring_1": "반지 1",
	"ring_2": "반지 2",
	"necklace": "목걸이"
}
const ERRORS := {
	"busy": "다른 처리가 진행 중입니다",
	"combat": "창을 닫고 행동과 재사용 대기가 끝난 뒤 시도하세요",
	"player_unavailable": "사망 또는 캐릭터 전환 중에는 장비와 소지품을 변경할 수 없습니다",
	"merchant_distance": "보급상 가까이에서만 거래할 수 있습니다",
	"gold": "골드가 부족합니다",
	"gold_limit": "골드 한도를 초과합니다",
	"bag_full": "가방 공간이 부족합니다",
	"quantity": "보유 수량이 부족합니다",
	"level": "착용 레벨이 부족합니다",
	"weapon_family": "현재 직업이 사용하는 무기가 아닙니다",
	"not_tradable": "판매할 수 없는 물품입니다",
	"economy_content_error": "경제 데이터 오류로 중단했습니다"
}
const STAT_NAMES := ["옵션 없음", "공격력", "방어력", "치명타 확률", "최대 HP", "최대 MP", "공격 속도"]
var runtime: Node
var panel: PanelContainer
var rows: GridContainer
var status: Label
var arbiter: UiPauseArbiter
var mode := "bag"
var selected := ""
var details: VBoxContainer
var title: Label
var wallet: Label
var explanation: Label
var tabs: HBoxContainer
var bag_rows: GridContainer
var gear_rows: Control
var stock: VBoxContainer
var filter_row: HBoxContainer
var filter_dropdown: OptionButton
var search_input: LineEdit
var gear_target := ""
var quantity := 1
var category := 0
var search := ""
var quantity_input: SpinBox
var actions: VBoxContainer
var shade: ColorRect
var overflow_rows: VBoxContainer
var overflow_scroll: ScrollContainer
var overflow_toggle: Button
var comparison_slot := ""
var show_overflow := false
var sort_reverse := false
var _pending := {}
var _message := ""
var _last_commit_msec := -1000
var _message_left := 0.0
var _bag_memory := {}


func setup(controller: Node) -> void:
	runtime = controller
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	arbiter = UiPauseArbiter.for_world(get_parent())
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	shade.hide()
	panel = PanelContainer.new()
	panel.position = Vector2(60, 60)
	panel.size = Vector2(1800, 960)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("111d2c")
	for side in ["left", "right", "top", "bottom"]:
		background.set("content_margin_" + side, 24)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title = _label(header, "보급상과 내 소지품", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_button(header, "닫기 [Esc / B]", close)
	wallet = _label(layout, "", 26)
	tabs = HBoxContainer.new()
	layout.add_child(tabs)
	explanation = _label(layout, "상품 선택 → 수량 선택 → 구매   /   내 물건 선택 → 장착 또는 판매", 22)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	stock = VBoxContainer.new()
	stock.custom_minimum_size.x = 1100
	columns.add_child(stock)

	filter_row = HBoxContainer.new()
	stock.add_child(filter_row)
	var filter := OptionButton.new()
	filter_dropdown = filter
	UiStyle.apply_body_font(filter, 22)
	for caption in ["전체", "무기", "방어구", "장신구", "회복약", "재료"]:
		filter.add_item(caption)
	filter.item_selected.connect(
		func(index):
			category = index
			refresh()
	)
	filter_row.add_child(filter)
	var input := LineEdit.new()
	search_input = input
	input.placeholder_text = "물건 이름 검색"
	UiStyle.apply_body_font(input, 22)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(input)
	input.text_changed.connect(
		func(value):
			search = value
			refresh()
	)
	_make_button(
		filter_row,
		"정렬 ↕",
		func():
			sort_reverse = not sort_reverse
			refresh()
	)
	rows = _grid(stock, 1, 1100, 500)
	bag_rows = _grid(stock, 6, 1100, 500)
	overflow_toggle = _make_button(
		stock,
		"보관 대기",
		func():
			show_overflow = not show_overflow
			refresh()
	)
	overflow_scroll = ScrollContainer.new()
	overflow_scroll.custom_minimum_size = Vector2(1100, 132)
	overflow_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stock.add_child(overflow_scroll)
	overflow_rows = VBoxContainer.new()
	overflow_scroll.add_child(overflow_rows)
	gear_rows = Control.new()
	gear_rows.custom_minimum_size = Vector2(1100, 550)
	stock.add_child(gear_rows)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 560
	columns.add_child(right)
	details = _column(right, 560)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	right.add_child(actions)
	status = _label(layout, "", 22)
	status.custom_minimum_size.y = 54
	status.modulate = Color("fee3a2")
	panel.hide()


func _grid(parent: Node, columns: int, width: float, height: float) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, height)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	return grid


func _column(parent: Control, width: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box


func _process(delta: float) -> void:
	if _message_left > 0:
		_message_left -= delta
		if _message_left <= 0:
			_message = ""
			status.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if key == KEY_ESCAPE and panel.visible:
		if not _pending.is_empty():
			_pending.clear()
			refresh()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var menu = get_parent().get_node("IntegratedMenu")
	if key in [KEY_B, KEY_I]:
		if panel.visible:
			if mode in ["shop", "sell"]:
				return
			close()
		else:
			if menu.is_open():
				if menu.screen != "feature":
					return
				menu.close_menu()
			open("bag")
		get_viewport().set_input_as_handled()
	elif panel.visible and mode not in ["shop", "sell"]:
		var keys := {KEY_C: 1, KEY_K: 2, KEY_J: 3, KEY_M: 4}
		if keys.has(key):
			close()
			menu._on_tab_shortcut(keys[key])
			get_viewport().set_input_as_handled()


func close() -> void:
	_pending.clear()
	panel.hide()
	shade.hide()
	_show_hint(true)
	arbiter.release(self)


func open(view: String = "shop") -> bool:
	if runtime.player.is_input_locked or runtime.player.get_node("PlayerStats").is_dead():
		return false
	if not arbiter.acquire(self):
		return false
	mode = view if view not in ["shop", "sell"] or trading() else "bag"
	selected = ""
	_pending.clear()
	_message = ""
	refresh()
	panel.show()
	shade.show()
	_show_hint(false)
	return true


func _show_hint(value: bool) -> void:
	for child in get_children():
		if child is Label:
			child.visible = value


func trading() -> bool:
	return (
		get_parent().map_id == "novera_gate"
		and runtime.player.position.distance_to(Vector2(216, 440)) <= 40
	)


func _label(parent: Node, text: String, font_size: int = 27) -> Label:
	var label := Label.new()
	label.text = text
	UiStyle.apply_body_font(label, font_size)
	if font_size >= 28:
		label.add_theme_font_override("font", load(UiStyle.FONT_HEADING_PATH))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _make_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.apply_action_button(button)
	button.custom_minimum_size.y = 66
	parent.add_child(button)
	button.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.double_click:
			button.set_meta("skip_double_click", true))
	button.pressed.connect(func():
		if button.get_meta("skip_double_click", false):
			button.set_meta("skip_double_click", false)
			return
		callback.call())
	return button


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _switch(view: String) -> void:
	if mode == "bag" and view == "gear":
		_bag_memory = {
			"selected": selected,
			"category": category,
			"search": search,
			"scroll": bag_rows.get_parent().scroll_vertical
		}
	mode = view
	_message = ""
	category = 0
	search = ""
	filter_dropdown.select(0)
	search_input.set_block_signals(true)
	search_input.text = ""
	search_input.set_block_signals(false)
	gear_target = ""
	selected = ""
	_pending.clear()
	if view == "bag" and not _bag_memory.is_empty():
		selected = _bag_memory.selected
		category = _bag_memory.category
		search = _bag_memory.search
		filter_dropdown.select(category)
		search_input.set_block_signals(true)
		search_input.text = search
		search_input.set_block_signals(false)
		bag_rows.get_parent().set_deferred("scroll_vertical", _bag_memory.scroll)
	refresh()


func select_item(key: String) -> void:
	selected = key
	quantity = 1
	_pending.clear()
	refresh()
	_reveal_selected.call_deferred(key)


func _reveal_selected(key: String) -> void:
	if selected != key:
		return
	for button in rows.get_children():
		if button.get_meta("item_key", "") == key:
			rows.get_parent().ensure_control_visible(button)


func refresh() -> void:
	_clear(rows)
	_clear(bag_rows)
	_clear(gear_rows)
	_clear(details)
	_clear(actions)
	_clear(overflow_rows)
	_clear(tabs)
	var state: Dictionary = runtime.state()
	var in_shop := mode in ["shop", "sell"]
	var equipment := mode in ["gear", "equip_choice"]
	title.text = "노베라 보급상" if in_shop else ("착용 장비" if equipment else "내 가방")
	wallet.text = (
		"보유 골드  %s G   ·   가방 %d / 30칸   ·   Lv%d" % [state.gold, state.bag.size(), runtime.level()]
	)
	if in_shop:
		for view in ["shop", "sell"]:
			var tab := _make_button(tabs, "구매" if view == "shop" else "판매", _switch.bind(view))
			if mode == view:
				var active := StyleBoxFlat.new()
				active.bg_color = Color("34465d")
				active.border_color = Color("f9cf75")
				active.border_width_bottom = 4
				active.content_margin_left = 24
				active.content_margin_right = 24
				active.content_margin_top = 12
				active.content_margin_bottom = 12
				tab.add_theme_stylebox_override("normal", active)
	else:
		_make_button(
			tabs, "가방으로" if equipment else "장비 보기", _switch.bind("bag" if equipment else "gear")
		)
	explanation.text = {
		"shop": "상인이 파는 상품입니다. 수량과 총액을 확인해 구매하세요. 구매한 물건은 가방으로 들어갑니다.",
		"sell": "내 가방의 판매 가능한 물건입니다. 착용 중인 장비는 여기에 나오지 않습니다.",
		"bag": "내가 가진 물건입니다. 장비를 선택하면 장착할 수 있습니다. 거래는 상인에게 말을 걸어 진행하세요.",
		"gear": "장비 칸을 선택하면 해제하거나 같은 부위의 가방 장비로 교체할 수 있습니다.",
		"equip_choice": "선택한 부위에 교체할 장비의 능력치와 착용 조건을 확인하세요."
	}[mode]
	rows.get_parent().visible = mode == "shop"
	bag_rows.get_parent().visible = mode in ["bag", "sell"]
	gear_rows.visible = equipment
	filter_row.visible = not equipment
	bag_rows.columns = 1 if mode == "sell" else 6
	overflow_toggle.visible = mode == "bag" and not state.overflow.is_empty()
	overflow_toggle.text = (
		"보관 대기 %d건 %s" % [state.overflow.size(), "접기" if show_overflow else "펼치기"]
	)
	overflow_scroll.visible = overflow_toggle.visible and show_overflow
	var item_ids: Array = runtime.model.items.keys()
	item_ids.sort_custom(
		func(a, b):
			var x: ItemData = runtime.model.items[a]
			var y: ItemData = runtime.model.items[b]
			var rx := _rank(x)
			var ry := _rank(y)
			var left := "%02d:%03d:%s:%s" % [rx, x.level_limit, x.item_name, a]
			var right := "%02d:%03d:%s:%s" % [ry, y.level_limit, y.item_name, b]
			return left > right if sort_reverse else left < right
	)
	if mode == "shop" and trading():
		for id in item_ids:
			if not runtime.model.catalog.prices.has(id):
				continue
			var item: ItemData = runtime.model.items[id]
			var price: Dictionary = runtime.model.catalog.prices[id]
			if price.offered and _matches(item):
				_card(rows, id, item, "%d G  ·  Lv%d" % [price.buy, item.level_limit], "shop", 1080)
		if rows.get_child_count() == 0:
			_empty(rows, "조건에 맞는 상품이 없습니다.")
	elif equipment:
		_equipment_view(state)
	else:
		for item_id in item_ids:
			var amount: int = runtime.model.quantity(state.bag, item_id)
			if amount == 0:
				continue
			var entry := {"item_id": item_id, "quantity": amount}
			var item: ItemData = runtime.model.items[entry.item_id]
			if not _matches(item):
				continue
			if (
				mode == "sell"
				and (
					not runtime.model.catalog.prices.has(entry.item_id)
					or runtime.model.catalog.prices[entry.item_id].sell < 0
				)
			):
				continue
			_card(
				bag_rows,
				entry.item_id,
				item,
				"보유 %d개" % entry.quantity,
				mode,
				1080 if mode == "sell" else 172
			)
		if mode == "bag":
			for index in state.overflow.size():
				_card(
					overflow_rows,
					"overflow:%d" % index,
					runtime.model.items[state.overflow[index].item_id],
					"보관품 · 회수",
					"bag",
					1080
				)
		if bag_rows.get_child_count() == 0:
			if mode == "sell":
				_empty(bag_rows, "판매할 물건이 없습니다.")
			else:
				explanation.text = "가방이 비어 있거나 검색 조건에 맞는 물건이 없습니다."
	if mode in ["bag", "sell"] and not selected.begins_with("overflow:"):
		if (
			not runtime.model.items.has(selected)
			or runtime.model.quantity(state.bag, selected) == 0
			or not _matches(runtime.model.items[selected])
		):
			selected = ""
	if mode == "shop" and runtime.model.items.has(selected):
		if not _matches(runtime.model.items[selected]):
			selected = ""
	if mode == "bag":
		for _index in range(bag_rows.get_child_count(), 30):
			var empty := Panel.new()
			empty.custom_minimum_size = Vector2(172, 104)
			bag_rows.add_child(empty)
	if selected.is_empty():
		_label(details, "물건 정보", 30)
		_label(details, "← 목록에서 물건을 선택하세요." if not equipment else "← 교체할 장비 칸을 선택하세요.")
	else:
		_show_details(state)
	status.text = _message


func _rank(item: ItemData) -> int:
	if item.item_type == ItemData.ItemType.POTION:
		return 0
	for slot in runtime.model.registry.slots:
		if runtime.model.equip_error(item.item_id, slot, runtime.level(), runtime.job_id()) == "":
			return 1
	return 2 + item.item_type


func _matches(item: ItemData) -> bool:
	return (
		(category == 0 or item.item_type == [0, 0, 1, 2, 3, 5][category])
		and (search.is_empty() or item.item_name.contains(search))
	)


func _empty(parent: Node, message: String) -> void:
	_label(parent, message, 24).custom_minimum_size.x = 1000


func _equipment_view(state: Dictionary) -> void:
	var slots := ["head", "weapon", "body", "legs", "necklace", "ring_1", "ring_2", "feet"]
	for index in slots.size():
		var slot: String = slots[index]
		var id: String = state.equipment[slot]
		var item: ItemData = null if id == "" else runtime.model.items[id]
		var card := _card(gear_rows, slot, item, SLOT_NAMES[slot], "gear", 310, true)
		card.position = Vector2(20 if index < 4 else 750, 24 + (index % 4) * 112)
		card.size.y = 92
	var portrait := TextureRect.new()
	var sprite := runtime.player.get_node("Sprite") as AnimatedSprite2D
	if sprite != null:
		portrait.texture = sprite.sprite_frames.get_frame_texture("idle_front", 0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.position = Vector2(410, 40)
	portrait.size = Vector2(230, 240)
	gear_rows.add_child(portrait)
	var stats = runtime.player.get_node("PlayerStats").stats
	var summary := _label(
		gear_rows,
		(
			"현재 적용 능력치\n공격력 %.1f\n방어력 %.1f\n최대 HP %.0f  /  MP %.0f"
			% [stats.attack_power, stats.defense, stats.max_hp, stats.max_mp]
		),
		24
	)
	summary.position = Vector2(375, 300)
	summary.size = Vector2(350, 180)


func _card(
	parent: Node,
	key: String,
	item: ItemData,
	caption: String,
	view: String,
	width: float,
	compact: bool = false
) -> Button:
	var button := _make_button(
		parent,
		"",
		func():
			mode = view
			select_item(key)
	)
	button.custom_minimum_size = Vector2(width, 104 if view == "bag" else (92 if compact else 116))
	button.set_meta("item_key", key)
	button.tooltip_text = caption + ("" if item == null else " · " + item.item_name)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("294758") if mode == view and selected == key else Color("203044")
	style.border_color = Color("dfbd79") if mode == view and selected == key else Color("40556b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	if item != null and not compact:
		var texture := View.icon(item)
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		icon.position = Vector2(8, 12)
		icon.size = Vector2(52, 52)
		if view == "bag":
			icon.position = Vector2(70, 4)
			icon.size = Vector2(32, 32)
		if texture == null:
			var badge := _label(button, View.KINDS[item.item_type].left(1), 30)
			badge.position = Vector2(14, 14)
			badge.size = Vector2(52, 40)
			badge.autowrap_mode = TextServer.AUTOWRAP_OFF
			if view == "bag":
				badge.position = Vector2(70, 4)
				UiStyle.apply_body_font(badge, 26)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.offset_left = 64 if view in ["shop", "sell"] else 12
		if view == "bag":
			box.offset_top = 62
	box.offset_right = -12
	box.offset_top = 8 if view != "bag" else 40
	var name_label := _label(box, "빈 칸" if item == null else View.item_name(item), 27)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var info := _label(box, caption, 24)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.modulate = Color("e2c58b")
	if not compact and item != null and view in ["shop", "sell"]:
		var kind := _label(box, View.effect(item) + " · " + View.condition(item), 24)
		kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return button


func _show_details(state: Dictionary) -> void:
	if not _pending.is_empty():
		_label(details, _pending.label + "\n판매하시겠습니까?", 28)
		_make_button(actions, "%d개 판매" % _pending.count, _confirm)
		var cancel := _make_button(actions, "취소", _cancel_sale)
		cancel.grab_focus()
		return
	if selected.begins_with("overflow:"):
		var index := int(selected.get_slice(":", 1))
		if index < state.overflow.size():
			_label(details, "이전 저장에서 옮긴 보관품입니다. 가방에 공간이 있어야 회수할 수 있습니다.")
			_action("가방으로 회수", "recover", "", "", index)
		return
	var id: String = state.equipment.get(selected, "") if mode == "gear" else selected
	if id == "" or not runtime.model.items.has(id):
		_label(details, "이 칸에는 장비가 없습니다.")
		if mode == "gear":
			_replacements(state, selected)
		return
	var item: ItemData = runtime.model.items[id]
	_label(details, View.item_name(item), 32)
	_label(details, View.condition(item))
	if item.heal_amount > 0:
		_label(details, "HP %d 회복 · 창을 닫고 퀵슬롯 [5]로 사용" % item.heal_amount)
	elif item.main_stat_type != ItemData.MainStatType.NONE:
		var unit := "%" if item.main_stat_type in [3, 4, 6] else ""
		_label(
			details, "%s +%.2f%s" % [STAT_NAMES[item.main_stat_type], item.main_stat_value, unit]
		)
	if mode == "shop":
		var price: Dictionary = runtime.model.catalog.prices[id]
		_quantity_picker(state, id, true)
		var total: int = int(price.buy) * quantity
		_label(actions, "합계  %d G\n구매 후 잔액  %d G" % [total, state.gold - total], 28)
		var error: String = runtime.model.trade(state.duplicate(true), id, quantity, true)
		if quantity == 0:
			error = "gold" if state.gold < price.buy else "bag_full"
		_action("%d개 구매 · %d G" % [quantity, total], "buy", id, "", quantity, error)
		if item.equip_slot != ItemData.EquipSlot.NONE:
			_label(details, "장비는 구매 후 가방에서 장착합니다. 다른 직업의 무기도 구매할 수 있습니다.")
			var available: Array = []
			for slot in state.equipment:
				if runtime.model.registry.slots[slot] == item.equip_slot:
					available.append(slot)
			if comparison_slot not in available:
				comparison_slot = available[0]
			if available.size() > 1:
				for slot in available:
					_make_button(
						details,
						SLOT_NAMES[slot] + " 비교",
						func():
							comparison_slot = slot
							refresh()
					)
			_label(details, View.comparison(runtime, id, comparison_slot))
	elif mode == "sell":
		_quantity_picker(state, id, false)
		var total: int = int(runtime.model.catalog.prices[id].sell) * quantity
		_label(actions, "받을 골드  %d G" % total, 28)
		_action("%d개 판매 · %d G" % [quantity, total], "sell", id, "", quantity)
	elif mode == "gear":
		_action("해제 → 가방으로", "unequip", "", selected)
		_replacements(state, selected)
	else:
		for slot in state.equipment:
			if mode == "equip_choice" and slot != gear_target:
				continue
			if runtime.model.registry.slots[slot] != item.equip_slot:
				continue
			var error: String = runtime.model.equip_error(
				id, slot, runtime.level(), runtime.job_id()
			)
			var previous: String = state.equipment[slot]
			_label(
				details,
				(
					SLOT_NAMES[slot]
					+ " 현재: "
					+ ("없음" if previous == "" else View.item_name(runtime.model.items[previous]))
				)
			)
			_label(details, View.comparison(runtime, id, slot))
			_action(SLOT_NAMES[slot] + "에 장착", "equip", id, slot, 1, error)
		if item.equip_slot == ItemData.EquipSlot.NONE and item.heal_amount <= 0:
			_label(details, "사냥과 제작에 쓰이는 보유 재료입니다. 판매는 상점에서 할 수 있습니다.")
		if mode == "equip_choice":
			_replacements(state, gear_target)


func _cancel_sale() -> void:
	_pending.clear()
	refresh()


func _replacements(state: Dictionary, slot: String) -> void:
	_label(details, "가방에서 교체할 장비", 26)
	var count := 0
	for entry in state.bag:
		var item: ItemData = runtime.model.items[entry.item_id]
		if runtime.model.registry.slots[slot] != item.equip_slot:
			continue
		count += 1
		_make_button(
			details,
			View.item_name(item) + " · Lv%d" % item.level_limit,
			func():
				gear_target = slot
				mode = "equip_choice"
				select_item(entry.item_id)
		)
	if count == 0:
		_label(details, "가방에 이 부위의 장비가 없습니다.")


func _action(
	label: String, kind: String, id: String, slot: String = "", count: int = 1, error: String = ""
) -> void:
	var button := _make_button(
		actions,
		label,
		func():
			var item_name: String = View.item_name(runtime.model.items[id]) if id != "" else ""
			_pending = {
				"label": item_name + "\n" + label,
				"kind": kind,
				"id": id,
				"slot": slot,
				"count": count
			}
			if kind == "sell":
				refresh()
			else:
				_confirm()
	)
	button.disabled = error != ""
	if error == "":
		var primary := StyleBoxFlat.new()
		primary.bg_color = Color("b8924b")
		primary.content_margin_top = 14
		primary.content_margin_bottom = 14
		button.add_theme_stylebox_override("normal", primary)
		button.add_theme_color_override("font_color", Color("101b28"))
	if error != "":
		var reason: String = ERRORS.get(error, "현재 실행할 수 없습니다")
		if error == "gold" and runtime.model.catalog.prices.has(id):
			reason = (
				"%d G 부족합니다"
				% (runtime.model.catalog.prices[id].buy * maxi(1, count) - runtime.state().gold)
			)
		elif error == "bag_full":
			reason = "물건을 넣을 가방 공간이 부족합니다. 판매하거나 칸을 비워 주세요."
		_label(actions, reason)


func _confirm() -> void:
	if _pending.is_empty():
		return
	if _pending.kind == "buy" and Time.get_ticks_msec() - _last_commit_msec < 300:
		_pending.clear()
		return
	if _pending.kind == "buy":
		_last_commit_msec = Time.get_ticks_msec()
	var action: Dictionary = _pending.duplicate()
	_pending.clear()
	var name_text: String = (
		View.item_name(runtime.model.items[action.id])
		if action.id != ""
		else SLOT_NAMES.get(action.slot, "보관품")
	)
	var before: int = runtime.state().gold
	var error: String = runtime.act(action.kind, action.id, action.slot, action.count)
	if error == "":
		quantity = 1
		_message_left = 3.0
		_message = (
			"%s · %s 완료     |     골드 %d → %d G"
			% [
				name_text,
				{"buy": "구매", "sell": "판매", "equip": "장착", "unequip": "해제", "recover": "회수"}[
					action.kind
				],
				before,
				runtime.state().gold
			]
		)
		if mode in ["bag", "sell", "equip_choice"] and action.kind in ["sell", "equip", "recover"]:
			selected = ""
	else:
		_message_left = 0.0
		_message = ERRORS.get(error, "이 작업을 처리할 수 없습니다")
	if mode == "equip_choice" and error == "":
		mode = "gear"
		selected = gear_target
	get_parent().get_node("IntegratedMenu")._refresh_character_tab()
	refresh()


func set_quantity(value: int) -> void:
	quantity = maxi(0, value)
	_pending.clear()
	refresh()


func _quantity_picker(state: Dictionary, id: String, buy: bool) -> void:
	var limit: int = runtime.model.quantity(state.bag, id)
	if buy:
		limit = mini(
			int(state.gold / runtime.model.catalog.prices[id].buy),
			runtime.model.LIMIT - runtime.model.quantity(state.bag, id)
		)
		if state.bag.size() >= 30 and runtime.model.quantity(state.bag, id) == 0:
			limit = 0
	quantity = clampi(quantity, 1 if limit > 0 else 0, limit)
	_label(actions, "수량  ·  %s %d개" % ["구매 가능" if buy else "보유", limit])
	var controls := HBoxContainer.new()
	actions.add_child(controls)
	_make_button(controls, "−", set_quantity.bind(quantity - 1)).disabled = quantity <= 1
	quantity_input = SpinBox.new()
	quantity_input.min_value = 1 if limit > 0 else 0
	quantity_input.max_value = limit
	quantity_input.value = quantity
	quantity_input.custom_minimum_size = Vector2(180, 60)
	UiStyle.apply_body_font(quantity_input.get_line_edit(), 26)
	controls.add_child(quantity_input)
	quantity_input.value_changed.connect(func(value): set_quantity.call_deferred(int(value)))
	_make_button(controls, "+", set_quantity.bind(quantity + 1)).disabled = quantity >= limit
	_make_button(controls, "최대", set_quantity.bind(maxi(1, limit))).disabled = limit <= 0
