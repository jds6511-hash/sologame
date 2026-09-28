## 별도 저장 폴더의 실제 월드 인스턴스로 비교. 제품 씬/에셋은 변경하지 않는다.
extends SceneTree

const ART = preload("res://scripts/tools/yeoulmok_art_pilot.gd")
const KIT = preload("res://scripts/tools/yeoulmok_native_kit.gd")
var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if "--candidate" in arguments and "--native-kit" in arguments:
		print("후보 원본과 정수 픽셀 키트는 별도 실행으로 비교합니다.")
		quit(2)
		return
	if "--candidate" in arguments and "--interactive" in arguments:
		print("후보 이미지의 충돌·앵커는 미승인입니다. --candidate는 정지 비교만 지원합니다.")
		quit(2)
		return
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
	if "--native-kit" in arguments:
		var manifest: Dictionary = KIT.install(art)
		_check(not manifest.has("error"), "정수 픽셀 키트 설치")
		if manifest.has("error"):
			print(manifest.error)
			quit(1)
			return
		_check_native_contract(art, manifest)
		_check_native_visibility(art)
		_check_native_edges(art, ground)
		_check_object_ground(art, ground)
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
	if "--native-kit" in arguments:
		world.get_node("Player").position = Vector2(248, 456)
		camera.reset_smoothing()
		await _capture("return-arrival")
		world.get_node("Player").position = Vector2(152, 264)
		camera.reset_smoothing()
		await _capture("shore-day")
		world.get_node("DayNightModulate").color = Color("6d7ab5")
		await _capture("shore-night")
		world.get_node("DayNightModulate").color = Color.WHITE
		for point in [Vector2(152, 200), Vector2(152, 96), Vector2(560, 320)]:
			world.get_node("Player").position = point
			camera.reset_smoothing()
			await _capture("region-%d-%d" % [int(point.x), int(point.y)])
		world.get_node("DayNightModulate").color = Color.WHITE
		world.get_node("Player").position = Vector2(152, 504)
		camera.reset_smoothing()
	if "--candidate" in OS.get_cmdline_user_args():
		await _candidate_preview(world, art)
	if "--interactive" in OS.get_cmdline_user_args():
		world.process_mode = Node.PROCESS_MODE_INHERIT
		camera.position = Vector2.ZERO
		print("여울목 시각 시제품: 별도 저장 폴더, 제품 아트 미적용")
		return
	world.free()
	root.get_node("BgmManager").reset()
	await process_frame
	var label := (
		"YEOULMOK_ART_CANDIDATE_PREVIEW" if "--candidate" in arguments else "YEOULMOK_ART_PILOT"
	)
	if "--native-kit" in arguments:
		label = "YEOULMOK_NATIVE_KIT"
	print(label + ("_PASS" if not failed else "_FAIL"))
	quit(1 if failed else 0)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../docs/qa/screenshots/yeoulmok-art")
	if "--native-kit" in OS.get_cmdline_user_args():
		directory = directory.path_join("native-kit")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(
		root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, label
	)


func _check(condition: bool, label: String) -> void:
	print(label + ": " + str(condition))
	failed = failed or not condition


func _check_native_contract(art: Node2D, manifest: Dictionary) -> void:
	var index := 0
	for name in ["House", "Workshop"]:
		var entry: Dictionary = manifest.buildings[name]
		var building = art.get_node(name)
		var sprite: Sprite2D = building.get_node("NativeSprite")
		var footprint: Array = entry.footprint
		var bounds := Rect2(
			building.position + sprite.position + Vector2(footprint[0], footprint[1]),
			Vector2(footprint[2], footprint[3])
		)
		_check(bounds == ART.FOOTPRINTS[index], name + " 명시 벽 범위와 충돌 일치")
		_check(sprite.scale == Vector2.ONE, name + " 원본 1px를 월드 1px로 표시")
		_check(
			sprite.position + Vector2(entry.threshold[0], entry.threshold[1]) == Vector2.ZERO,
			name + " 문턱과 발밑 앵커 일치"
		)
		index += 1


