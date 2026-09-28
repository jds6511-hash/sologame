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
	var query := PhysicsShapeQueryParameters2D.new()
	var player_shape = world.get_node("Player/CollisionShape2D")
	query.shape = player_shape.shape
	query.collision_mask = 1
	query.exclude = [world.get_node("Player").get_rid()]
	var space = world.get_world_2d().direct_space_state
	query.transform = Transform2D(0, Vector2(40, 360))
	_check(not space.intersect_shape(query).is_empty(), "기존 북서 성벽 충돌 존재")
	var routes := {
		"동문": [Vector2(152, 504), Vector2(200, 504), Vector2(200, 456), Vector2(300, 456)],
		"관문지기": [Vector2(248, 456), Vector2(280, 456)],
		"귀환점": [Vector2(248, 456), Vector2(200, 456), Vector2(200, 504), Vector2(152, 504)],
		"MQ04 동문 우회와 여울":
		[Vector2(300, 456), Vector2(300, 280), Vector2(152, 280), Vector2(152, 200)]
	}
	for label in routes:
		_check(_route_clear(routes[label], query, space, player_shape.transform), label)
	for rect in ART.FOOTPRINTS:
		query.transform = Transform2D(0, rect.get_center())
		_check(not space.intersect_shape(query).is_empty(), "건물 내부 충돌 존재")
	await _capture("pilot-night")
	world.get_node("DayNightModulate").color = Color.WHITE
	await _capture("pilot-day")
	_check(art.y_sort_enabled and art.z_index == 0, "시제품 정렬 컨테이너")
	for building_name in ["House", "Workshop"]:
		var building = art.get_node(building_name)
		_check(building.z_index == 0 and building.position.y == 424, building_name + " 발밑 정렬")
		for feet_y in [398, 448]:
			world.get_node("Player").position = Vector2(building.position.x, feet_y)
			camera.reset_smoothing()
			await _capture(building_name.to_lower() + "-" + str(feet_y))
	world.get_node("Player").position = Vector2(152, 504)
	camera.reset_smoothing()
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
	var directory := ProjectSettings.globalize_path("res://../docs/qa/screenshots/yeoulmok-art")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(
		root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, label
	)


func _check(condition: bool, label: String) -> void:
	print(label + ": " + str(condition))
	failed = failed or not condition


func _route_clear(
	points: Array,
	query: PhysicsShapeQueryParameters2D,
	space: PhysicsDirectSpaceState2D,
	local_shape: Transform2D
) -> bool:
	for index in range(points.size() - 1):
		var steps := int(points[index].distance_to(points[index + 1]) / 4) + 1
		for step in range(steps + 1):
			var feet: Vector2 = points[index].lerp(points[index + 1], float(step) / steps)
			query.transform = Transform2D(0, feet) * local_shape
			if not space.intersect_shape(query).is_empty():
				print("차단된 발 위치: ", feet)
				return false
	return true
