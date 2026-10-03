extends GutTest
## 실제 형상 경로·생성·사망 신호 검사. 사람 입력 전투·체감 검증과 구분한다.
const Content = preload("res://scripts/content/game_content.gd")
const Product = preload("res://scripts/world/game_product.gd")


func after_each() -> void:
	BgmManager.reset()
	GameClock.reset()
	get_tree().paused = false


func frame_bounded(frame_signal: Signal, label: String) -> void:
	var state := {"seen": false}
	var arrived := func(): state.seen = true
	frame_signal.connect(arrived, CONNECT_ONE_SHOT)
	await wait_until(func(): return state.seen, 2.0, label)
	if frame_signal.is_connected(arrived):
		frame_signal.disconnect(arrived)
	assert_false(did_wait_timeout(), label)


func test_each_region_has_sources_npcs_and_spawned_enemy_stats() -> void:
	for region in ["suretgul", "valkren", "old_front", "valkren_rift"]:
		var world: Node = Product.instantiate_world(region)
		assert_not_null(world, region)
		if world == null:
			continue
		world.set_meta("save_directory", "user://product_verify")
		add_child(world)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		var ids := []
		for candidate in world.get_node("WorldInteraction").candidates:
			if "npc_id" in candidate:
				ids.append(candidate.npc_id)
		for id in Content.NPCS:
			if Content.NPCS[id][0] == region:
				assert_has(ids, id)
		for id in Content.SITES:
			if Content.SITES[id][4] == region:
				assert_has(ids, id)
		for id in Content.ENCOUNTERS:
			if Content.ENCOUNTERS[id].region == region:
				assert_has(ids, id, "전장 소집 표식")
				assert_false(Content.SITES.has(id), "일반 현장 표식으로 우회 불가")
		var expected := 0
		for habitat in Content.HABITATS.values():
			if habitat[0] == region:
				expected += habitat[1].size()
		if world.has_node("EncounterController"):
			expected = mini(expected, 4)
		assert_eq(world.get_node("MonsterSpawner").get_child_count(), expected, region)
		if region in ["valkren", "valkren_rift"]:
			assert_eq(expected, 0, "대피·군후는 입장으로 자동 생성하지 않는다")
		var progression: PlayerProgression = world.get_node("Player/PlayerProgression")
		var emissions := {"exp": 0, "gold": 0}
		progression.exp_changed.connect(func(_current, _next): emissions.exp += 1)
		var drops: DropSystem = world.get_node("DropSystem")
		drops.gold_dropped.connect(func(_amount, _position): emissions.gold += 1)
		for monster in world.get_node("MonsterSpawner").get_children():
			var id: String = monster.get_meta("content_id", "")
			assert_true(Content.MONSTER_VARIANTS.has(id))
			if Content.MONSTER_VARIANTS.has(id):
				assert_eq(monster.stats.display_name, Content.MONSTER_VARIANTS[id].title)
				assert_eq(
					MonsterDropRegistry.table_for(monster).monster_level,
					Content.MONSTER_VARIANTS[id].level
				)
				assert_almost_eq(monster.hp, monster.effective_max_hp(), 0.01)
				assert_almost_eq(
					monster.effective_attack_power(),
					monster.stats.attack_power * GameClock.get_monster_stat_multiplier(false),
					0.01
				)
				var count: int = emissions.exp
				var gold_count: int = emissions.gold
				monster.take_damage(monster.effective_max_hp() * 10.0)
				monster.take_damage(monster.effective_max_hp() * 10.0)
				assert_eq(emissions.gold, gold_count + 1)
				assert_eq(emissions.exp, count + 1)
		world.free()
		await frame_bounded(get_tree().process_frame, region + " 생성 검사 뒤 프레임")


