## D-3 검증 — `monster_spawner.gd`의 마커(무리) 단위 재스폰.
##
## Phase D(`docs\design\systems\m3-balance-phase-d.md` 3-5장)가 "재스폰이 없어 빌드 전체 EXP
## 재고가 Lv10 요구량의 25.8%뿐이라 정상 플레이로 전직에 도달할 수 없다"고 판정한 G3-1 차단
## 요인을 해소한 구현의 회귀 테스트다. 규칙·수치 근거는 `docs\design\levels\m3-respawn-spec.md`.
##
## 시간은 실시간으로 기다리지 않고 `MonsterSpawner.advance_respawn_tick()`을 필요한 횟수만큼
## 직접 호출해 주입한다(쿨다운이 30~180초라 실시간 대기는 불가능하다). `_process`가 하는 일은
## 그 함수를 RESPAWN_TICK_SEC 주기로 부르는 것뿐이므로 판정 로직은 그대로 검증된다.
extends GutTest

const TILE := 16.0
## 게이트·쿨다운 판정에 걸리지 않도록 플레이어를 멀리 두는 기본 위치(타일).
const FAR_AWAY := Vector2(400, 400)

# --- 하네스 ---


## 루트 + Player 노드. 스포너는 `../Player`로 플레이어를 찾는다.
func _make_root(player_tile: Vector2 = FAR_AWAY) -> Node2D:
	var root := Node2D.new()
	root.name = "RespawnHarness"
	var player := Node2D.new()
	player.name = "Player"
	player.position = player_tile * TILE
	root.add_child(player)
	return root


func _add_marker_group(root: Node2D, group_name: String, tiles: Array) -> void:
	var group := Node2D.new()
	group.name = group_name
	for i in tiles.size():
		var marker := Marker2D.new()
		marker.name = "Spawn_%d" % i
		marker.position = (tiles[i] as Vector2) * TILE
		group.add_child(marker)
	root.add_child(group)


## exports: { 스포너 export 이름 → 마커 그룹 노드 이름 }
func _attach_spawner(root: Node2D, exports: Dictionary) -> MonsterSpawner:
	var spawner := MonsterSpawner.new()
	spawner.name = "Spawner"
	spawner.player_path = NodePath("../Player")
	for export_name in exports:
		spawner.set(export_name, NodePath("../%s" % exports[export_name]))
	root.add_child(spawner)
	return spawner


func _player_of(root: Node2D) -> Node2D:
	return root.get_node("Player") as Node2D


# --- 조회/조작 헬퍼 ---


## 살아 있는 몬스터 수. `_die()`는 사망 애니메이션이 끝난 뒤에야 queue_free하므로 자식 수가
## 아니라 `is_dead()`로 센다(시체가 남아 있어도 정확하다).
func _living(spawner: MonsterSpawner, display_name := "") -> int:
	var count := 0
	for child in spawner.get_children():
		var monster := child as MonsterBase
		if monster == null or monster.is_dead():
			continue
		if not display_name.is_empty() and monster.stats.display_name != display_name:
			continue
		count += 1
	return count


func _living_monsters(spawner: MonsterSpawner) -> Array[MonsterBase]:
	var alive: Array[MonsterBase] = []
	for child in spawner.get_children():
		var monster := child as MonsterBase
		if monster != null and not monster.is_dead():
			alive.append(monster)
	return alive


## leave_alive마리를 남기고 나머지를 즉사시킨다.
func _kill_all(spawner: MonsterSpawner, leave_alive := 0) -> void:
	var alive := _living_monsters(spawner)
	for i in range(alive.size() - leave_alive):
		alive[i].take_damage(99999.0, "강")


func _tick(spawner: MonsterSpawner, seconds: int) -> void:
	for _i in seconds:
		spawner.advance_respawn_tick(MonsterSpawner.RESPAWN_TICK_SEC)


# --- 재스폰 트리거 ---


func test_solo_marker_respawns_after_cooldown() -> void:
	GameClock.reset()
	var root := _make_root()
	_add_marker_group(root, "Rabbits", [Vector2(0, 0)])
	var spawner := _attach_spawner(root, {"rabbit_spawn_root_path": "Rabbits"})
	add_child_autofree(root)
	await wait_physics_frames(2)
	assert_eq(_living(spawner), 1, "마커 1개 = 최초 1마리")

	_kill_all(spawner)
	assert_eq(_living(spawner), 0, "처치 직후에는 0마리")

	_tick(spawner, int(MonsterSpawner.NORMAL_RESPAWN_SEC) - 1)
	assert_eq(_living(spawner), 0, "쿨다운 만료 전에는 재스폰되지 않는다")

	_tick(spawner, 1)
	assert_eq(_living(spawner), 1, "쿨다운(%.0f초) 만료 시 재스폰" % MonsterSpawner.NORMAL_RESPAWN_SEC)
	GameClock.reset()


