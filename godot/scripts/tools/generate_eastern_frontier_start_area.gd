## MP-3 맵 씬 생성기 (여울목 부락 ~ 노베라 들녘, Lv1~12 밴드 일부).
##
## 참조: docs/design/levels/world-structure.md 2장 1번 항목·1-3 ASCII맵,
## docs/design/quests/quest-structure.md 3-2절(MQ-01-01~05),
## docs/design/systems/m2-monster-spec.md(뿔토끼·들개 마수·균열 점액 무리 규모),
## docs/art/PIPELINE.md 3장(씬 체크리스트).
##
## 한 번 실행해 결과물(TileSet 리소스 + TileMap 맵 씬)을 res:// 아래에 저장하는
## 빌드 도구 스크립트다. 런타임에 게임에서 참조하지 않는다.
## 실행: godot --headless --script res://scripts/tools/generate_eastern_frontier_start_area.gd
extends SceneTree

const TILE_PNG := "res://assets/tiles/eastern_frontier_tileset.png"
const TILE_JSON := "res://assets/tiles/eastern_frontier_tileset.json"
const TILESET_OUT := "res://assets/tiles/eastern_frontier_tileset.tres"
const SCENE_OUT := "res://scenes/world/eastern_frontier_starting_area.tscn"

const TILE_SIZE := 16

## 충돌이 필요한 타일 키 (MP-3 지시: 물/방벽/바위)
const COLLIDING_KEYS := ["river_water", "stone_wall", "rock_small"]

## 맵 그리드 크기 (타일 단위)
const MAP_W := 48
const MAP_H := 36

# 주요 좌표 (타일 단위) — 문서(ASCII맵)와 동일한 값을 유지할 것
const VILLAGE_RECT := Rect2i(2, 22, 16, 12)  # x=2..17, y=22..33
const VILLAGE_GATE_Y := Vector2i(27, 29)  # 동쪽 벽 개방 구간 (y=27..29)
const VILLAGE_PLAZA_RECT := Rect2i(6, 25, 8, 7)  # 석재 바닥 광장
const VILLAGE_FARM_WEST_RECT := Rect2i(3, 24, 3, 9)
const VILLAGE_FARM_EAST_RECT := Rect2i(14, 24, 3, 9)
const VILLAGE_FLAG_POS := Vector2i(9, 27)  # "부락 중심" 기준점

const RAIDED_FARM_RECT := Rect2i(18, 25, 4, 6)  # 뿔토끼가 헤집는 개척 농지

const RIVER_Y := Vector2i(13, 15)  # y=13..15 (3행)
const RIVER_X_END := 25  # x=1..25
const FORD_X := Vector2i(8, 10)  # 도섭 지점 (충돌 없음)

const TRAIL_X := 9  # 균열 굴로 이어지는 오솔길 x좌표
const TRAIL_Y := Vector2i(6, 21)  # y=6..21

const ROAD_Y := Vector2i(27, 28)  # 노베라 방향 대로 (2행)
const ROAD_X_START := 18
const NOBERA_EXIT_X := 47
const NOBERA_EXIT_Y := Vector2i(26, 29)

const HOLE_CENTER := Vector2i(9, 5)  # MQ-01-04 REACH 지점 "균열 굴 어귀"
const HOLE_INTERACT := Vector2i(11, 4)  # 균열 표식 조사 지점

const PLAYER_START := Vector2i(9, 31)
const NPC_RECEPTIONIST := Vector2i(9, 29)

var _key_to_atlas: Dictionary = {}


