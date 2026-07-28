## C-10 검증 — 신규 적 배치가 `world-structure.md` 2장 레벨 밴드와 어긋나지 않는지,
## 스폰 마커·스포너 배선·야간 전용 스폰이 실제로 작동하는지 확인한다.
##
## 씬 인스턴스화 없이 PackedScene.get_state()로 노드 트리를 읽는다 — 시작 지역 씬을 그대로
## 인스턴스화하면 HUD·튜토리얼·몬스터 십수 마리가 함께 뜨고, 마커 좌표 검증에는 불필요하다.
##
## 밴드 근거(배치 문서 3장): 시작 지역(노베라 들녘)은 Lv1~12이므로 신규 7종 중 배치 가능한
## 것은 숲거미 계열(Lv10, 밴드 8~16 하단)뿐이다. 그마저 여울목 개울(y=13~15타일, 도섭 지점만
## 통행) **북쪽**에만 두어, Lv1 구간(부락·뿔토끼 서식지·대로, y>=18타일)과 지형으로 분리한다.
extends GutTest

const START_AREA_PATH := "res://scenes/world/eastern_frontier_starting_area.tscn"
const FIELD_PATH := "res://scenes/world/m3_new_enemy_field.tscn"
const TILE_PX := 16.0
## 여울목 개울의 남쪽 끝 행(타일) — 이보다 큰 y는 Lv1~4 저레벨 권역이다.
const RIVER_SOUTH_EDGE_TILE_Y := 15

const SPIDER_GROUP := "Markers/MonsterSpawns_숲거미"
const SHADOW_GROUP := "Markers/MonsterSpawns_그림자숲거미_야간"

# --- 씬 상태 조회 헬퍼 ---


## SceneState의 노드 경로는 루트 기준 "./..." 형태다 — 비교 편의를 위해 접두사를 떼어낸다.
func _relative_path(state: SceneState, index: int) -> String:
	return str(state.get_node_path(index)).trim_prefix("./")


func _state(scene_path: String) -> SceneState:
	var scene: PackedScene = load(scene_path)
	assert_not_null(scene, "%s 로드 실패" % scene_path)
	return scene.get_state()


## 노드 경로(부모 기준 상대 경로) → 그 노드의 프로퍼티 딕셔너리.
func _node_properties(state: SceneState, node_path: String) -> Dictionary:
	var props := {}
	for i in state.get_node_count():
		var full_path := _relative_path(state, i)
		if full_path != node_path:
			continue
		for p in state.get_node_property_count(i):
			props[state.get_node_property_name(i, p)] = state.get_node_property_value(i, p)
		return props
	return props


## 지정한 그룹 노드 직속 자식 마커들의 위치(px).
func _marker_positions(state: SceneState, group_path: String) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for i in state.get_node_count():
		var full_path := _relative_path(state, i)
		if not full_path.begins_with(group_path + "/"):
			continue
		if full_path.trim_prefix(group_path + "/").contains("/"):
			continue
		for p in state.get_node_property_count(i):
			if state.get_node_property_name(i, p) == "position":
				positions.append(state.get_node_property_value(i, p))
	return positions


# --- 시작 지역: 마커·스포너 배선 ---


func test_start_area_spawner_paths_are_wired() -> void:
	var props := _node_properties(_state(START_AREA_PATH), "MonsterSpawner")
	assert_eq(
		str(props.get("forest_spider_spawn_root_path", "")), "../" + SPIDER_GROUP, "숲거미 스폰 그룹 배선"
	)
	assert_eq(
		str(props.get("shadow_forest_spider_night_spawn_root_path", "")),
		"../" + SHADOW_GROUP,
		"그림자 숲거미 야간 스폰 그룹 배선"
	)


func test_start_area_has_forest_spider_markers() -> void:
	var state := _state(START_AREA_PATH)
	assert_eq(_marker_positions(state, SPIDER_GROUP).size(), 3, "숲거미 3마커(개별 급습 2~3마리 군집)")
	assert_eq(_marker_positions(state, SHADOW_GROUP).size(), 2, "그림자 숲거미 야간 2마커")


