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
var rows: VBoxContainer
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


func setup(controller: Node) -> void:
	runtime = controller
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	arbiter = UiPauseArbiter.for_world(get_parent())
	panel = PanelContainer.new()
	panel.position = Vector2(180, 90)
	panel.size = Vector2(1560, 890)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("172333")
	for side in ["left", "right", "top", "bottom"]:
		background.set("content_margin_" + side, 28)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)
	title = _label(layout, "", 34)
	wallet = _label(layout, "", 26)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	layout.add_child(tabs)
	explanation = _label(layout, "", 24)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 32)
	layout.add_child(columns)
	rows = _column(columns, 660)
	details = _column(columns, 800)
	status = _label(layout, "물건을 선택하면 설명과 가능한 행동이 나타납니다.", 24)
	status.custom_minimum_size.y = 58
	status.modulate = Color("fee3a2")
	_make_button(layout, "닫기 [Esc / B]", close)
	panel.hide()


func _column(parent: Control, width: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, 480)
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
	_clear(details)
	_clear(tabs)
	var state: Dictionary = runtime.state()
	title.text = {"shop": "노베라 보급상 · 물건 사기", "bag": "내 가방 · 보유 물건", "gear": "착용 중인 장비"}[mode]
	wallet.text = (
		"내 골드  %s G     |     가방  %d / 30칸     |     Lv%d"
		% [state.gold, state.bag.size(), runtime.level()]
	)
	for view in ["shop", "bag", "gear"]:
		var text: String = {"shop": "상점 · 구매", "bag": "가방 · 장착 / 판매", "gear": "착용 장비 · 해제"}[view]
		var button := _make_button(tabs, text, _switch.bind(view))
		button.disabled = view == mode or (view == "shop" and not trading())
	explanation.text = {
		"shop": "상인이 파는 물건입니다. 왼쪽 상품을 선택하고 오른쪽에서 구매하세요. 구매한 물건은 가방에 들어갑니다.",
		"bag": "내가 가진 물건입니다. 선택하면 장착하거나 상인에게 팔 수 있습니다. 장착한 물건은 착용 장비 탭에 있습니다.",
		"gear": "현재 몸에 착용한 장비입니다. 선택해 해제하면 가방으로 돌아갑니다."
	}[mode]
	if mode == "shop":
		for id in runtime.model.catalog.prices:
			var price: Dictionary = runtime.model.catalog.prices[id]
			if price.offered:
				var item: ItemData = runtime.model.items[id]
				_entry(id, "%s\nLv%d · %d G" % [item.item_name, item.level_limit, price.buy])
	elif mode == "gear":
		for slot in state.equipment:
			var id: String = state.equipment[slot]
			_entry(
				slot,
				(
					SLOT_NAMES[slot]
					+ "  ·  "
					+ ("비어 있음" if id == "" else runtime.model.items[id].item_name)
				)
			)
	else:
		for entry in state.bag:
			_entry(
				entry.item_id,
				"%s  ×%d" % [runtime.model.items[entry.item_id].item_name, entry.quantity]
			)
		for index in state.overflow.size():
			_entry(
				"overflow:%d" % index,
				"보관품 회수 · " + runtime.model.items[state.overflow[index].item_id].item_name
			)
		if rows.get_child_count() == 0:
			_label(rows, "가방이 비어 있습니다.\n상점에서 물건을 사거나 사냥으로 얻어 보세요.")
	if selected.is_empty():
		_label(details, "← 왼쪽에서 물건을 선택하세요", 28)
	else:
		_show_details(state)
	status.text = _message if _message != "" else "구매·판매는 1개씩 처리합니다. 확정 전에는 골드와 물건이 바뀌지 않습니다."


func _entry(key: String, text: String) -> void:
	var button := _make_button(
		rows, ("▶ " if selected == key else "") + text, select_item.bind(key)
	)
	button.set_meta("item_key", key)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT


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
		_label(details, "구매 가격  %d G\n구매 후 골드  %d G" % [price.buy, state.gold - price.buy])
		var error: String = runtime.model.trade(state.duplicate(true), id, 1, true)
		_action("1개 구매 · %d G" % price.buy, "buy", id, "", 1, error)
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
			_action("1개 판매 · %d G" % runtime.model.catalog.prices[id].sell, "sell", id)
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
