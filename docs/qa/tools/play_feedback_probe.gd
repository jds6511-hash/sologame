extends SceneTree

var world: Node
var failed := false


func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", "user://play_feedback_probe")
	root.add_child(world)
	current_scene = world
	await process_frame
	var menu = world.get_node("SaveMenu")
	menu.open_menu()
	await process_frame
	await process_frame
	for button in menu.panel.find_children("*", "Button", true, false):
		if button is OptionButton or button.text.begins_with("돌아가기"):
			continue
		for ratio in [0.1, 0.5, 0.9]:
			var point: Vector2 = button.global_position + button.size * Vector2(0.5, ratio)
			await click(point)
			check(menu.confirmation.visible, "저장 메뉴 클릭 %s %.1f" % [button.text, ratio])
			menu.confirmation.hide()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			"res://../docs/qa/screenshots/play-feedback-save.png"
		)
	menu.close_menu()
	var dialog = world.get_node("QuestDialog")
	var journal = world.get_node("QuestController").journal
	var reward_clicks := 0
	for ratio in [0.1, 0.5, 0.9]:
		check(
			journal.restore_state({"MQ-01-01": {"state": "active", "counts": [1, 0]}}) == "",
			"보상 검사 준비"
		)
		dialog.open_dialog("yeoulmok_receptionist")
		await process_frame
		await process_frame
		for button in dialog.panel.find_children("*", "Button", true, false):
			if button.text == "모험가 패 받기":
				reward_clicks += 1
				await click(button.global_position + button.size * Vector2(0.5, ratio))
				check(journal.export_state()["MQ-01-01"].state == "completed", "보상 클릭 %.1f" % ratio)
	check(reward_clicks == 3, "보상 검사 3개 도달")
	dialog.close_dialog()
	var integrated = world.get_node("IntegratedMenu")
	integrated._on_tab_shortcut(4)
	check(integrated.is_open(), "지도 열림")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../docs/qa/screenshots/play-feedback-map.png")
	integrated.close_menu()
	menu._show_status("자동 저장 완료 · 슬롯 1")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../docs/qa/screenshots/play-feedback-toast.png")
	menu._process(4.1)
	check(not menu.toast.visible, "자동 저장 알림 종료")
	world.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("PLAY_FEEDBACK_FAIL" if failed else "PLAY_FEEDBACK_PASS")
	quit(1 if failed else 0)


func click(point: Vector2) -> void:
	# GUI 로컬 좌표 입력. OS 물리 클릭과 구분하며 pressed 신호를 직접 호출하지 않는다.
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		root.push_input(event, true)
		await process_frame


func check(ok: bool, label: String) -> void:
	print(label, ": ", ok)
	failed = failed or not ok