## 숲거미 계열은 전부 개울 북쪽(Lv8~12 위험대)에 있어야 한다 — Lv1 구간과 지형 분리.
func test_start_area_spiders_stay_north_of_the_river() -> void:
	var state := _state(START_AREA_PATH)
	for group in [SPIDER_GROUP, SHADOW_GROUP]:
		for pos in _marker_positions(state, group):
			assert_lt(
				pos.y / TILE_PX,
				float(RIVER_SOUTH_EDGE_TILE_Y),
				"%s 마커(y=%.0fpx)는 개울 북쪽이어야 한다" % [group, pos.y]
			)


## 개별 급습이라도 마커가 겹치면 개체가 포개 보인다 — 최소 3타일 간격을 보장한다.
func test_start_area_spider_markers_are_spread_out() -> void:
	var state := _state(START_AREA_PATH)
	var all_positions := _marker_positions(state, SPIDER_GROUP)
	all_positions.append_array(_marker_positions(state, SHADOW_GROUP))
	for i in all_positions.size():
		for j in range(i + 1, all_positions.size()):
			var gap := all_positions[i].distance_to(all_positions[j]) / TILE_PX
			assert_gte(gap, 3.0, "마커 %d-%d 간격 %.1f타일" % [i, j, gap])


## 저레벨 플레이어가 MQ-01-04(균열 굴 어귀 REACH·INTERACT)를 수행하는 동선에 Lv10 숲거미의
## 인지 범위(6타일)가 닿으면 안 된다 — quest-designer 동선과의 충돌 방지.
func test_start_area_spiders_do_not_cover_mq0104_quest_points() -> void:
	var state := _state(START_AREA_PATH)
	var quest_points: Array[Vector2] = []
	for marker_name in ["REACH_균열굴어귀_MQ0104", "INTERACT_균열표식_MQ0104"]:
		var props := _node_properties(state, "Markers/QuestPoints/" + marker_name)
		assert_true(props.has("position"), "%s 마커가 있어야 한다" % marker_name)
		quest_points.append(props["position"])
	var perception_tiles := (
		(load("res://data/monsters/forest_spider_stats.tres") as MonsterStatsData)
		. perception_range_tiles
	)
	var all_positions := _marker_positions(state, SPIDER_GROUP)
	all_positions.append_array(_marker_positions(state, SHADOW_GROUP))
	for quest_point in quest_points:
		for spawn in all_positions:
			var gap := spawn.distance_to(quest_point) / TILE_PX
			assert_gt(gap, perception_tiles, "퀘스트 지점과 숲거미 스폰 간격 %.1f타일" % gap)


## 야간 활성 시간대에 저레벨 플레이어가 균열 점액(Lv8)과 그림자 숲거미(Lv10 야간 ×1.2)를
## 동시에 상대하지 않도록, 야간 아종 스폰은 균열 점액 스폰에서 인지 범위 밖에 둔다.
func test_night_spiders_do_not_overlap_rift_slime_spawns() -> void:
	var state := _state(START_AREA_PATH)
	var perception_tiles := (
		(load("res://data/monsters/shadow_forest_spider_stats.tres") as MonsterStatsData)
		. perception_range_tiles
	)
	var slime_positions := _marker_positions(state, "Markers/MonsterSpawns_균열점액")
	assert_gt(slime_positions.size(), 0, "균열 점액 마커가 있어야 한다")
	for shadow in _marker_positions(state, SHADOW_GROUP):
		for slime in slime_positions:
			var gap := shadow.distance_to(slime) / TILE_PX
			assert_gt(gap, perception_tiles, "그림자 숲거미-균열 점액 스폰 간격 %.1f타일" % gap)


## 시작 지역에는 밴드를 넘는 종(무법자 Lv14 이상)의 스폰 그룹이 없어야 한다.
func test_start_area_has_no_out_of_band_species() -> void:
	var props := _node_properties(_state(START_AREA_PATH), "MonsterSpawner")
	for key in [
		"outlaw_pack_spawn_root_path",
		"highwayman_pack_spawn_root_path",
		"poacher_spawn_root_path",
		"imp_pack_spawn_root_path",
		"imp_lord_camp_spawn_root_path",
	]:
		assert_false(props.has(key), "시작 지역(Lv1~12)에 %s 배선 금지" % key)