func _initialize() -> void:
	_load_manifest()
	var tile_set := _build_tileset()
	ResourceSaver.save(tile_set, TILESET_OUT)
	tile_set = load(TILESET_OUT)  # ext_resource로 정상 참조되도록 저장본을 다시 로드

	var root := Node2D.new()
	root.name = "EasternFrontierStartingArea"

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tile_set
	root.add_child(ground)
	_paint_ground(ground)

	# Camera2D.current는 --headless 모드에서 라이브 뷰포트가 없어 런타임 설정이 실패한다
	# (엔진 제약 — 트리 편입 여부와 무관하게 재현됨). zoom/position만 여기서 설정하고,
	# current=true는 저장 직후 _patch_camera_current()가 씬 텍스트에 직접 기입한다.
	var camera := Camera2D.new()
	camera.name = "DebugCamera2D"
	camera.zoom = Vector2(4, 4)
	camera.position = _tile_center_px(PLAYER_START)
	root.add_child(camera)

	var markers := Node2D.new()
	markers.name = "Markers"
	root.add_child(markers)
	_build_markers(markers)

	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("씬 pack 실패: %d" % pack_err)
		quit(1)
		return
	var save_err := ResourceSaver.save(packed, SCENE_OUT)
	if save_err != OK:
		push_error("씬 저장 실패: %d" % save_err)
		quit(1)
		return
	_patch_camera_current(SCENE_OUT)

	_report_distances()
	print("완료: ", SCENE_OUT)
	quit()


