class_name QuestDialog
extends CanvasLayer

const Presentation = preload("res://scripts/quests/quest_presentation.gd")
const Npcs = preload("res://scripts/npc/npc_registry.gd")
const Regions = preload("res://scripts/world/region_registry.gd")

var controller: QuestController
var panel: PanelContainer
var _box: VBoxContainer
var _message: Label
var _npc_id := ""
var _arbiter: UiPauseArbiter
var _selection: Dictionary = {}


func setup(quests: QuestController) -> void:
	controller = quests
	_arbiter = UiPauseArbiter.for_world(get_parent())
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 31
	panel = PanelContainer.new()
	panel.position = Vector2(440, 300)
	panel.custom_minimum_size = Vector2(1040, 400)
	var panel_style := UiStyle.make_panel_stylebox()
	panel_style.bg_color.a = 1.0
	panel.add_theme_stylebox_override("panel", panel_style)
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
	if not Npcs.SCENES.has(npc_id) or panel.visible or not _arbiter.acquire(self):
		return false
	_npc_id = npc_id
	controller.journal.record_event("TALK", npc_id, "", 0)
	_refresh()
	panel.show()
	return true


func close_dialog() -> void:
	panel.hide()
	_arbiter.release(self)


func choose(action: String, quest_id: String = "") -> void:
	if not panel.visible:
		return
	if action == "close":
		close_dialog()
		return
	var current := Presentation.select(
		controller.journal.catalog, controller.journal.export_state(), _npc_id
	)
	if (
		quest_id.is_empty()
		or quest_id != _selection.get("quest_id")
		or action != _selection.get("action")
		or current != _selection
	):
		return
	var error := ""
	match action:
		"travel":
			var session = get_parent().get_node("SaveSession")
			var destination := Regions.START if _npc_id == "novera_gatewarden" else Regions.NEXT
			close_dialog()
			var result: Dictionary = session.travel(destination)
			if not result.ok:
				open_dialog(_npc_id)
				_message.text = "이동할 수 없습니다: " + result.code + "\n안전한 상태에서 다시 시도하세요."
			return
		"report":
			error = controller.report(quest_id, _npc_id)
		"accept":
			error = controller.journal.accept(quest_id)
		_:
			return
	if not error.is_empty():
		_message.text = (
			"가방을 비운 뒤 다시 보고해 주세요." if error == "inventory_full" else "진행할 수 없습니다: " + error
		)
		return
	close_dialog()
	if action == "report" and quest_id == "MQ-01-05":
		var result: Dictionary = get_parent().get_node("SaveSession").travel(Regions.NEXT)
		if not result.ok:
			open_dialog(_npc_id)
			_message.text += "\n이동 대기: " + result.code + " · 보상은 이미 받았습니다."


func _refresh() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(960, 180)
	_box.add_child(_message)
	_selection = Presentation.select(
		controller.journal.catalog, controller.journal.export_state(), _npc_id
	)
	_message.text = _selection.message
	if not _selection.action.is_empty():
		_button(_selection.button, _selection.action, _selection.quest_id)
	_button("나중에 / 닫기 [Esc]", "close")


func _button(text: String, action: String, quest_id: String = "") -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(choose.bind(action, quest_id))
	_box.add_child(button)


func _input(event: InputEvent) -> void:
	if panel.visible and event.is_action_pressed("menu_pause"):
		close_dialog()
		get_viewport().set_input_as_handled()