# --- 검증 필드: 밴드 초과 5종의 배치 ---


func test_verification_field_wires_all_seven_species() -> void:
	var props := _node_properties(_state(FIELD_PATH), "MonsterSpawner")
	for key in [
		"forest_spider_spawn_root_path",
		"shadow_forest_spider_night_spawn_root_path",
		"outlaw_pack_spawn_root_path",
		"highwayman_pack_spawn_root_path",
		"poacher_spawn_root_path",
		"imp_pack_spawn_root_path",
		"imp_lord_camp_spawn_root_path",
	]:
		assert_true(props.has(key), "검증 필드: %s 배선 필요" % key)


## 구역 간 간격이 최대 인지 범위(밀렵꾼 7타일)보다 넓어야 구역끼리 어그로가 새지 않는다.
func test_verification_field_zones_do_not_leak_aggro() -> void:
	var state := _state(FIELD_PATH)
	var groups := [
		"Markers/MonsterSpawns_무법자",
		"Markers/MonsterSpawns_노상강도",
		"Markers/MonsterSpawns_밀렵꾼",
		"Markers/MonsterSpawns_임프",
		"Markers/MonsterSpawns_임프장균열포인트",
	]
	var centers: Array[Vector2] = []
	for group in groups:
		var positions := _marker_positions(state, group)
		assert_eq(positions.size(), 1, "%s 는 구역 대표 마커 1개" % group)
		centers.append(positions[0])
	for i in centers.size():
		for j in range(i + 1, centers.size()):
			var gap := centers[i].distance_to(centers[j]) / TILE_PX
			assert_gt(gap, 7.0, "구역 %d-%d 간격 %.1f타일 > 최대 인지 7타일" % [i, j, gap])


# --- 야간 전용 스폰 실작동 (그림자 숲거미) ---


class NightSpawnHarness:
	extends Node2D

	var spawner: MonsterSpawner

	func _init() -> void:
		var markers := Node2D.new()
		markers.name = "NightMarkers"
		for i in 2:
			var marker := Marker2D.new()
			marker.name = "ShadowSpawn_%d" % i
			marker.position = Vector2(i * 64, 0)
			markers.add_child(marker)
		add_child(markers)
		spawner = MonsterSpawner.new()
		spawner.name = "Spawner"
		spawner.shadow_forest_spider_night_spawn_root_path = NodePath("../NightMarkers")
		add_child(spawner)


func _spawned_shadow_spiders(harness: NightSpawnHarness) -> int:
	var count := 0
	for child in harness.spawner.get_children():
		if child is MonsterBase and child.stats.display_name == "그림자 숲거미":
			count += 1
	return count


func test_shadow_spider_spawns_only_at_night() -> void:
	GameClock.reset()
	var harness := NightSpawnHarness.new()
	add_child_autofree(harness)
	await wait_frames(3)
	assert_eq(_spawned_shadow_spiders(harness), 0, "낮에는 그림자 숲거미가 없다")

	GameClock.night_started.emit(1)
	await wait_frames(2)
	assert_eq(_spawned_shadow_spiders(harness), 2, "밤이 되면 마커 수만큼 스폰")

	GameClock.day_started.emit(2)
	await wait_frames(2)
	assert_eq(_spawned_shadow_spiders(harness), 0, "낮이 되면 소멸")
	GameClock.reset()


func test_shadow_spider_does_not_accumulate_on_repeated_night_signals() -> void:
	GameClock.reset()
	var harness := NightSpawnHarness.new()
	add_child_autofree(harness)
	await wait_frames(3)

	GameClock.night_started.emit(1)
	await wait_frames(2)
	GameClock.night_started.emit(1)
	await wait_frames(2)
	assert_eq(_spawned_shadow_spiders(harness), 2, "야간 신호가 중복돼도 개체가 누적되지 않는다")
	GameClock.day_started.emit(2)
	await wait_frames(2)
	GameClock.reset()