## Camera2D.current를 씬 텍스트에 직접 기입 (엔진 제약 우회, 위 _initialize() 주석 참조)
func _patch_camera_current(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var node_header := '[node name="DebugCamera2D"'
	var header_idx := text.find(node_header)
	if header_idx == -1:
		push_error("DebugCamera2D 노드 블록을 찾지 못해 current 패치 실패")
		return
	var line_end := text.find("\n", header_idx)
	text = text.insert(line_end + 1, "current = true\n")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _load_manifest() -> void:
	var text := FileAccess.get_file_as_string(TILE_JSON)
	var data: Dictionary = JSON.parse_string(text)
	for tile in data["tiles"]:
		_key_to_atlas[tile["key"]] = Vector2i(tile["col"], tile["row"])


func _build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var physics_layer_index := tile_set.get_physics_layers_count()
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(physics_layer_index, 1)

	var texture: Texture2D = load(TILE_PNG)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for row in range(4):
		for col in range(4):
			source.create_tile(Vector2i(col, row))

	tile_set.add_source(source)  # 물리 레이어 인식을 위해 충돌 폴리곤 설정 전에 소스를 등록해야 한다

	var half := float(TILE_SIZE) * 0.5
	var full_tile_polygon := PackedVector2Array(
		[Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	)
	for key in COLLIDING_KEYS:
		var atlas_coords: Vector2i = _key_to_atlas[key]
		var tile_data: TileData = source.get_tile_data(atlas_coords, 0)
		tile_data.add_collision_polygon(physics_layer_index)
		tile_data.set_collision_polygon_points(physics_layer_index, 0, full_tile_polygon)

	return tile_set


func _atlas(key: String) -> Vector2i:
	return _key_to_atlas[key]


func _set_cell(layer: TileMapLayer, x: int, y: int, key: String) -> void:
	layer.set_cell(Vector2i(x, y), 0, _atlas(key))


func _fill_rect(layer: TileMapLayer, rect: Rect2i, key: String) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_cell(layer, x, y, key)


func _paint_ground(layer: TileMapLayer) -> void:
	# 1. 기본 바닥 — 풀밭 + 결정적 패턴의 들꽃/덤불 장식
	for y in range(1, MAP_H - 1):
		for x in range(1, MAP_W - 1):
			var key := "grass_base"
			if (x + y) % 7 == 0:
				key = "grass_flower"
			elif (x + 2 * y) % 17 == 0:
				key = "bush_small"
			_set_cell(layer, x, y, key)

	# 2. 맵 경계 — 바위 (충돌), 노베라 방향 출구만 개방
	for x in range(0, MAP_W):
		_set_cell(layer, x, 0, "rock_small")
		_set_cell(layer, x, MAP_H - 1, "rock_small")
	for y in range(0, MAP_H):
		_set_cell(layer, 0, y, "rock_small")
		if y >= NOBERA_EXIT_Y.x and y <= NOBERA_EXIT_Y.y:
			_set_cell(layer, NOBERA_EXIT_X, y, "dirt_path")
		else:
			_set_cell(layer, NOBERA_EXIT_X, y, "rock_small")

	# 3. 여울목 부락 — 방벽 + 동쪽 대문 + 내부(광장/농지/울타리/깃발)
	var v := VILLAGE_RECT
	for x in range(v.position.x, v.position.x + v.size.x):
		_set_cell(layer, x, v.position.y, "stone_wall")
		_set_cell(layer, x, v.position.y + v.size.y - 1, "stone_wall")
	for y in range(v.position.y, v.position.y + v.size.y):
		_set_cell(layer, v.position.x, y, "stone_wall")
		var east_x := v.position.x + v.size.x - 1
		if y >= VILLAGE_GATE_Y.x and y <= VILLAGE_GATE_Y.y:
			_set_cell(layer, east_x, y, "dirt_path")  # 대문 개방
		else:
			_set_cell(layer, east_x, y, "stone_wall")

	_fill_rect(layer, VILLAGE_PLAZA_RECT, "stone_floor")
	_fill_rect(layer, VILLAGE_FARM_WEST_RECT, "tilled_soil")
	_fill_rect(layer, VILLAGE_FARM_EAST_RECT, "tilled_soil")
	# 농지 테두리 울타리 (장식 — 충돌 없음)
	for rect in [VILLAGE_FARM_WEST_RECT, VILLAGE_FARM_EAST_RECT]:
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_cell(layer, x, rect.position.y - 1, "wood_fence")
	_set_cell(layer, VILLAGE_FLAG_POS.x, VILLAGE_FLAG_POS.y, "flag_banner")

	# 4. 뿔토끼가 헤집는 개척 농지 (부락 바로 너머)
	_fill_rect(layer, RAIDED_FARM_RECT, "tilled_soil")

	# 5. 대로 — 부락 대문에서 노베라 방향 출구까지
	for y in range(ROAD_Y.x, ROAD_Y.y + 1):
		for x in range(ROAD_X_START, NOBERA_EXIT_X):
			_set_cell(layer, x, y, "dirt_path")

	# 6. 여울목 개울물 + 도섭 지점(강가 모래톱)
	for y in range(RIVER_Y.x, RIVER_Y.y + 1):
		for x in range(1, RIVER_X_END + 1):
			if x >= FORD_X.x and x <= FORD_X.y:
				_set_cell(layer, x, y, "riverbank_sand")
			else:
				_set_cell(layer, x, y, "river_water")

	# 7. 균열 굴로 이어지는 오솔길 (도섭 지점을 관통)
	for y in range(TRAIL_Y.x, TRAIL_Y.y + 1):
		if y >= RIVER_Y.x and y <= RIVER_Y.y:
			continue  # 도섭 지점 타일 유지
		_set_cell(layer, TRAIL_X, y, "dirt_path")

	# 8. 옛 균열 굴 어귀 — 균열 흉터 대지 + 폐허 잔해 + 바위 (일부 개방)
	var hx := HOLE_CENTER.x
	var hy := HOLE_CENTER.y
	for offset in [
		Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
	]:
		_set_cell(layer, hx + offset.x, hy + offset.y, "cracked_ground")
	for pos in [Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		_set_cell(layer, hx + pos.x, hy + pos.y, "rubble_stone")
	for pos in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
		_set_cell(layer, hx + pos.x, hy + pos.y, "rock_small")

	# 9. 들개 지역 — 성긴 바위(거친 지형), 이동 경로는 막지 않도록 고정 좌표만 사용
	for pos in [Vector2i(30, 14), Vector2i(34, 10), Vector2i(38, 20), Vector2i(26, 12)]:
		_set_cell(layer, pos.x, pos.y, "rock_small")


func _tile_center_px(tile_pos: Vector2i) -> Vector2:
	return Vector2(
		tile_pos.x * TILE_SIZE + TILE_SIZE * 0.5, tile_pos.y * TILE_SIZE + TILE_SIZE * 0.5
	)


func _add_marker(group: Node2D, marker_name: String, tile_pos: Vector2i) -> Marker2D:
	var marker := Marker2D.new()
	marker.name = marker_name
	marker.position = _tile_center_px(tile_pos)
	group.add_child(marker)
	return marker


func _add_group(parent: Node2D, group_name: String) -> Node2D:
	var group := Node2D.new()
	group.name = group_name
	parent.add_child(group)
	return group


func _build_markers(parent: Node2D) -> void:
	var player_group := _add_group(parent, "PlayerStart")
	_add_marker(player_group, "PlayerStart", PLAYER_START)

	var npc_group := _add_group(parent, "NPCs")
	_add_marker(npc_group, "NPC_조합순회접수원", NPC_RECEPTIONIST)

	var quest_group := _add_group(parent, "QuestPoints")
	_add_marker(
		quest_group,
		"REACH_부락초입관문_MQ0105",
		Vector2i(
			VILLAGE_RECT.position.x + VILLAGE_RECT.size.x - 1,
			(VILLAGE_GATE_Y.x + VILLAGE_GATE_Y.y) / 2
		)
	)
	_add_marker(quest_group, "REACH_균열굴어귀_MQ0104", HOLE_CENTER)
	_add_marker(quest_group, "INTERACT_균열표식_MQ0104", HOLE_INTERACT)
	_add_marker(quest_group, "REACH_부락중심_거리기준점", VILLAGE_FLAG_POS)
	_add_marker(
		quest_group,
		"NoberaExit_지역전환예정_MP3범위밖",
		Vector2i(NOBERA_EXIT_X, (NOBERA_EXIT_Y.x + NOBERA_EXIT_Y.y) / 2)
	)

	var rabbit_group := _add_group(parent, "MonsterSpawns_뿔토끼")
	_add_marker(rabbit_group, "RabbitSpawn_A", Vector2i(21, 22))
	_add_marker(rabbit_group, "RabbitSpawn_B", Vector2i(24, 30))
	_add_marker(rabbit_group, "RabbitSpawn_C", Vector2i(19, 25))

	var dog_group := _add_group(parent, "MonsterSpawns_들개마수")
	_add_marker(dog_group, "DogPackSpawn_A", Vector2i(32, 20))
	_add_marker(dog_group, "DogPackSpawn_B", Vector2i(36, 16))

	var slime_group := _add_group(parent, "MonsterSpawns_균열점액")
	_add_marker(slime_group, "SlimeSpawn_A", Vector2i(6, 6))
	_add_marker(slime_group, "SlimeSpawn_B", Vector2i(13, 6))


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)


func _report_distances() -> void:
	var flag_to_hole := Vector2(VILLAGE_FLAG_POS).distance_to(Vector2(HOLE_CENTER))
	var start_to_hole := Vector2(PLAYER_START).distance_to(Vector2(HOLE_CENTER))
	var manhattan_start_to_hole := (
		abs(PLAYER_START.x - HOLE_CENTER.x) + abs(PLAYER_START.y - HOLE_CENTER.y)
	)
	print("[MQ-01-04 거리 실측]")
	print(
		(
			"  부락 중심(깃발, %s) → 균열 굴 어귀(%s) 직선거리: %.1f 타일"
			% [VILLAGE_FLAG_POS, HOLE_CENTER, flag_to_hole]
		)
	)
	print("  플레이어 시작점(%s) → 균열 굴 어귀(%s) 직선거리: %.1f 타일" % [PLAYER_START, HOLE_CENTER, start_to_hole])
	print("  플레이어 시작점 → 균열 굴 어귀 맨해튼 거리(실제 이동 경로 하한): %d 타일" % manhattan_start_to_hole)