func test_pack_marker_does_not_respawn_until_wiped() -> void:
	GameClock.reset()
	var root := _make_root()
	_add_marker_group(root, "Wolves", [Vector2(0, 0)])
	var spawner := _attach_spawner(root, {"wolf_pack_spawn_root_path": "Wolves"})
	add_child_autofree(root)
	await wait_physics_frames(3)
	var initial := _living(spawner)
	assert_between(initial, 2, 4, "들개 마수는 마커당 2~4마리")

	_kill_all(spawner, 1)
	assert_eq(_living(spawner), 1, "1마리를 남겨 둔 상태")
	_tick(spawner, int(MonsterSpawner.NORMAL_RESPAWN_SEC) * 2)
	assert_eq(_living(spawner), 1, "무리가 전멸하지 않으면 개체가 리필되지 않는다")

	_kill_all(spawner)
	_tick(spawner, int(MonsterSpawner.NORMAL_RESPAWN_SEC))
	assert_between(_living(spawner), 2, 4, "전멸 후에는 무리 단위로 다시 스폰된다")
	GameClock.reset()


# --- 거리 게이트 ---


func test_respawn_waits_until_player_leaves_perception_range() -> void:
	GameClock.reset()
	## 뿔토끼 인지 범위 3타일 + 여유 1타일 = 게이트 4타일. 플레이어를 2타일 거리에 둔다.
	var root := _make_root(Vector2(2, 0))
	_add_marker_group(root, "Rabbits", [Vector2(0, 0)])
	var spawner := _attach_spawner(root, {"rabbit_spawn_root_path": "Rabbits"})
	add_child_autofree(root)
	await wait_physics_frames(2)
	_kill_all(spawner)

	_tick(spawner, int(MonsterSpawner.NORMAL_RESPAWN_SEC) * 3)
	assert_eq(_living(spawner), 0, "플레이어가 인지 범위 안에 있으면 재스폰을 미룬다")

	_player_of(root).position = FAR_AWAY * TILE
	_tick(spawner, 1)
	assert_eq(_living(spawner), 1, "플레이어가 벗어나면 쿨다운은 이미 만료 상태이므로 즉시 재스폰(지연이지 취소가 아니다)")
	GameClock.reset()


# --- 성능: 프레임(틱) 분산 ---


func test_simultaneous_cooldowns_spawn_one_marker_per_tick() -> void:
	GameClock.reset()
	assert_eq(MonsterSpawner.MAX_RESPAWNS_PER_TICK, 1, "틱당 스폰 마커 상한은 1이어야 한다(스폰 스톨 방지)")
	var root := _make_root()
	_add_marker_group(root, "Rabbits", [Vector2(0, 0), Vector2(8, 0), Vector2(16, 0)])
	var spawner := _attach_spawner(root, {"rabbit_spawn_root_path": "Rabbits"})
	add_child_autofree(root)
	await wait_physics_frames(2)
	assert_eq(_living(spawner), 3, "마커 3개 = 최초 3마리")

	## 3마커가 동시에 전멸 → 쿨다운도 동시에 만료된다(최악 조건).
	_kill_all(spawner)
	_tick(spawner, int(MonsterSpawner.NORMAL_RESPAWN_SEC))
	assert_eq(_living(spawner), 1, "동시 만료여도 첫 틱에는 1마커만 스폰")
	_tick(spawner, 1)
	assert_eq(_living(spawner), 2, "다음 틱에 1마커 더")
	_tick(spawner, 1)
	assert_eq(_living(spawner), 3, "그 다음 틱에 남은 1마커")
	GameClock.reset()


# --- 정예 캠프 ---


func test_elite_camp_respawns_as_a_whole_with_longer_cooldown() -> void:
	GameClock.reset()
	var root := _make_root()
	_add_marker_group(root, "ImpLordCamp", [Vector2(0, 0)])
	var spawner := _attach_spawner(root, {"imp_lord_camp_spawn_root_path": "ImpLordCamp"})
	add_child_autofree(root)
	await wait_physics_frames(3)
	assert_eq(_living(spawner, "포효 임프장"), 1, "캠프에는 임프장 1마리")
	assert_between(_living(spawner, "임프"), 2, 3, "호위 일반 임프 2~3마리")

	_kill_all(spawner)
	_tick(spawner, int(MonsterSpawner.NORMAL_RESPAWN_SEC) * 2)
	assert_eq(_living(spawner), 0, "정예 캠프는 일반 쿨다운의 2배가 지나도 돌아오지 않는다")

	_tick(spawner, int(MonsterSpawner.ELITE_RESPAWN_SEC - MonsterSpawner.NORMAL_RESPAWN_SEC * 2))
	assert_eq(
		_living(spawner, "포효 임프장"),
		1,
		"정예 쿨다운(%.0f초) 만료 시 임프장 복귀" % MonsterSpawner.ELITE_RESPAWN_SEC
	)
	assert_between(_living(spawner, "임프"), 2, 3, "호위도 함께 복귀 — spec 7-4 지휘관 셋업이 유지된다")
	GameClock.reset()


