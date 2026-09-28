## 합성 상태·엔진 입력 검증. 실제 도보 플레이는 아니다.
extends SceneTree

var errors: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", "user://m5_journal_render")
	root.add_child(world)
	current_scene = world
	await process_frame
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var journal = world.get_node("QuestController").journal
	_check(
		(
			journal.restore_state(
				{
					"MQ-01-01": {"state": "completed", "counts": [1, 1]},
					"MQ-01-02": {"state": "completed", "counts": [2]},
					"MQ-01-03": {"state": "completed", "counts": [2]},
					"MQ-01-04": {"state": "active", "counts": [1, 0]}
				}
			)
			== ""
		),
		"fixture"
	)
	var before: Dictionary = journal.export_state()
	var menu = world.get_node("IntegratedMenu")
	var tab = menu.get_node("Tabs/JournalTab")
	await _key(KEY_J)
	_check(menu.is_open() and paused, "J opens journal and pauses")
	_check(menu.get_node("Tabs").current_tab == menu.Tab.JOURNAL, "journal tab")
	_check(tab.selected_detail().quest_id == "MQ-01-04", "current quest selected")
	await _capture("active")
	var search: LineEdit = tab._search
	search.grab_focus()
	await _key(KEY_J, 106)
	_check(menu.is_open() and search.text == "j", "J types in search, does not close")
	_check(tab.visible_entries().is_empty(), "search empty result")
	await _capture("search-empty")
	search.release_focus()
	tab.find_child("CurrentQuest", true, false).pressed.emit()
	_check(tab.selected_quest_id == "MQ-01-04", "current button clears search")
	tab.set_filter("completed")
	# 네이티브 버튼 신호를 통해 완료 이력을 선택한다.
	tab.find_child("MQ-01-02", true, false).pressed.emit()
	_check(tab.selected_detail().state == "completed", "completed row")
	await _capture("history")
	_check(journal.export_state() == before, "browsing never changes quest state")
	await _key(KEY_ESCAPE)
	_check(not menu.is_open() and not paused, "Esc resumes")
	await _key(KEY_J)
	await _key(KEY_J)
	_check(not menu.is_open() and not paused, "J toggles close")
	world.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("M5_JOURNAL_RENDER_PASS" if errors.is_empty() else str(errors))
	quit(0 if errors.is_empty() else 1)


func _key(code: int, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.unicode = unicode_value
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../docs/qa/evidence/m5-journal")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(
		root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, label
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