func freeze_processes(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze_processes(child)


func test_routes_to_all_sites_and_gates_use_actual_player_shape() -> void:
	for region in ["jaetgol", "suretgul", "valkren", "old_front", "valkren_rift"]:
		var world: Node = Product.instantiate_world(region)
		world.set_meta("save_directory", "user://product_verify")
		add_child(world)
		freeze_processes(world)
		for frame in 2:
			await frame_bounded(get_tree().physics_frame, region + " 물리 동기화")
			if did_wait_timeout():
				world.free()
				return
		var player: CharacterBody2D = world.get_node("Player")
		var reachable := reachable_points(player, Content.BOUNDS[region])
		var points := []
		for habitat in Content.HABITATS.values():
			if habitat[0] == region:
				for spawn: Vector2 in habitat[1]:
					points.append(spawn + Vector2(0, 32))
		for arrival_edge in Content.EDGES.values():
			if arrival_edge[1] == region:
				points.append(arrival_edge[3])
		for id in Content.NPCS:
			if Content.NPCS[id][0] == region:
				points.append(Content.NPCS[id][1] + Vector2(0, 24))
		for site in Content.SITES.values():
			if site[4] == region:
				points.append(site[0] + Vector2(0, 24))
		for edge in Content.EDGES.values():
			if edge[0] == region:
				points.append(edge[2] + Vector2(0, 24))
		for encounter in Content.ENCOUNTERS.values():
			if encounter.region == region:
				points.append(encounter.position + Vector2(0, 24))
				for spawn: Vector2 in encounter.points:
					points.append(spawn)
		for point in points:
			var reached := false
			for step: Vector2 in reachable:
				if step.distance_to(point) > 48.0:
					continue
				var transform := player.global_transform
				transform.origin = step
				if not player.test_move(transform, point - step):
					reached = true
					break
			assert_true(reached, region + " 실제 플레이어 충돌 경로: " + str(point))
		world.free()
		await frame_bounded(get_tree().process_frame, region + " 경로 검사 뒤 프레임")


func reachable_points(player: CharacterBody2D, bounds: Rect2) -> Array[Vector2]:
	# 물·책장은 통과하지 않고 실제 플레이어 형상으로 우회한다.
	var queue: Array[Vector2] = [player.global_position]
	var visited := {player.global_position: true}
	var head := 0
	while head < queue.size():
		var point := queue[head]
		head += 1
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var next: Vector2 = point + direction * 32.0
			if visited.has(next) or not bounds.grow(-32).has_point(next):
				continue
			var transform := player.global_transform
			transform.origin = point
			if player.test_move(transform, next - point):
				continue
			visited[next] = true
			queue.append(next)
	return queue


func test_active_evacuation_blocks_save_and_successful_travel_suspends() -> void:
	var world: Node = Product.instantiate_world("valkren")
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	freeze_processes(world)
	var journal: QuestJournal = world.get_node("QuestController").journal
	var prepared := {}
	for id in journal.catalog.ordered_ids():
		if Content.QUEST_REVISIONS[id] < 8 or id == "MQ-09-01":
			prepared[id] = {
				"state": "completed",
				"counts": Array(journal.catalog.definitions[id].objective_counts)
			}
	assert_eq(journal.restore_state(prepared), "")
	assert_eq(world.get_node("QuestController").accept("MQ-09-02"), "")
	var manager = world.get_node("EncounterController")
	var player = world.get_node("Player")
	player.position = Content.ENCOUNTERS.valkren_evac_west.position
	assert_true(manager.resume("valkren_evac_west"))
	assert_eq(load("res://scripts/save/save_safety.gd").blocked_reason(world), "encounter_active")
	var session = world.get_node("SaveSession")
	var rejected: Dictionary = session.travel("suretgul")
	assert_false(rejected.ok, "관문 밖 이동은 실패")
	assert_true(manager.active, "실패한 이동은 대피 진행을 취소하지 않는다")
	player.position = Content.edge("valkren", "suretgul")[2]
	var moved: Dictionary = session.travel("suretgul")
	assert_true(moved.ok, moved.code)
	if moved.ok:
		assert_false(manager.active, "성공 이동은 분리 전 전장을 중단한다")
		for enemy in manager.targets():
			assert_true(enemy.is_queued_for_deletion())
		var destination: Node
		for child in get_children():
			if child.has_node("SaveSession") and child != world:
				destination = child
		assert_not_null(destination, "같은 부모 아래 교체 월드 생성")
		if destination != null:
			assert_eq(destination.map_id, "suretgul")
			assert_eq(destination.get_node("SaveSession").store.root, "user://product_verify")
			destination.free()
	else:
		world.free()
	await frame_bounded(get_tree().process_frame, "전장 이동 후 정리")


func test_natural_respawn_shares_encounter_capacity_and_waits_during_active_session() -> void:
	var world: Node = Product.instantiate_world("old_front")
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	freeze_processes(world)
	var manager = world.get_node("EncounterController")
	var spawner = world.get_node("ContentSpawner")
	var holder = world.get_node("MonsterSpawner")
	assert_eq(holder.get_child_count(), 4, "자연 생성도 전장 전체 상한4")
	var sources := {}
	for monster in holder.get_children():
		var source: String = monster.get_meta("spawn_source_id")
		sources[source] = int(sources.get(source, 0)) + 1
	assert_eq(sources.get("old_front_scouts", 0), 2, "필수 서브 표적 접근")
	assert_eq(sources.get("old_front_wraiths", 0), 2, "망령 표적을 초기 정원에서 배제하지 않는다")
	spawner._process(100.0)
	assert_eq(holder.get_child_count(), 4, "대기 슬롯도 정원을 넘지 않는다")
	for monster in holder.get_children():
		monster.free()
	manager.active = true
	spawner._process(100.0)
	assert_eq(holder.get_child_count(), 0, "활성 전장에 자연 재생성이 끼어들지 않는다")
	manager.active = false
	spawner._process(0.1)
	assert_eq(holder.get_child_count(), 4, "전장 종료 후 준비된 슬롯을 정원 안에서 재생성")
	world.free()
	await frame_bounded(get_tree().process_frame, "공유 재생성 정원 검사 정리")