func test_elite_cooldown_is_long_enough_to_beat_camping() -> void:
	## 정예 EXP/초 = 2304 / (실측 TTK 24.51초 + 쿨다운) 이 동렙 일반 사냥(약 28.9 EXP/초,
	## Phase D 3-6장)보다 낮아야 정예 캠핑이 억제된다.
	var elite_rate := 2304.0 / (24.51 + MonsterSpawner.ELITE_RESPAWN_SEC)
	assert_lt(elite_rate, 28.9, "정예 캠프 캠핑 효율(%.1f EXP/초)이 일반 사냥(28.9)보다 낮아야 한다" % elite_rate)


# --- 드랍 · 처치 EXP 재등록 ---


func test_respawned_monster_emits_monster_spawned_with_drop_table() -> void:
	GameClock.reset()
	var root := _make_root()
	_add_marker_group(root, "Rabbits", [Vector2(0, 0)])
	var spawner := _attach_spawner(root, {"rabbit_spawn_root_path": "Rabbits"})
	add_child_autofree(root)
	await wait_physics_frames(2)

	## 월드 루트(eastern_frontier_starting_area.gd)가 하는 구독과 동일한 배선.
	var received: Array[MonsterBase] = []
	spawner.monster_spawned.connect(func(monster: MonsterBase) -> void: received.append(monster))

	_kill_all(spawner)
	_tick(spawner, int(MonsterSpawner.NORMAL_RESPAWN_SEC))
	assert_eq(received.size(), 1, "재스폰도 monster_spawned를 발신해야 한다(드랍·EXP 재등록 경로)")
	assert_not_null(
		MonsterDropRegistry.table_for(received[0]), "재스폰된 개체도 MonsterDropRegistry에서 드랍 테이블이 조회돼야 한다"
	)
	GameClock.reset()


# --- 야간 전용 종과의 상호작용 ---


func test_night_only_species_is_excluded_from_respawn_slots() -> void:
	GameClock.reset()
	var root := _make_root()
	_add_marker_group(root, "ShadowSpiders", [Vector2(0, 0), Vector2(8, 0)])
	var spawner := _attach_spawner(
		root, {"shadow_forest_spider_night_spawn_root_path": "ShadowSpiders"}
	)
	add_child_autofree(root)
	await wait_physics_frames(2)
	assert_eq(_living(spawner), 0, "낮에는 그림자 숲거미가 없다")

	## 낮에 아무리 시간이 흘러도 야간 종이 재스폰돼서는 안 된다(슬롯 대상이 아니다).
	_tick(spawner, int(MonsterSpawner.ELITE_RESPAWN_SEC))
	assert_eq(_living(spawner), 0, "야간 전용 종은 낮에 재스폰되지 않는다")

	GameClock.night_started.emit(1)
	await wait_physics_frames(2)
	assert_eq(_living(spawner), 2, "밤에는 마커 수만큼 스폰")

	## 낮 소멸은 queue_free(died 미발신)이므로 재스폰 쿨다운을 걸어서는 안 된다.
	GameClock.day_started.emit(2)
	await wait_physics_frames(2)
	_tick(spawner, int(MonsterSpawner.ELITE_RESPAWN_SEC))
	assert_eq(_living(spawner), 0, "낮 소멸이 재스폰을 유발하지 않는다")
	GameClock.reset()


func test_day_species_keeps_respawning_across_night_transition() -> void:
	GameClock.reset()
	var root := _make_root()
	_add_marker_group(root, "Spiders", [Vector2(0, 0)])
	_add_marker_group(root, "ShadowSpiders", [Vector2(40, 0)])
	var spawner := _attach_spawner(
		root,
		{
			"forest_spider_spawn_root_path": "Spiders",
			"shadow_forest_spider_night_spawn_root_path": "ShadowSpiders",
		}
	)
	add_child_autofree(root)
	await wait_physics_frames(3)
	assert_eq(_living(spawner, "숲거미"), 1, "주간 종은 낮에 스폰돼 있다")

	GameClock.night_started.emit(1)
	await wait_physics_frames(2)
	_kill_all(spawner)
	_tick(spawner, int(MonsterSpawner.NORMAL_RESPAWN_SEC))
	assert_eq(_living(spawner, "숲거미"), 1, "주간 종은 밤에도 정상 재스폰된다")
	assert_eq(_living(spawner, "그림자 숲거미"), 0, "처치된 야간 종은 그 밤 안에 돌아오지 않는다(밤마다 1회 스폰 규격)")
	GameClock.reset()
