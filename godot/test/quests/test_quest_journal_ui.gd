extends GutTest

const WORLD = preload("res://scenes/world/eastern_frontier_starting_area.tscn")
const Presentation = preload("res://scripts/quests/quest_presentation.gd")
var world: Node
var tab: Control
var journal: QuestJournal


func before_each() -> void:
	world = WORLD.instantiate()
	world.set_meta("save_directory", "user://journal_ui_%d" % Time.get_ticks_usec())
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("WorldInteraction").process_mode = Node.PROCESS_MODE_DISABLED
	await wait_process_frames(8)
	tab = world.get_node("IntegratedMenu/Tabs/JournalTab")
	journal = world.get_node("QuestController").journal


func after_each() -> void:
	get_tree().paused = false
	await wait_process_frames(1)
	BgmManager.reset()
	GameClock.reset()


func _implemented() -> bool:
	assert_true(tab.has_method("visible_entries"), "J 탭은 의뢰 목록을 제공해야 한다")
	return tab.has_method("visible_entries")


func _fourth(state: String = "active", counts: Array = [1, 0]) -> void:
	assert_eq(
		journal.restore_state(
			{
				"MQ-01-01": {"state": "completed", "counts": [1, 1]},
				"MQ-01-02": {"state": "completed", "counts": [2]},
				"MQ-01-03": {"state": "completed", "counts": [2]},
				"MQ-01-04": {"state": state, "counts": counts}
			}
		),
		""
	)


func test_journal_shows_only_accepted_content_and_never_mutates_progress() -> void:
	if not _implemented():
		return
	var before := journal.export_state()
	var entries: Array = tab.visible_entries()
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].quest_id, "MQ-01-01")
	tab.select_quest("MQ-01-04")
	assert_eq(tab.selected_quest_id, "MQ-01-01")
	entries[0].title = "외부 변경"
	assert_ne(tab.visible_entries()[0].title, "외부 변경")
	assert_eq(journal.export_state(), before)


func test_filters_search_and_hidden_future_content() -> void:
	if not _implemented():
		return
	_fourth()
	tab.set_filter("completed")
	assert_eq(tab.visible_entries().size(), 3)
	tab.set_search("들개")
	assert_eq(tab.visible_entries().size(), 1)
	tab.set_search("없는 의뢰")
	assert_eq(tab.visible_entries().size(), 0)
	assert_eq(tab.selected_quest_id, "")
	tab.focus_current()
	assert_eq(tab.selected_quest_id, "MQ-01-04")
	assert_eq(tab.visible_entries().size(), 4)


func test_all_objectives_and_report_then_history_update_from_signals() -> void:
	if not _implemented():
		return
	_fourth()
	tab.focus_current()
	var detail: Dictionary = tab.selected_detail()
	assert_eq(detail.objectives.size(), 2)
	assert_eq(detail.objectives[0].status, "completed")
	assert_eq(detail.objectives[1].status, "current")
	assert_eq(detail.objectives[1].current, 0)
	assert_string_contains(detail.reward, "1040")
	journal.record_event("INTERACT", "yeoulmok_rift_mark", "yeoulmok_old_rift_site", 0)
	assert_eq(tab.selected_detail().state, "ready")
	tab.set_filter("ready")
	assert_eq(tab.visible_entries().size(), 1)
	assert_eq(world.get_node("QuestController").report("MQ-01-04", "yeoulmok_receptionist"), "")
	assert_eq(tab.visible_entries().size(), 0)
	tab.set_filter("completed")
	tab.select_quest("MQ-01-04")
	assert_eq(tab.selected_detail().state, "completed")
	assert_string_contains(tab.selected_detail().next_action, "수령 완료")
	assert_eq(world.get_node("Player/Inventory").gold, 300)


func test_viewing_history_does_not_change_main_tracker() -> void:
	if not _implemented():
		return
	_fourth()
	var tracker = world.get_node("QuestTracker")
	var before: String = tracker._label.text
	tab.set_filter("all")
	tab.select_quest("MQ-01-01")
	assert_eq(tracker._label.text, before)
	assert_string_contains(before, "균열")


func test_tracker_can_collapse_without_changing_progress() -> void:
	if not _implemented():
		return
	var tracker = world.get_node("QuestTracker")
	var before := journal.export_state()
	tracker._toggle.pressed.emit()
	assert_false(tracker._label.visible)
	assert_true(tracker._toggle.visible)
	tracker._refresh()
	assert_false(tracker._label.visible, "목표 갱신이 접은 안내를 다시 열지 않음")
	tracker._toggle.pressed.emit()
	assert_true(tracker._label.visible)
	assert_eq(journal.export_state(), before)


func test_rebinding_clears_ui_preferences_and_old_journal_subscription() -> void:
	if not _implemented():
		return
	_fourth()
	tab.set_filter("completed")
	tab.set_search("들개")
	var replacement := QuestJournal.new(QuestCatalog.new())
	replacement.accept("MQ-01-01")
	tab.bind_journal(replacement)
	assert_eq(tab.visible_entries().size(), 1)
	assert_eq(tab.selected_quest_id, "MQ-01-01")
	assert_false(journal.changed.is_connected(tab.refresh))
	assert_true(replacement.changed.is_connected(tab.refresh))


func test_journal_menu_shares_pause_owner_and_close_resumes_world() -> void:
	if not _implemented():
		return
	var menu = world.get_node("IntegratedMenu")
	var dialog = world.get_node("QuestDialog")
	assert_true(dialog.open_dialog("yeoulmok_receptionist"))
	menu._on_tab_shortcut(IntegratedMenu.Tab.JOURNAL)
	assert_false(menu.is_open())
	assert_true(get_tree().paused)
	dialog.close_dialog()
	menu._on_tab_shortcut(IntegratedMenu.Tab.JOURNAL)
	assert_true(menu.is_open())
	assert_true(get_tree().paused)
	assert_false(dialog.open_dialog("yeoulmok_receptionist"))
	menu._on_tab_shortcut(IntegratedMenu.Tab.INVENTORY)
	assert_true(get_tree().paused)
	menu.close_menu()
	assert_false(get_tree().paused)


func test_pending_objectives_empty_search_and_invalid_filter_are_read_only() -> void:
	if not _implemented():
		return
	_fourth("active", [0, 0])
	tab.focus_current()
	var detail: Dictionary = tab.selected_detail()
	assert_eq(detail.objectives[0].status, "current")
	assert_eq(detail.objectives[1].status, "pending")
	detail.objectives[0].current = 99
	assert_eq(tab.selected_detail().objectives[0].current, 0)
	tab.set_search("  푸른 표식  ")
	assert_eq(tab.visible_entries().size(), 1)
	tab.set_filter("unknown")
	assert_eq(tab.visible_entries().size(), 1)
	tab.bind_journal(null)
	assert_eq(tab.visible_entries(), [])
	assert_eq(tab.selected_detail(), {})
