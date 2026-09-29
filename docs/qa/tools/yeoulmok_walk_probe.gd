## 실제 이동/선택/대화 경로의 자동 회귀. OS 키 전달이나 사람 플레이 검증은 아니다.
extends SceneTree

const ART = preload("res://scripts/tools/yeoulmok_art_pilot.gd")
const KIT = preload("res://scripts/tools/yeoulmok_native_kit.gd")
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
var failed := false
var completed_dialogues := 0
var world: Node2D
var player: CharacterBody2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(_timeout)
	_run.call_deferred()


func _timeout() -> void:
	_release()
	print("YEOULMOK_WALK_FAIL: 전체 실행 시간 초과")
	quit(1)


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", "user://yeoulmok_walk_probe")
	root.add_child(world)
	current_scene = world
	await process_frame
	player = world.get_node("Player")
	if "--baseline" not in OS.get_cmdline_user_args():
		var art := ART.new()
		art.name = "ArtPilot"
		world.add_child(art)
		var result := KIT.install(art)
		_check(not result.has("error"), "키트 설치")
	var original_cells: PackedByteArray = world.get_node("Ground").tile_map_data.duplicate()
	await physics_frame
	await process_frame
	await _dialogue("yeoulmok_receptionist", "reception")
	if "--blocked" in OS.get_cmdline_user_args():
		# 음성 대조: QA에서만 이동을 막고 타임아웃 실패를 확인한다.
		player.process_mode = Node.PROCESS_MODE_DISABLED
	for point in [Vector2(200, 504), Vector2(200, 456), Vector2(248, 456)]:
		if not await _walk(point):
			break
	if not failed:
		await _dialogue("yeoulmok_gatewarden", "gate")
		for point in [Vector2(200, 456), Vector2(200, 504), Vector2(152, 504)]:
			if not await _walk(point):
				break
	if not failed:
		await _dialogue("yeoulmok_receptionist", "return")
		_check(player.position.distance_to(Vector2(152, 504)) <= 1.5, "도보 왕복 도착")
		_check(not player.get_node("PlayerStats").is_dead(), "왕복 생존")
		_check(completed_dialogues == 3, "대화 검사 3회 끝까지 실행")
	_check(world.get_node("Ground").tile_map_data == original_cells, "원본 타일 불변")
	_release()
	paused = false
	world.free()
	root.get_node("BgmManager").reset()
	print("YEOULMOK_WALK_FAIL" if failed else "YEOULMOK_WALK_PASS")
	quit(1 if failed else 0)


func _walk(target: Vector2) -> bool:
	var start := player.position
	var limit := 90 if "--blocked" in OS.get_cmdline_user_args() else 600
	for frame in range(limit):
		_release()
		var difference := target - player.position
		if difference.length() <= 1.5:
			print("도보 도달: ", start, " → ", player.position, " 목표 ", target)
			return true
		if absf(difference.x) > 1.0:
			Input.action_press("move_right" if difference.x > 0 else "move_left")
		if absf(difference.y) > 1.0:
			Input.action_press("move_down" if difference.y > 0 else "move_up")
		await physics_frame
		await process_frame
	_release()
	_check(false, "도보 타임아웃: %s → %s (현재 %s)" % [start, target, player.position])
	return false


func _dialogue(expected: String, capture: String) -> void:
	_release()
	await physics_frame
	await process_frame
	var selection = world.get_node("WorldInteraction")
	selection.refresh()
	var correct: bool = (
		selection.selected != null and selection.selected.interaction_id() == expected
	)
	_check(correct, "근접·레이캐스트·선택: " + expected)
	if not correct:
		return
	var name_label: Label = selection.selected.get_node("Name")
	var prompt: Label = selection.hud.get_node("InteractionPrompt")
	var name_screen: Rect2 = (
		name_label.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, name_label.size)
	)
	_check(not name_screen.intersects(prompt.get_global_rect()), "이름표·프롬프트 분리")
	var art = world.get_node_or_null("ArtPilot")
	if art != null:
		for prop in art.get_children():
			if not prop.has_meta("native_decoration"):
				continue
			var sprite: Sprite2D = prop.get_node("NativeSprite")
			var bounds := Rect2(sprite.texture.get_image().get_used_rect())
			bounds.position += sprite.position
			var screen: Rect2 = prop.get_global_transform_with_canvas() * bounds
			_check(not screen.intersects(name_screen), "장식·실제 이름표 분리")
			_check(not screen.intersects(prompt.get_global_rect()), "장식·실제 프롬프트 분리")
	await _capture(capture + "-prompt")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = "interact"
	event.pressed = false
	Input.parse_input_event(event)
	var dialog = world.get_node("QuestDialog")
	_check(dialog.panel.visible and paused, "대화 입력·일시정지: " + expected)
	await _capture(capture + "-dialog")
	event = InputEventAction.new()
	event.action = "menu_pause"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = "menu_pause"
	event.pressed = false
	Input.parse_input_event(event)
	_check(not paused and not dialog.panel.visible, "대화 닫기·재개")
	completed_dialogues += 1


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../docs/qa/screenshots/yeoulmok-walk")
	directory += "/baseline" if "--baseline" in OS.get_cmdline_user_args() else "/native"
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory + "/" + label + ".png") == OK, label)


func _release() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _check(value: bool, label: String) -> void:
	print(label, ": ", value)
	failed = failed or not value
