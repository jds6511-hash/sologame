## 별도 저장 폴더의 실제 월드 인스턴스로 비교. 제품 씬/에셋은 변경하지 않는다.
extends SceneTree

const ART = preload("res://scripts/tools/yeoulmok_art_pilot.gd")
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", "user://yeoulmok_art_pilot")
	root.add_child(world)
	current_scene = world
	await process_frame
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var camera = world.get_node("Player/Camera2D")
	camera.position = Vector2(24, -52)
	camera.reset_smoothing()
	var ground = world.get_node("Ground")
	ground.process_mode = Node.PROCESS_MODE_ALWAYS
	var cells = ground.tile_map_data.duplicate()
	await _capture("before-day")
	world.get_node("DayNightModulate").color = Color("6d7ab5")
	await _capture("before-night")
	var art := ART.new()
	art.process_mode = Node.PROCESS_MODE_ALWAYS
	art.name = "ArtPilot"
	world.add_child(art)
	_check(ground.tile_map_data == cells, "원본 타일·충돌 데이터 불변")
	_check(world.get_node("Player").position == Vector2(152, 504), "플레이어 시작점 불변")
	for rect in ART.FOOTPRINTS:
		_check(not rect.grow(40).has_point(Vector2(152, 472)), "접수원 접근 보존")
		_check(not rect.intersects(Rect2(96, 432, 176, 80)), "광장·동문 경로 보존")
	await physics_frame
	await process_frame
	var points := [Vector2(152, 504), Vector2(200, 504), Vector2(200, 448), Vector2(300, 448)]
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8
	query.shape = circle
	query.collision_mask = 1
	query.exclude = [world.get_node("Player").get_rid()]
	var space = world.get_world_2d().direct_space_state
	query.transform = Transform2D(0, Vector2(40, 360))
	_check(not space.intersect_shape(query).is_empty(), "기존 북서 성벽 충돌 존재")
	var route_clear := true
	for index in range(points.size() - 1):
		var steps := int(points[index].distance_to(points[index + 1]) / 4) + 1
		for step in range(steps + 1):
			query.transform = Transform2D(
				0, points[index].lerp(points[index + 1], float(step) / steps)
			)
			route_clear = route_clear and space.intersect_shape(query).is_empty()
	_check(route_clear, "반경8px 물리 질의: 시작점에서 동문 밖까지")
	for rect in ART.FOOTPRINTS:
		query.transform = Transform2D(0, rect.get_center())
		_check(not space.intersect_shape(query).is_empty(), "건물 내부 충돌 존재")
	await _capture("pilot-night")
	world.get_node("DayNightModulate").color = Color.WHITE
	await _capture("pilot-day")
	if "--interactive" in OS.get_cmdline_user_args():
		world.process_mode = Node.PROCESS_MODE_INHERIT
		camera.position = Vector2.ZERO
		print("여울목 시각 시제품: 별도 저장 폴더, 제품 아트 미적용")
		return
	world.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("YEOULMOK_ART_PILOT_PASS" if not failed else "YEOULMOK_ART_PILOT_FAIL")
	quit(1 if failed else 0)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../docs/qa/evidence/yeoulmok-art")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(
		root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, label
	)


func _check(condition: bool, label: String) -> void:
	print(label + ": " + str(condition))
	failed = failed or not condition
