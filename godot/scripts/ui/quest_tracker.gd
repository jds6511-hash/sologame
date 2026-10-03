extends CanvasLayer

const Presentation = preload("res://scripts/quests/quest_presentation.gd")

var journal: QuestJournal
var _label: Label
var _notification: Label
var _toggle: Button


func setup(controller: QuestController) -> void:
	layer = 5
	journal = controller.journal
	_toggle = Button.new()
	_toggle.position = Vector2(24, 222)
	_toggle.custom_minimum_size = Vector2(440, 36)
	_toggle.text = "의뢰 안내 접기 −  ·  J 상세"
	UiStyle.apply_body_font(_toggle, 22)
	_toggle.pressed.connect(_toggle_tracking)
	add_child(_toggle)
	_label = Label.new()
	_label.position = Vector2(24, 264)
	_label.custom_minimum_size = Vector2(440, 120)
	_label.max_lines_visible = 4
	_label.clip_text = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.apply_body_font(_label, 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_notification = Label.new()
	_notification.position = Vector2(650, 760)
	UiStyle.apply_body_font(_notification, 28)
	_notification.add_theme_color_override("font_outline_color", Color.BLACK)
	_notification.add_theme_constant_override("outline_size", 4)
	add_child(_notification)
	journal.changed.connect(_refresh)
	controller.reward_claimed.connect(_on_reward)
	_refresh()


func _toggle_tracking() -> void:
	_label.visible = not _label.visible
	_toggle.text = "의뢰 안내 접기 −  ·  J 상세" if _label.visible else "의뢰 안내 펼치기 +  ·  J 상세"


func _refresh() -> void:
	var npc_id := (
		"novera_gatewarden"
		if get_parent().get("map_id") == "novera_gate"
		else "yeoulmok_receptionist"
	)
	if journal.catalog.has_method("tracking_npc"):
		npc_id = journal.catalog.tracking_npc(journal.export_state())
	if journal.catalog.has_method("selected_view"):
		var selected_id := String(journal.get_meta("selected_quest_id", ""))
		var choices: Array = journal.catalog.available_ids(journal.export_state())
		if selected_id not in choices and not choices.is_empty():
			selected_id = choices[0]
		if selected_id in choices:
			var definition: QuestData = journal.catalog.definitions[selected_id]
			npc_id = (
				definition.npc_id
				if journal.export_state().has(selected_id)
				else definition.giver_id()
			)
	_label.text = (Presentation.for_journal(journal, npc_id).tracker)
	_label.text += "\n[J] 의뢰 목록·상세"


func _on_reward(id: String) -> void:
	var definition: QuestData = journal.catalog.definitions[id]
	_notification.text = "의뢰 보상: 경험치 +%d · 골드 +%d" % [definition.reward_exp, definition.reward_gold]
	if definition.reward_item_count > 0:
		_notification.text += " · 회복약 +%d" % definition.reward_item_count
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): _notification.text = "")