func _check_native_visibility(art: Node2D) -> void:
	var protected := [Vector2(248, 456), Vector2(280, 456), Vector2(152, 472), Vector2(152, 504)]
	for child in art.get_children():
		if not child.has_meta("native_decoration"):
			continue
		var sprite: Sprite2D = child.get_node("NativeSprite")
		var used := sprite.texture.get_image().get_used_rect()
		var bounds := Rect2(Vector2(used.position) + child.position + sprite.position, used.size)
		if str(child.name).begins_with("Native_bench"):
			var previous := Rect2(bounds.position + Vector2(244, 470) - child.position, bounds.size)
			_check(previous.has_point(Vector2(248, 456)), "이전 벤치 배치 가림 재현")
		for point in protected:
			_check(not bounds.has_point(point), str(child.name) + " 보호 지점 가림 없음")
		_check(not bounds.intersects(Rect2(200, 450, 100, 7)), str(child.name) + " 동문 발밑 여백")
		_check(not bounds.intersects(Rect2(194, 456, 12, 55)), str(child.name) + " 세로 동선 여백")
		for patch in ART.CROP_PATCHES:
			_check(not bounds.intersects(patch), str(child.name) + " 작물 가림 없음")
		if str(child.name).begins_with("Native_bench"):
			var old_crop := Rect2(bounds.position + Vector2(224, 488) - child.position, bounds.size)
			_check(old_crop.intersects(ART.CROP_PATCHES[1]), "이전 벤치 작물 겹침 재현")


func _check_object_ground(art: Node2D, ground: TileMapLayer) -> void:
	var bases := {}
	var objects := {}
	for sprite in art.get_node("NativeSurface").get_children():
		var cell := Vector2i(sprite.position / 16)
		if sprite.has_meta("base_kind"):
			bases[cell] = sprite
		if sprite.has_meta("original_object"):
			objects[cell] = sprite
	var expected := 0
	var bounds := ground.get_used_rect()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			if ground.get_cell_atlas_coords(cell) not in [Vector2i(2, 3), Vector2i(3, 3)]:
				continue
			expected += 1
			_check(bases.has(cell) and objects.has(cell), "오브젝트 바닥/그림 분리 설치")
			if not bases.has(cell) or not objects.has(cell):
				continue
			_check(bases[cell].get_index() < objects[cell].get_index(), "바닥 뒤 원래 소품 표시")
			var image: Image = bases[cell].texture.get_image()
			_check(not image.detect_alpha(), "오브젝트 바닥 불투명")
			var source: TileSetAtlasSource = ground.tile_set.get_source(
				ground.get_cell_source_id(cell)
			)
			var region := source.get_tile_texture_region(ground.get_cell_atlas_coords(cell))
			var original := source.texture.get_image().get_region(region)
			_check(
				original.get_data() == objects[cell].texture.get_image().get_data(), "소품 픽셀 원본 보존"
			)
	_check(objects.size() == expected and expected > 0, "오브젝트 전수 보존")
	_check(bases.has(Vector2i(10, 12)), "MQ04 표식 아래 바닥")
	_check(bases.has(Vector2i(2, 16)), "강 남쪽 덤불 아래 바닥")
	_check(not bases.has(Vector2i(9, 14)), "여울 바닥 덮기 금지")
	_check(bases.has(Vector2i(27, 20)), "동부 필드 지면 연결")
	_check(bases.has(Vector2i(0, 0)), "북쪽 가장자리 바닥 연결")
	var expected_bases := 0
	for cell in ground.get_used_cells():
		var atlas := ground.get_cell_atlas_coords(cell)
		var eligible := (
			atlas
			in [
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(2, 0),
				Vector2i(3, 0),
				Vector2i(2, 3),
				Vector2i(3, 3)
			]
		)
		_check(bases.has(cell) == eligible, "지역 전수 지면 포함/제외")
		expected_bases += int(eligible)
	_check(bases.size() == expected_bases, "맵 밖 추가 지면 없음")
	print("표면 수: ", bases.size(), " / 분리 오브젝트: ", objects.size())


