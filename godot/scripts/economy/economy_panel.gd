## 후보 상점/가방/착용 장비를 분리한다. 모든 변경은 EconomyRuntime.act를 통한다.
extends CanvasLayer

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
var _pending := {}
var _message := ""
var bag_rows: GridContainer
var gear_rows: GridContainer
var quantity := 1
var category := 0
var search := ""
var quantity_input: SpinBox


func setup(controller: Node) -> void:
	runtime = controller
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	arbiter = UiPauseArbiter.for_world(get_parent())
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
	var stock := VBoxContainer.new()
	stock.custom_minimum_size.x = 530
	columns.add_child(stock)
	_label(stock, "상점 상품", 28)
	var filter_row := HBoxContainer.new()
	stock.add_child(filter_row)
	var filter := OptionButton.new()
	UiStyle.apply_body_font(filter, 22)
	for caption in ["전체", "무기", "방어구", "장신구", "소모품"]:
		filter.add_item(caption)
	filter.item_selected.connect(func(index):
		category = index
		refresh())
	filter_row.add_child(filter)
	var input := LineEdit.new()
	input.placeholder_text = "물건 이름 검색"
	UiStyle.apply_body_font(input, 22)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(input)
	input.text_changed.connect(func(value):
		search = value
		refresh())
	rows = _grid(stock, 2, 530, 550)
	var possessions := VBoxContainer.new()
	possessions.custom_minimum_size.x = 600
	columns.add_child(possessions)
	_label(possessions, "착용 장비  ·  선택하면 해제", 28)
	gear_rows = GridContainer.new()
	gear_rows.columns = 2
	gear_rows.add_theme_constant_override("h_separation", 10)
	gear_rows.add_theme_constant_override("v_separation", 8)
	possessions.add_child(gear_rows)
	_label(possessions, "내 가방  ·  선택하면 장착 / 판매", 28)
	bag_rows = _grid(possessions, 3, 600, 240)
	details = _column(columns, 560)
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
	scroll.custom_minimum_size = Vector2(width, 550)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	return box


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			if panel.visible:
				close()
			else:
				open("bag")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and panel.visible:
			if not _pending.is_empty():
				_pending.clear()
				refresh()
			else:
				close()
			get_viewport().set_input_as_handled()


func close() -> void:
	_pending.clear()
	panel.hide()
	_show_hint(true)
	arbiter.release(self)


func open(view: String = "shop") -> bool:
	if not arbiter.acquire(self):
		return false
	mode = view if view != "shop" or trading() else "bag"
	selected = ""
	_pending.clear()
	_message = ""
	refresh()
	panel.show()
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


func _label(parent: Node, text: String, font_size: int = 24) -> Label:
	var label := Label.new()
	label.text = text
	UiStyle.apply_body_font(label, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _make_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.apply_action_button(button)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _switch(view: String) -> void:
	mode = view
	selected = ""
	_pending.clear()
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
	var state: Dictionary = runtime.state()
	title.text = "노베라 보급상" if trading() else "장비와 가방"
	wallet.text = "보유 골드  %s G     ·     가방  %d / 30칸     ·     Lv%d" % [state.gold, state.bag.size(), runtime.level()]
	if trading():
		for id in runtime.model.catalog.prices:
			var item: ItemData = runtime.model.items[id]
			var price: Dictionary = runtime.model.catalog.prices[id]
			if not price.offered or (category > 0 and item.item_type != category - 1):
				continue
			if not search.is_empty() and not item.item_name.contains(search):
				continue
			_card(rows, id, item, "%d G  ·  Lv%d" % [price.buy, item.level_limit], "shop", 255)
		if rows.get_child_count() == 0:
			_label(rows, "해당 상품이 없습니다.")
	else:
		_label(rows, "상인 근처에서\n물건을 사고팔 수 있습니다.")
	for slot in state.equipment:
		var id: String = state.equipment[slot]
		var item: ItemData = null if id == "" else runtime.model.items[id]
		_card(gear_rows, slot, item, SLOT_NAMES[slot], "gear", 290, true)
	for entry in state.bag:
		_card(bag_rows, entry.item_id, runtime.model.items[entry.item_id], "보유 %d개" % entry.quantity, "bag", 190)
	for index in state.overflow.size():
		_card(bag_rows, "overflow:%d" % index, runtime.model.items[state.overflow[index].item_id], "보관품 · 회수", "bag", 190)
	if state.bag.is_empty() and state.overflow.is_empty():
		var empty := _label(bag_rows, "가방이 비어 있습니다.\n구매한 물건이 여기에 표시됩니다.", 22)
		empty.custom_minimum_size.x = 580
	if selected.is_empty():
		_label(details, "물건 정보", 30)
		_label(details, "상점 상품을 선택하면 구매 수량과 총액을 확인할 수 있습니다.\n\n내 가방에서는 장착·판매, 착용 장비에서는 해제할 수 있습니다.")
	else:
		_show_details(state)
	status.text = _message if _message != "" else "선택만으로 거래되지 않습니다. 수량과 총액을 확인한 뒤 확정하세요."


func _card(parent: Node, key: String, item: ItemData, caption: String, view: String, width: float, compact: bool = false) -> void:
	var button := _make_button(parent, "", func():
		mode = view
		select_item(key))
	button.custom_minimum_size = Vector2(width, 64 if compact else 132)
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
	box.offset_right = -12
	box.offset_top = 8
	var name_label := _label(box, "빈 칸" if item == null else item.item_name, 22)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var info := _label(box, caption, 20)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.modulate = Color("e2c58b")
	if not compact and item != null:
		var kind := _label(box, ["무기", "방어구", "장신구", "회복약", "특수 무기", "재료"][item.item_type], 20)
		kind.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_details(state: Dictionary) -> void:
	if not _pending.is_empty():
		_label(details, _pending.label + "\n확정하시겠습니까?", 28)
		_make_button(details, "확정", _confirm)
		_make_button(
			details,
			"취소",
			func():
				_pending.clear()
				refresh()
		)
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
		return
	var item: ItemData = runtime.model.items[id]
	_label(details, item.item_name, 30)
	_label(details, "요구 레벨 %d  ·  %s등급" % [item.level_limit, ["C", "B", "A", "S"][item.grade]])
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
		_label(details, "합계  %d G\n거래 후 잔액  %d G" % [total, state.gold - total], 28)
		var error: String = runtime.model.trade(state.duplicate(true), id, quantity, true)
		_action("%d개 구매 · %d G" % [quantity, total], "buy", id, "", quantity, error)
		if item.equip_slot != ItemData.EquipSlot.NONE:
			_label(details, "장비는 구매 후 가방에서 장착합니다. 다른 직업의 무기도 구매할 수 있습니다.")
	elif mode == "gear":
		_action("해제 → 가방으로", "unequip", "", selected)
	else:
		for slot in state.equipment:
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
					+ ("없음" if previous == "" else runtime.model.items[previous].item_name)
				)
			)
			var value: float = (
				0 if previous == "" else runtime.model.items[previous].main_stat_value
			)
			_label(
				details,
				"%s  %.2f → %.2f" % [STAT_NAMES[item.main_stat_type], value, item.main_stat_value]
			)
			_action(SLOT_NAMES[slot] + "에 장착", "equip", id, slot, 1, error)
		if trading() and runtime.model.catalog.prices.has(id):
			_quantity_picker(state, id, false)
			var total: int = int(runtime.model.catalog.prices[id].sell) * quantity
			_label(details, "판매 합계  %d G" % total, 28)
			_action("%d개 판매 · %d G" % [quantity, total], "sell", id, "", quantity)
		else:
			_label(details, "판매하려면 노베라 보급상 가까이 가세요.")


