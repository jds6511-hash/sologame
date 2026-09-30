## 전직/공격/회피와 저장 메뉴의 입력 배선 검사. 레벨 준비는 기존 디버그 키다.
extends SceneTree

var world: Node
var player: Node2D
var failed := false
var completed := false
var directory: String


func _initialize() -> void:
	node_added.connect(
		func(node):
			if (
				node.get_script() != null
				and (
					node.get_script().resource_path
					== "res://scripts/player/player_death_sequence.gd"
				)
			):
				node.connect("death_sequence_started", func(): _check(false, "세션 중 사망"))
	)
	create_timer(90).timeout.connect(func(): quit(1))
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	print(label, ": ", value)
	failed = failed or not value


func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame


func _button(owner: Node, text: String) -> bool:
	for node in owner.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree() and not node.disabled:
			node.pressed.emit()
			await process_frame
			return true
	_check(false, "표시 버튼 없음: " + text)
	return false


func _refresh() -> void:
	await process_frame
	world = current_scene
	player = world.get_node("Player")


func _menu_action(text: String, cancel := false) -> void:
	var menu = world.get_node("SaveMenu")
	if not menu.panel.visible:
		await _key(KEY_F6)
	_check(menu.panel.visible and paused, "F6 메뉴와 일시정지")
	await _button(menu, text)
	_check(menu.confirmation.visible, "확인창 표시")
	# 네이티브 확인창 클릭은 headless에서 검증하지 않는다. UI의 확인/취소 신호 경로만 실행.
	menu.confirmation.hide()
	menu.confirmation.emit_signal("canceled" if cancel else "confirmed")
	await process_frame
	await _refresh()


func _job(id: String, label: String, level: int) -> void:
	while player.get_node("PlayerProgression").current_level < level:
		await _key(KEY_PAGEUP)
	await _key(KEY_V)
	var screen = world.get_node("Hud/JobSelectionScreen")
	_check(screen.visible and paused, "V 전직 선택 화면")
	await _button(screen, label)
	_check(player.get_node("PlayerJobTransition").current_job_id == id, "UI 전직: " + id)
	_check(not paused and not screen.visible, "전직 후 일시정지 해제")


func _scenario(job: String, phase: String) -> void:
	world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", directory)
	root.add_child(world)
	current_scene = world
	await _refresh()
	if phase == "play":
		await _job(
			"archer" if job == "archer" else "warrior",
			"궁수 전직 (2)" if job == "archer" else "전사 전직 (1)",
			10
		)
		if job == "gladiator":
			await _job("gladiator", "검투사 전직 (1)", 40)
		Input.action_press("attack")
		await physics_frame
		await physics_frame
		_check(player.attack_state != 0, "전직 후 기본 공격 입력")
		Input.action_release("attack")
		await create_timer(1.5).timeout
		var start: Vector2 = player.position
		Input.action_press("move_right")
		Input.action_press("dodge")
		await physics_frame
		await physics_frame
		_check(player.is_dashing, "회피 입력")
		Input.action_release("dodge")
		Input.action_release("move_right")
		await create_timer(14).timeout
		_check(player.position.distance_to(start) > 1, "회피 실제 이동")
		await _menu_action("선택 슬롯에 저장", true)
		_check(not FileAccess.file_exists(directory.path_join("character_01.json")), "취소 시 파일 미생성")
		await _menu_action("선택 슬롯에 저장")
		_check(FileAccess.file_exists(directory.path_join("character_01.json")), "메뉴 저장 파일 생성")
		var menu = world.get_node("SaveMenu")
		print("저장 결과 안내: ", menu.status.text)
		_check(world.get_node("SaveSession").active_slot == 1, "저장 슬롯 활성화")
		var fixture := FileAccess.open(directory.path_join("expected.json"), FileAccess.WRITE)
		_check(fixture != null, "스냅샷 기록 가능")
		if fixture == null:
			return
		fixture.store_string(JSON.stringify(_snapshot()))
		fixture.close()
		await _key(KEY_ESCAPE)
		_check(not paused and not menu.panel.visible, "ESC 닫기·재개")
	else:
		await _menu_action("선택 슬롯 불러오기")
		_check(player.get_node("PlayerJobTransition").current_job_id == job, "별도 프로세스 메뉴 직업 복원")
		_check(not paused, "불러오기 일시정지 해제")
		var expected = JSON.parse_string(
			FileAccess.get_file_as_string(directory.path_join("expected.json"))
		)
		_check(
			expected is Dictionary and expected == JSON.parse_string(JSON.stringify(_snapshot())),
			"레벨·직업·포인트·회피 후 위치 복원"
		)
		var hash_before := FileAccess.get_sha256(directory.path_join("character_01.json"))
		await _menu_action("새 캐릭터 시작", true)
		_check(player.get_node("PlayerJobTransition").current_job_id == job, "새 캐릭터 취소 유지")
		await _menu_action("새 캐릭터 시작")
		_check(player.get_node("PlayerJobTransition").current_job_id == "adventurer", "새 캐릭터 초기 직업")
		_check(player.get_node("PlayerProgression").current_level == 1, "새 캐릭터 초기 레벨")
		_check(not paused, "새 캐릭터 일시정지 해제")
		_check(
			FileAccess.get_sha256(directory.path_join("character_01.json")) == hash_before,
			"기존 슬롯 해시 보존"
		)
	completed = true


func _snapshot() -> Dictionary:
	return {
		"job": str(player.get_node("PlayerJobTransition").current_job_id),
		"level": player.get_node("PlayerProgression").current_level,
		"exp": player.get_node("PlayerProgression").current_exp,
		"points": player.get_node("PlayerSkillPoints").available_points,
		"position": [player.position.x, player.position.y],
	}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if (
		args.size() != 2
		or args[0] not in ["warrior", "archer", "gladiator"]
		or args[1] not in ["cleanup", "play", "reload"]
	):
		quit(2)
		return
	directory = "user://job_save_menu_probe/" + args[0]
	if args[1] == "cleanup":
		if DirAccess.dir_exists_absolute(directory):
			for file in DirAccess.get_files_at(directory):
				_check(DirAccess.remove_absolute(directory.path_join(file)) == OK, "격리 파일 정리")
		completed = true
	else:
		await _scenario(args[0], args[1])
	_check(completed, "마지막 검사 도달")
	paused = false
	for action in ["attack", "dodge", "move_right"]:
		Input.action_release(action)
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	print("JOB_SAVE_MENU_FAIL" if failed else "JOB_SAVE_MENU_PASS")
	quit(1 if failed else 0)
