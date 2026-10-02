extends QuestDialog


func open_notice(message: String) -> bool:
	if panel.visible or not _arbiter.acquire(self):
		return false
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_selection = {}
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(960, 180)
	_message.text = message
	_box.add_child(_message)
	_button("확인 / 닫기 [Esc]", "close")
	panel.show()
	return true


func _refresh() -> void:
	super._refresh()
	var catalog = controller.journal.catalog
	var states := controller.journal.export_state()
	var choices: Array = catalog.available_ids(states, _npc_id)
	if choices.size() < 2:
		return
	for id in choices:
		var button := Button.new()
		UiStyle.apply_action_button(button)
		button.text = "의뢰 선택: " + catalog.definitions[id].title
		button.pressed.connect(_select.bind(id))
		_box.add_child(button)


func _select(id: String) -> void:
	if load("res://scripts/content/game_selection.gd").select_quest(controller.journal, id):
		_refresh()