func _action(
	label: String, kind: String, id: String, slot: String = "", count: int = 1, error: String = ""
) -> void:
	var button := _make_button(
		details,
		label,
		func():
			var item_name: String = runtime.model.items[id].item_name if id != "" else ""
			_pending = {
				"label": item_name + "\n" + label,
				"kind": kind,
				"id": id,
				"slot": slot,
				"count": count
			}
			refresh()
	)
	button.disabled = error != ""
	if error != "":
		_label(details, ERRORS.get(error, "현재 실행할 수 없습니다"))


func _confirm() -> void:
	if _pending.is_empty():
		return
	var action: Dictionary = _pending.duplicate()
	_pending.clear()
	var name_text: String = (
		runtime.model.items[action.id].item_name
		if action.id != ""
		else SLOT_NAMES.get(action.slot, "보관품")
	)
	var before: int = runtime.state().gold
	var error: String = runtime.act(action.kind, action.id, action.slot, action.count)
	if error == "":
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
		if mode == "bag" and action.kind in ["sell", "equip", "recover"]:
			selected = ""
	else:
		_message = ERRORS.get(error, "이 작업을 처리할 수 없습니다")
	refresh()


func set_quantity(value: int) -> void:
	quantity = maxi(1, value)
	_pending.clear()
	refresh()


func _quantity_picker(state: Dictionary, id: String, buy: bool) -> void:
	var limit: int = runtime.model.quantity(state.bag, id)
	if buy:
		limit = int(state.gold / runtime.model.catalog.prices[id].buy)
		if state.bag.size() >= 30 and runtime.model.quantity(state.bag, id) == 0:
			limit = 0
	quantity = clampi(quantity, 1, maxi(1, limit))
	_label(details, "수량  ·  %s %d개" % ["구매 가능" if buy else "보유", limit])
	var controls := HBoxContainer.new()
	details.add_child(controls)
	_make_button(controls, "−", set_quantity.bind(quantity - 1)).disabled = quantity <= 1
	quantity_input = SpinBox.new()
	quantity_input.min_value = 1
	quantity_input.max_value = maxi(1, limit)
	quantity_input.value = quantity
	quantity_input.custom_minimum_size = Vector2(180, 60)
	UiStyle.apply_body_font(quantity_input.get_line_edit(), 26)
	controls.add_child(quantity_input)
	quantity_input.value_changed.connect(func(value): set_quantity.call_deferred(int(value)))
	_make_button(controls, "+", set_quantity.bind(quantity + 1)).disabled = quantity >= limit
	_make_button(controls, "최대", set_quantity.bind(maxi(1, limit))).disabled = limit <= 0
