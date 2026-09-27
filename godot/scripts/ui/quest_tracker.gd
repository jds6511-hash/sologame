extends CanvasLayer

const Presentation = preload("res://scripts/quests/quest_presentation.gd")

var journal: QuestJournal
var _label: Label
var _notification: Label


func setup(controller: QuestController) -> void:
	layer = 5
	journal = controller.journal
	_label = Label.new()
	_label.position = Vector2(1300, 340)
	_label.custom_minimum_size = Vector2(540, 100)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.apply_body_font(_label, 24)
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


func _refresh() -> void:
	_label.text = (
		Presentation
		. select(journal.catalog, journal.export_state(), "yeoulmok_receptionist")
		. tracker
	)
	var menu = get_parent().get_node_or_null("IntegratedMenu")
	if menu:
		menu.get_node("Tabs/JournalTab").set_message(_label.text)


func _on_reward(id: String) -> void:
	var definition: QuestData = journal.catalog.definitions[id]
	_notification.text = "의뢰 보상: 경험치 +%d · 골드 +%d" % [definition.reward_exp, definition.reward_gold]
	if definition.reward_item_count > 0:
		_notification.text += " · 회복약 +%d" % definition.reward_item_count
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): _notification.text = "")