func _check_native_edges(art: Node2D, ground: TileMapLayer) -> void:
	for offset in [Vector2i(0, 2), Vector2i(2, 0), Vector2i(0, 1)]:
		var equal := 0
		var total := 0
		for y in range(36 - offset.y):
			for x in range(48 - offset.x):
				var cell := Vector2i(x, y)
				equal += int(KIT.variant_for(cell) == KIT.variant_for(cell + offset))
				total += 1
		var ratio := float(equal) / total
		print("변형 2차원 일치율: ", offset, " ", equal, "/", total)
		_check(ratio >= 0.3 and ratio <= 0.7, "변형의 행/열 단주기 반복 방지")
	var counts := {"road": 0, "shore": 0}
	var corners := {"road": 0, "shore": 0}
	var actual_edges := {}
	for sprite in art.get_node("NativeSurface").get_children():
		if sprite.has_meta("corner_kind"):
			var kind: String = sprite.get_meta("corner_kind")
			var direction: String = sprite.get_meta("corner_direction")
			var cell := Vector2i(sprite.position / 16)
			var dx := Vector2i(1 if "e" in direction else -1, 0)
			var dy := Vector2i(0, 1 if "s" in direction else -1)
			var neighbors := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 3), Vector2i(3, 3)]
			if kind == "shore":
				neighbors.append_array([Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1)])
				_check(ground.get_cell_atlas_coords(cell) == Vector2i(1, 1), "물가 코너는 물 셀")
			else:
				_check(
					ground.get_cell_atlas_coords(cell) in [Vector2i(2, 0), Vector2i(3, 0)],
					"길 코너는 흙 셀"
				)
			_check(ground.get_cell_atlas_coords(cell + dx + dy) in neighbors, "코너의 대각 경계 존재")
			_check(
				(
					ground.get_cell_atlas_coords(cell + dx) not in neighbors
					and ground.get_cell_atlas_coords(cell + dy) not in neighbors
				),
				"직선 경계와 코너 중복 없음"
			)
			corners[kind] += 1
		if not sprite.has_meta("edge_kind"):
			continue
		var kind: String = sprite.get_meta("edge_kind")
		counts[kind] += 1
		var cell := Vector2i(sprite.position / 16)
		var direction: String = sprite.get_meta("edge_direction")
		var key := "%s:%s:%s" % [cell, kind, direction]
		_check(not actual_edges.has(key), "직선 경계 중복 없음")
		actual_edges[key] = true
		if kind == "shore":
			_check(ground.get_cell_atlas_coords(cell) == Vector2i(1, 1), "물가 장식은 물 셀 안쪽")
	_check(counts.road > 0 and counts.shore > 0, "길/물가 접합 실제 배치")
	print("접합 수: ", counts)
	_check(corners.road + corners.shore > 0, "코너 실제 배치")
	print("코너 수: ", corners)
	var expected_edges := {}
	var directions := {
		"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)
	}
	for cell in ground.get_used_cells():
		var atlas := ground.get_cell_atlas_coords(cell)
		if atlas not in [Vector2i(1, 1), Vector2i(2, 0), Vector2i(3, 0)]:
			continue
		var kind := "shore" if atlas == Vector2i(1, 1) else "road"
		var eligible := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 3), Vector2i(3, 3)]
		if kind == "shore":
			eligible.append_array([Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1)])
		for direction in directions:
			if ground.get_cell_atlas_coords(cell + directions[direction]) in eligible:
				expected_edges["%s:%s:%s" % [cell, kind, direction]] = true
	_check(actual_edges == expected_edges, "전 지역 직선 경계 누락/과잉 없음")


func _candidate_preview(world: Node2D, art: Node2D) -> void:
	var loader = load("res://scripts/tools/yeoulmok_candidate_assets.gd")
	var path := "res://../docs/art/concepts/yeoulmok/buildings-source-v2.png"
	var inspection: Dictionary = loader.inspect_source(path)
	_check(not inspection.has("error"), "후보 원본 읽기/투명 분리")
	if inspection.has("error"):
		print(inspection.error)
		return
	var report := inspection.duplicate()
	report.erase("image")
	print("후보 원본 실측: ", JSON.stringify(report))
	print("후보 품질 판정: 원본 규격·팔레트 미승인, 물리 검사는 도형 시제품에 한정")
	for width in [48.0, 72.0]:
		loader.install(art, inspection, width)
		for night in [false, true]:
			world.get_node("DayNightModulate").color = Color("6d7ab5") if night else Color.WHITE
			await _capture("candidate-v2-%d-%s" % [int(width), "night" if night else "day"])
	world.get_node("DayNightModulate").color = Color.WHITE


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
