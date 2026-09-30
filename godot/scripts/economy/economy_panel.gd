## M6 후보 통합 가방/거래창. B로 가방, 노베라 상인 근처에서 구매/판매 허용.
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
	"combat": "행동이 끝난 뒤 교체하세요",
	"merchant_distance": "보급상에게 가까이 가세요",
	"gold": "골드가 부족합니다",
	"gold_limit": "골드 한도를 초과합니다",
	"bag_full": "가방 공간이나 수량 한도가 부족합니다",
	"quantity": "보유 수량이 부족합니다",
	"level": "착용 레벨이 부족합니다",
	"weapon_family": "현재 직업이 사용하는 무기가 아닙니다",
	"not_tradable": "이 상인이 취급하지 않는 물품입니다",
	"economy_content_error": "경제 데이터 오류로 중단했습니다"
}
var runtime: Node
var panel: PanelContainer
var rows: VBoxContainer
var status: Label
var arbiter: UiPauseArbiter


func setup(controller: Node) -> void:
	runtime = controller
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	arbiter = UiPauseArbiter.for_world(get_parent())
	panel = PanelContainer.new()
	panel.position = Vector2(600, 100)
	panel.size = Vector2(680, 640)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("202938")
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_top = 12
	background.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 640)
	panel.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	panel.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			if panel.visible:
				close()
			else:
				open()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and panel.visible:
			close()
			get_viewport().set_input_as_handled()


func close() -> void:
	panel.hide()
	arbiter.release(self)


func open() -> bool:
	if not arbiter.acquire(self):
		return false
	refresh()
	panel.show()
	return true


func trading() -> bool:
	return (
		get_parent().map_id == "novera_gate"
		and runtime.player.position.distance_to(Vector2(216, 440)) <= 40
	)


func _label(text: String) -> void:
	var label := Label.new()
	label.text = text
	rows.add_child(label)


func _button(
	text: String, action: String, id: String = "", slot: String = "", count: int = 1
) -> void:
	var button := Button.new()
	button.text = text
	rows.add_child(button)
	button.pressed.connect(
		func():
			for child in rows.get_children():
				rows.remove_child(child)
				child.queue_free()
			_label(text + " — 확정하시겠습니까?")
			var confirm := Button.new()
			confirm.text = "확정"
			rows.add_child(confirm)
			confirm.pressed.connect(
				func():
					var error: String = runtime.act(action, id, slot, count)
					refresh()
					status.text = "완료" if error == "" else ERRORS.get(error, "이 작업을 처리할 수 없습니다")
			)
			var cancel := Button.new()
			cancel.text = "취소"
			rows.add_child(cancel)
			cancel.pressed.connect(refresh)
	)


func refresh() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var state: Dictionary = runtime.state()
	_label("가방 · 골드 %d · %d/30칸 · B/Esc 닫기" % [state.gold, state.bag.size()])
	status = Label.new()
	rows.add_child(status)
	_label("장비 — 해제는 가방에 공간이 있을 때 가능합니다")
	for slot in state.equipment:
		var id: String = state.equipment[slot]
		_button(
			(
				SLOT_NAMES[slot]
				+ ": "
				+ ("비어 있음" if id == "" else runtime.model.items[id].item_name)
				+ " / 해제"
			),
			"unequip",
			"",
			slot
		)
	_label("소지품 — 각 버튼은 1개 단위입니다")
	for entry in state.bag:
		var item: ItemData = runtime.model.items[entry.item_id]
		_label(
			(
				"%s ×%d · 요구 Lv%d · 옵션 %.2f"
				% [item.item_name, entry.quantity, item.level_limit, item.main_stat_value]
			)
		)
		for slot in state.equipment:
			if runtime.model.registry.slots[slot] == item.equip_slot:
				var current: String = state.equipment[slot]
				var value: float = (
					0 if current == "" else runtime.model.items[current].main_stat_value
				)
				_button(
					"%s 교체: %.2f → %.2f" % [SLOT_NAMES[slot], value, item.main_stat_value],
					"equip",
					item.item_id,
					slot
				)
		if trading() and runtime.model.catalog.prices.has(item.item_id):
			_button(
				"판매 %d골드" % runtime.model.catalog.prices[item.item_id].sell, "sell", item.item_id
			)
	for index in range(state.overflow.size()):
		_button(
			"이관 보관품 회수: " + runtime.model.items[state.overflow[index].item_id].item_name,
			"recover",
			"",
			"",
			index
		)
	if trading():
		_label("보급상 — 구매")
		for id in runtime.model.catalog.prices:
			var price: Dictionary = runtime.model.catalog.prices[id]
			if price.offered:
				_button("%s 구매 %d골드" % [runtime.model.items[id].item_name, price.buy], "buy", id)
	else:
		_label("노베라 보급상 가까이에서 구매·판매할 수 있습니다.")
