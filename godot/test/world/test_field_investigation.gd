extends GutTest
## 실제 월드·충돌·대화 API 검사. 사람 입력 완주 증거는 아니다.
const Product = preload("res://scripts/world/game_product.gd")
const Content = preload("res://scripts/content/game_content.gd")
const Bootstrap = preload("res://scripts/world/game_bootstrap.gd")


func after_each() -> void:
	BgmManager.reset()
	get_tree().paused = false


func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze(child)


func clear_at(player: CharacterBody2D, point: Vector2) -> bool:
	var shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = (
		Transform2D(player.global_transform.x, player.global_transform.y, point) * shape.transform
	)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func fixture(id: String) -> Dictionary:
	var data: Array = Content.SITES[id]
	var world: Node = Product.instantiate_world(data[4])
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	freeze(world)
	var journal: QuestJournal = world.get_node("QuestController").journal
	var chapter := 5 if id == "marsh_route" else 6
	var bootstrap := Bootstrap.new()
	var states: Dictionary = bootstrap.preparation(journal.catalog, chapter).quests
	bootstrap.free()
	for number in range(1, 3):
		var main := "MQ-%02d-%02d" % [chapter, number]
		states[main] = {
			"state": "completed", "counts": Array(journal.catalog.definitions[main].objective_counts)
		}
	var quest := "MQ-05-03" if chapter == 5 else "SQ-06-008"
	states[quest] = {"state": "active", "counts": [3, 1, 0] if chapter == 5 else [0, 0]}
	assert_eq(journal.restore_state(states), "")
	var site: Node2D
	for candidate in world.get_node("WorldInteraction").candidates:
		if "npc_id" in candidate and candidate.npc_id == id:
			site = candidate
	return {"world": world, "site": site, "journal": journal, "quest": quest}


func test_site_opens_observation_without_giving_progress() -> void:
	var f := fixture("marsh_route")
	f.world.get_node("Player").global_position = f.site.global_position
	await get_tree().physics_frame
	assert_true(f.site.interact())
	assert_eq(f.journal.export_state()[f.quest].counts, [3, 1, 0])
	assert_true(get_tree().paused)
	f.world.get_node("QuestDialog").close_dialog()
	f.world.free()
	await get_tree().process_frame


func test_two_sites_require_correct_physical_clue_and_keep_completed_saves() -> void:
	for id in ["marsh_route", "mosswood_water"]:
		var f := fixture(id)
		var field: Node = f.site.get_node_or_null("FieldInvestigation")
		assert_not_null(field)
		if field == null:
			f.world.free()
			continue
		var player: CharacterBody2D = f.world.get_node("Player")
		var dialog = f.world.get_node("QuestDialog")
		var before: Dictionary = f.journal.export_state()
		player.global_position = f.site.global_position
		await get_tree().physics_frame
		assert_true(f.site.interact())
		dialog.close_dialog()
		for clue in field.clues:
			var from: Vector2 = f.site.global_position + Vector2(0, 24)
			var to: Vector2 = clue.global_position + Vector2(0, 24)
			var transform := player.global_transform
			transform.origin = from
			assert_true(clear_at(player, from), "현장 출발 충돌 없음")
			assert_true(clear_at(player, to), "단서 도착 충돌 없음")
			assert_false(player.test_move(transform, to - from), id + " 단서 실제 몸체 경로")
		var wrong: Node2D = field.clues[(field.correct_index + 1) % 3]
		player.global_position = wrong.global_position
		assert_true(wrong.interact())
		assert_eq(f.journal.export_state(), before, "틀린 단서는 진행하지 않는다")
		dialog.close_dialog()
		var correct: Node2D = field.clues[field.correct_index]
		assert_false(correct.interact(), "먼 단서 원격 입력 금지")
		assert_false(field.choose(field.correct_index), "helper 원격 입력도 금지")
		player.global_position = correct.global_position
		assert_true(correct.interact())
		dialog.close_dialog()
		var saved: Dictionary = f.journal.export_state()
		assert_ne(saved, before)
		assert_eq(saved[f.quest].counts[2 if id == "marsh_route" else 0], 1)
		assert_false(correct.interact(), "중복 이벤트 없음")
		assert_eq(f.journal.export_state(), saved)
		assert_true(field.solved)
		assert_eq(f.journal.restore_state(saved), "")
		assert_true(field.solved, "기존 완료 카운트로 현장 결과 복원")
		assert_false(correct.can_interact())
		assert_eq(f.journal.restore_state(before), "")
		assert_false(field.solved, "다른 저장을 불러오면 완료 표시 해제")
		f.world.free()
		await get_tree().process_frame
		var restored := fixture(id)
		assert_eq(restored.journal.restore_state(saved), "")
		var restored_field: Node = restored.site.get_node("FieldInvestigation")
		assert_true(restored_field.solved, "현장 재진입 시 완료 연결선 복원")
		assert_false(restored_field.clues[restored_field.correct_index].can_interact())
		restored.world.free()
		await get_tree().process_frame


func test_investigation_cannot_bypass_prior_objective_or_start_remotely() -> void:
	var f := fixture("marsh_route")
	var field: Node = f.site.get_node_or_null("FieldInvestigation")
	assert_not_null(field)
	if field == null:
		f.world.free()
		return
	var player: Node2D = f.world.get_node("Player")
	var states: Dictionary = f.journal.export_state()
	states[f.quest].counts = [3, 0, 0]
	assert_eq(f.journal.restore_state(states), "")
	player.global_position = f.site.global_position
	await get_tree().physics_frame
	assert_false(f.site.interact())
	var clue: Node2D = field.clues[field.correct_index]
	player.global_position = clue.global_position
	assert_false(clue.interact())
	assert_eq(f.journal.export_state(), states)
	f.world.free()
	await get_tree().process_frame
