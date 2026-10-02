extends GutTest
## 상태 준비와 상호작용 메서드를 사용하는 API fixture. 실제 키보드 완주 증거는 아니다.
const Content = preload("res://scripts/content/game_content.gd")
const Product = preload("res://scripts/world/game_product.gd")
const Catalog = preload("res://scripts/content/game_catalog.gd")
const Bootstrap = preload("res://scripts/world/game_bootstrap.gd")


func after_each() -> void:
	BgmManager.reset()
	get_tree().paused = false


func make_world(region: String) -> Node:
	var world: Node = Product.instantiate_world(region)
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	freeze_processes(world)
	return world


func freeze_processes(node: Node) -> void:
	# PROCESS_MODE_DISABLED는 충돌체까지 공간에서 빼므로 실제 충돌 검증에는 쓰지 않는다.
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze_processes(child)


func prepared(catalog: QuestCatalog, through: int = 0) -> Dictionary:
	var bootstrap := Bootstrap.new()
	var states: Dictionary = bootstrap.preparation(catalog, 3).quests
	bootstrap.free()
	for number in range(1, through + 1):
		var id := "MQ-03-%02d" % number
		states[id] = {"state": "completed", "counts": Array(catalog.definitions[id].objective_counts)}
	return states


func candidate(world: Node, id: String) -> Node2D:
	for value in world.get_node("WorldInteraction").candidates:
		if "npc_id" in value and value.npc_id == id:
			return value
	return null


func clear_at(player: CharacterBody2D, point: Vector2) -> bool:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = Transform2D(player.global_transform.x, player.global_transform.y, point) * shape.transform
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func segment_clear(player: CharacterBody2D, from: Vector2, to: Vector2) -> bool:
	var transform := player.global_transform
	transform.origin = from
	return clear_at(player, from) and clear_at(player, to) and not player.test_move(transform, to - from)


func test_new_gate_departure_and_return_use_real_player_shape() -> void:
	for region in ["eastern_frontier_start", "yeoulmok_defense"]:
		var world := make_world(region)
		await get_tree().physics_frame
		var player: CharacterBody2D = world.get_node("Player")
		for id in ["yeoulmok_defense_gate", "defense_exit_gate"]:
			var edge: Array = Content.EDGES[id]
			if edge[0] == region:
				var gate := candidate(world, id)
				assert_not_null(gate, id)
				var approach: Vector2 = edge[2] + Vector2(0, 24)
				assert_true(clear_at(player, approach), id + " 접근 위치")
				assert_true(segment_clear(player, approach + Vector2(0, 16), approach), id + " 접근 동선")
				player.global_position = approach
				assert_true(gate.can_interact(), id + " 실제 대화 거리/시야")
			if edge[1] == region:
				assert_true(clear_at(player, edge[3]), id + " 도착 위치")
				assert_true(segment_clear(player, edge[3], edge[3] + Vector2(16, 0)), id + " 도착 후 이동")
		world.free()
		await get_tree().process_frame


func test_defense_points_are_reachable_with_actual_shape_from_safe_arrival() -> void:
	var world := make_world("yeoulmok_defense")
	await get_tree().physics_frame
	var player: CharacterBody2D = world.get_node("Player")
	var start: Vector2 = Content.EDGES["yeoulmok_defense_gate"][3]
	assert_false(clear_at(player, Vector2(0, 320)), "경계 충돌이 활성 상태인지 양성 대조")
	assert_false(segment_clear(player, start, Vector2(-16, start.y)), "실제 몸체는 경계를 통과하지 못한다")
	var points: Array[Vector2] = []
	for value in world.get_node("WorldInteraction").candidates:
		if value is Node2D:
			points.append(value.global_position + Vector2(0, 24))
	for wave in Content.DEFENSE_WAVES.values():
		for point in wave.points:
			points.append(point)
	for point in points:
		# 열린 전장은 안전 집결지의 수평선과 목표 세로선을 잇는 실제 몸체 이동으로 확인한다.
		var bend := Vector2(point.x, start.y)
		assert_true(segment_clear(player, start, bend), "수평 접근 " + str(point))
		assert_true(segment_clear(player, bend, point), "세로 접근 " + str(point))
	world.free()
	await get_tree().process_frame


func test_gatewarden_report_and_accept_take_priority_over_travel() -> void:
	var catalog := Catalog.new()
	var states := prepared(catalog)
	states["MQ-03-01"] = {"state": "ready", "counts": [1]}
	var report: Dictionary = catalog.selected_view(states, "yeoulmok_gatewarden", "")
	assert_eq(report.quest_id, "MQ-03-01")
	assert_eq(report.action, "report")
	states["MQ-03-01"].state = "completed"
	var offer: Dictionary = catalog.selected_view(states, "yeoulmok_gatewarden", "")
	assert_eq(offer.quest_id, "MQ-03-02")
	assert_eq(offer.action, "accept")


func test_shadow_interaction_acquires_and_releases_real_dialog_pause() -> void:
	var world := make_world("yeoulmok_defense")
	var controller: QuestController = world.get_node("QuestController")
	var states := prepared(controller.journal.catalog, 3)
	states["MQ-03-04"] = {"state": "active", "counts": [1, 0]}
	assert_eq(controller.journal.restore_state(states), "")
	var site := candidate(world, "yeoulmok_shadow_trace")
	assert_not_null(site)
	world.get_node("Player").global_position = site.global_position + Vector2(0, 24)
	await get_tree().physics_frame
	assert_false(get_tree().paused)
	assert_true(site.interact())
	var dialog: QuestDialog = world.get_node("QuestDialog")
	assert_true(dialog.panel.visible)
	assert_true(get_tree().paused)
	assert_same(dialog._arbiter._holder, dialog)
	assert_eq(dialog._message.text, Content.SITE_NOTICES.yeoulmok_shadow_trace)
	assert_eq(controller.journal.export_state()["MQ-03-04"].state, "ready")
	dialog.choose("close")
	assert_false(dialog.panel.visible)
	assert_false(get_tree().paused)
	assert_null(dialog._arbiter._holder)
	assert_false(site.interact(), "완료 표식 재입력은 목격창을 반복하지 않는다")
	world.free()
	await get_tree().process_frame
