extends MarginContainer
## J 저널: 열람과 허용된 서브 현장 보고. 보상 확정은 QuestController 소관.

const View = preload("res://scripts/quests/quest_journal_view.gd")
const Presentation = preload("res://scripts/quests/quest_presentation.gd")
const FILTERS := ["all", "active", "ready", "completed"]
const FILTER_TEXT := ["전체", "미완료", "보고 가능", "완료"]
const OBJECTIVE_TEXT := {"completed": "완료", "current": "현재", "pending": "대기"}
var selected_quest_id := ""
var _journal: QuestJournal
var _filter := "active"
var _query := ""
var _entries: Array = []
var _states: Dictionary = {}
var _search: LineEdit
var _filter_control: OptionButton
var _list: VBoxContainer
var _title: Label
var _body: Label
var _lead: Label
var _count: Label
var _buttons: Dictionary = {}
var _controller: QuestController
var _report_button: Button
var _report_notice: Label
var _report_debounce_until := 0


func _ready() -> void:
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 24)
	var journal_theme := Theme.new()
	journal_theme.default_font = load(UiStyle.FONT_BODY_PATH)
	journal_theme.default_font_size = 26
	theme = journal_theme
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	_lead = _label(box, "접수원에게 첫 의뢰를 받아 보세요.")
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 16)
	box.add_child(toolbar)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "수락한 의뢰의 제목·목표·위치 검색"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(set_search)
	toolbar.add_child(_search)
	_filter_control = OptionButton.new()
	_filter_control.name = "StateFilter"
	for text in FILTER_TEXT:
		_filter_control.add_item(text)
	_filter_control.select(1)
	_filter_control.item_selected.connect(func(index): set_filter(FILTERS[index]))
	toolbar.add_child(_filter_control)
	var current_button := Button.new()
	current_button.name = "CurrentQuest"
	current_button.text = "현재 의뢰 보기"
	current_button.pressed.connect(focus_current)
	toolbar.add_child(current_button)
	_count = _label(box, "수락한 의뢰가 없습니다.")
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	var list_scroll := _scroll(columns)
	list_scroll.custom_minimum_size.x = 460
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	list_scroll.add_child(_list)
	var detail_scroll := _scroll(columns)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 20)
	detail_scroll.add_child(detail_box)
	_title = _label(detail_box, "의뢰를 선택하세요")
	_title.add_theme_font_size_override("font_size", 34)
	_body = _label(detail_box, "")
	_report_button = Button.new()
	_report_button.text = "현장 기록 제출 · 보상 받기"
	_report_button.custom_minimum_size.y = 52
	_report_button.pressed.connect(_report_selected)
	detail_box.add_child(_report_button)
	_report_notice = _label(detail_box, "")
	_label(box, "메인 의뢰는 HUD에 자동 추적됩니다. 목록 선택은 열람만 합니다.  ·  J / Esc 닫기")


func bind_journal(journal: QuestJournal, controller: QuestController = null) -> void:
	if _journal != null and _journal.changed.is_connected(refresh):
		_journal.changed.disconnect(refresh)
	_journal = journal
	_controller = controller
	_filter = "active"
	_query = ""
	selected_quest_id = ""
	_search.text = ""
	_filter_control.select(1)
	if _journal != null:
		_journal.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_states = _journal.export_state() if _journal != null else {}
	_entries = View.entries(_journal.catalog, _states, _filter, _query) if _journal else []
	var ids := _entries.map(func(entry): return entry.quest_id)
	if selected_quest_id not in ids:
		selected_quest_id = ids[0] if not ids.is_empty() else ""
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	for entry in _entries:
		var button := Button.new()
		button.name = entry.quest_id
		button.text = "%s\n%s" % [entry.title, View.STATE_TEXT[entry.state]]
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(select_quest.bind(entry.quest_id))
		_list.add_child(button)
		_buttons[entry.quest_id] = button
	_count.text = "표시 %d건 / 수락한 의뢰 %d건" % [_entries.size(), _states.size()]
	if _journal:
		_lead.text = (
			"다음 행동 · "
			+ (
				Presentation
				. select(_journal.catalog, _states, "yeoulmok_receptionist")
				. tracker
				. replace("\n", " · ")
			)
		)
	else:
		_lead.text = "연결된 캐릭터가 없습니다."
	_refresh_detail()


func visible_entries() -> Array:
	return _entries.duplicate(true)


func selected_detail() -> Dictionary:
	return View.detail(_journal.catalog, _states, selected_quest_id) if _journal else {}


func set_filter(value: String) -> void:
	if value not in FILTERS:
		return
	_filter = value
	_filter_control.select(FILTERS.find(value))
	refresh()


func set_search(value: String) -> void:
	_query = value
	if _search.text != value:
		_search.text = value
	refresh()


func select_quest(id: String) -> void:
	if id not in _buttons:
		return
	selected_quest_id = id
	_refresh_detail()


func focus_current() -> void:
	_query = ""
	_filter = "all"
	_search.text = ""
	_filter_control.select(0)
	refresh()
	if not _journal:
		return
	var current := Presentation.select(_journal.catalog, _states, "yeoulmok_receptionist")
	if _states.get(current.quest_id, {}).get("state") in ["active", "ready"]:
		select_quest(current.quest_id)
	else:
		selected_quest_id = ""
		_refresh_detail()


func _refresh_detail() -> void:
	_report_button.visible = false
	_report_notice.text = ""
	for id in _buttons:
		_buttons[id].set_pressed_no_signal(id == selected_quest_id)
	var detail := selected_detail()
	if detail.is_empty():
		_title.text = "표시할 의뢰가 없습니다" if _entries.is_empty() else "의뢰를 선택하세요"
		_body.text = "검색·필터를 바꾸거나 위의 다음 행동 안내를 확인하세요."
		return
	_title.text = detail.title + " · " + View.STATE_TEXT[detail.state]
	var lines: Array[String] = [detail.description, "", "목표"]
	for objective in detail.objectives:
		lines.append(
			(
				"[%s] %s  %d/%d"
				% [
					OBJECTIVE_TEXT[objective.status],
					objective.label,
					objective.current,
					objective.required
				]
			)
		)
		if not objective.location.is_empty():
			lines.append("    위치 · " + objective.location)
	lines.append_array(["", detail.next_action, "", "보상 · " + detail.reward])
	_body.text = "\n".join(lines)
	_report_button.visible = (
		_controller != null
		and detail.state == "ready"
		and _journal.catalog.has_method("allows_field_report")
		and _journal.catalog.allows_field_report(selected_quest_id)
	)


func _report_selected() -> void:
	if _controller == null or not _report_button.visible or Time.get_ticks_msec() < _report_debounce_until:
		return
	_report_debounce_until = Time.get_ticks_msec() + 300
	var id := selected_quest_id
	var error := _controller.report_from_journal(id)
	refresh()
	_report_notice.text = "보상을 받았습니다." if error.is_empty() else "보상을 받을 수 없습니다. 가방과 캐릭터 상태를 확인하세요."


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _scroll(parent: Node) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	return scroll
