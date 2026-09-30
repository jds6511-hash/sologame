extends QuestDialog


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
	if controller.journal.catalog.select_quest(id, controller.journal.export_state()):
		controller.journal.changed.emit()
		_refresh()
