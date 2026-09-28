## 합성 선행 진행·좌표 배치와 실제 엔진 입력을 사용한다. 디렉터 플레이가 아니다.
extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", "user://m5_fourth_render")
	root.add_child(world)
	current_scene = world
	await process_frame
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var selector = world.get_node("WorldInteraction")
	var quests = world.get_node("QuestController")
	var journal = quests.journal
	journal.restore_state(
		{
			"MQ-01-01": {"state": "completed", "counts": [1, 1]},
			"MQ-01-02": {"state": "completed", "counts": [2]},
			"MQ-01-03": {"state": "completed", "counts": [2]}
		}
	)
	selector.refresh()
	await _key(KEY_F)
	var dialog = world.get_node("QuestDialog")
	_check(dialog.panel.visible, "접수원 F 대화")
	await _capture("offer")
	dialog._box.get_child(1).pressed.emit()
	_check(journal.export_state().has("MQ-01-04"), "수락 버튼")
	world.get_node("Player").global_position = world.get_node("RiftInvestigation").reach_position
	world.get_node("Player/Camera2D").reset_smoothing()
	selector.refresh()
	await _capture("site")
	await _key(KEY_F)
	_check(journal.export_state()["MQ-01-04"].state == "ready", "표식 F 조사")
	await _capture("ready")
	world.get_node("Player").global_position = Vector2(152, 504)
	selector.refresh()
	await _key(KEY_F)
	await _capture("report")
	dialog._box.get_child(1).pressed.emit()
	_check(world.get_node("Player/Inventory").gold == 300, "보고 버튼 보상")
	world.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("M5_FOURTH_RENDER_PASS" if not failed else "M5_FOURTH_RENDER_FAIL")
	quit(1 if failed else 0)


func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
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
	var directory := ProjectSettings.globalize_path("res://../docs/qa/evidence/m5-fourth")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(
		root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, label
	)


func _check(condition: bool, label: String) -> void:
	print(label + ": " + str(condition))
	failed = failed or not condition
