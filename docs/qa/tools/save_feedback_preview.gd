## 저장 안내 UI만 재현하는 fixture. 정지 월드/시간 주입으로 실제 플레이를 대체하지 않는다.
extends SceneTree

const DIRECTORY := "user://save_feedback_preview"
const OUTPUT := "res://../docs/qa/screenshots/save-feedback"
var failed := false
var captures := 0


func _initialize() -> void:
	_run.call_deferred()
	create_timer(30.0).timeout.connect(func(): quit(1))


func _run() -> void:
	if (
		DirAccess.dir_exists_absolute(DIRECTORY)
		and not DirAccess.get_files_at(DIRECTORY).is_empty()
	):
		print("SAVE_FEEDBACK_PREVIEW_FAIL: 기존 QA 파일 보존, 빈 전용 폴더 필요")
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	var world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", DIRECTORY)
	root.add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player = world.get_node("Player")
	player.get_node("PlayerStats")._time_since_combat_action_sec = 10.0
	var session = world.get_node("SaveSession")
	_check(session.save_slot(1).ok, "기준 저장")
	var blocker = load("res://scenes/monsters/rabbit.tscn").instantiate()
	world.get_node("MonsterSpawner").add_child(blocker)
	blocker.global_position = player.global_position + Vector2(32, 0)
	var menu = world.get_node("SaveMenu")
	menu.open_menu()
	menu._action = "save"
	menu._slot = 1
	menu._confirm_action()
	_check("동쪽" in menu.status.text and "2.0칸" in menu.status.text, "차단 개체 안내")
	await _capture("manual-blocked")
	menu.close_menu()
	session.advance(180.0)
	menu.open_menu()
	_check("자동 저장 대기" in menu.status.text, "메뉴 재개 후 대기 안내")
	await _capture("automatic-wait")
	menu.close_menu()
	blocker.free()
	session.advance(0.01)
	_check("자동 저장 완료" in menu.badge.text, "안전 상태 즉시 재개")
	await _capture("automatic-complete")
	_check(captures == 3, "화면 검사 끝까지 실행")
	world.free()
	root.get_node("BgmManager").reset()
	for file in DirAccess.get_files_at(DIRECTORY):
		_check(DirAccess.remove_absolute(DIRECTORY.path_join(file)) == OK, "QA 파일 정리")
	print("SAVE_FEEDBACK_PREVIEW_FAIL" if failed else "SAVE_FEEDBACK_PREVIEW_PASS")
	quit(1 if failed else 0)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path(OUTPUT).simplify_path()
	_check(DirAccess.make_dir_recursive_absolute(output) == OK, "출력 폴더")
	_check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, label)
	captures += 1


func _check(condition: bool, label: String) -> void:
	print(label, ": ", condition)
	failed = failed or not condition
