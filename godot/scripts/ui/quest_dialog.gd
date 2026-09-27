class_name QuestDialog
extends CanvasLayer

var controller: QuestController
var panel: PanelContainer
var _box: VBoxContainer
var _message: Label
var _npc_id := ""
var _arbiter: UiPauseArbiter


func setup(quests: QuestController) -> void:
	controller = quests
	_arbiter = UiPauseArbiter.for_world(get_parent())
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 31
	panel = PanelContainer.new()
	panel.position = Vector2(440, 300)
	panel.custom_minimum_size = Vector2(1040, 400)
	panel.add_theme_stylebox_override("panel", UiStyle.make_panel_stylebox())
	var theme := Theme.new()
	theme.default_font = load(UiStyle.FONT_BODY_PATH)
	theme.default_font_size = 26
	panel.theme = theme
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 20)
	margin.add_child(_box)
	panel.hide()


func open_dialog(npc_id: String) -> bool:
	if panel.visible or not _arbiter.acquire(self):
		return false
	_npc_id = npc_id
	controller.journal.record_event("TALK", npc_id, "", 0)
	_refresh()
	panel.show()
	return true


func close_dialog() -> void:
	panel.hide()
	_arbiter.release(self)


func choose(action: String) -> void:
	if not panel.visible:
		return
	var error := ""
	match action:
		"report_first":
			error = controller.report("MQ-01-01", _npc_id)
		"accept_second":
			error = controller.journal.accept("MQ-01-02")
		"report_second":
			error = controller.report("MQ-01-02", _npc_id)
		"close":
			pass
		_:
			return
	if not error.is_empty():
		_message.text = (
			"가방을 비운 뒤 다시 보고해 주세요." if error == "inventory_full" else "진행할 수 없습니다: " + error
		)
		return
	close_dialog()


func _refresh() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(960, 180)
	_box.add_child(_message)
	var states := controller.journal.export_state()
	if states.get("MQ-01-01", {}).get("state") == "ready":
		_message.text = "여울목 조합 순회 접수원\n출신을 묻지 않습니다. 당신의 공훈을 기록하겠습니다.\n모험가 패 · 경험치 75 · 20골드"
		_button("모험가 패 받기", "report_first")
	elif not states.has("MQ-01-02"):
		_message.text = "모험가 패 보유\n동쪽 서식지의 뿔토끼 2마리를 잡고 돌아와 주세요.\n경험치 325 · 100골드 · 하급 회복약 2개"
		_button("토끼몰이 수락", "accept_second")
	elif states["MQ-01-02"].state == "ready":
		_message.text = "토끼몰이 완료!\n보고하면 경험치 325 · 100골드 · 하급 회복약 2개를 받습니다."
		_button("보고하고 보상 받기", "report_second")
	elif states["MQ-01-02"].state == "completed":
		_message.text = "공훈부에 기록했습니다.\n다음 의뢰는 준비 중입니다. 모험가 패는 계속 유효합니다."
	else:
		_message.text = "토끼몰이: 뿔토끼 %d/2\n동쪽 서식지에서 처치한 뒤 돌아와 주세요." % states["MQ-01-02"].counts[0]
	_button("나중에 / 닫기 [Esc]", "close")


func _button(text: String, action: String) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(choose.bind(action))
	_box.add_child(button)


func _input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("menu_pause"):
		close_dialog()
		get_viewport().set_input_as_handled()
