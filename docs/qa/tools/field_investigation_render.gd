## 합성 의뢰 상태·순간 위치 배치 렌더. 실제 도보 플레이 증거는 아니다.
extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze(child)


func run() -> void:
	var content = load("res://scripts/content/game_content.gd")
	for id in ["marsh_route", "mosswood_water"]:
		var world: Node = load("res://scripts/world/game_product.gd").instantiate_world(
			content.SITES[id][4]
		)
		world.set_meta("save_directory", "user://product_verify")
		root.add_child(world)
		current_scene = world
		freeze(world)
		var journal: QuestJournal = world.get_node("QuestController").journal
		var chapter := 5 if id == "marsh_route" else 6
		var bootstrap = load("res://scripts/world/game_bootstrap.gd").new()
		var states: Dictionary = bootstrap.preparation(journal.catalog, chapter).quests
		bootstrap.free()
		for number in range(1, 3):
			var main := "MQ-%02d-%02d" % [chapter, number]
			states[main] = {
				"state": "completed", "counts": Array(journal.catalog.definitions[main].objective_counts)
			}
		var quest := "MQ-05-03" if chapter == 5 else "SQ-06-008"
		states[quest] = {"state": "active", "counts": [3, 1, 0] if chapter == 5 else [0, 0]}
		assert(journal.restore_state(states) == "")
		var site: Node2D
		for candidate in world.get_node("WorldInteraction").candidates:
			if "npc_id" in candidate and candidate.npc_id == id:
				site = candidate
		var player: Node2D = world.get_node("Player")
		player.global_position = site.global_position + Vector2(0, 24)
		var camera: Camera2D = player.get_node("Camera2D")
		camera.reset_smoothing()
		camera.force_update_scroll()
		await physics_frame
		assert(site.interact())
		await capture(id + "-notice")
		world.get_node("QuestDialog").close_dialog()
		await capture(id + "-choices")
		var field: Node = site.get_node("FieldInvestigation")
		player.global_position = field.clues[field.correct_index].global_position
		assert(field.clues[field.correct_index].interact())
		world.get_node("QuestDialog").close_dialog()
		await capture(id + "-solved")
		world.free()
		root.get_node("BgmManager").reset()
		await process_frame
	print("FIELD_INVESTIGATION_RENDER_PASS")
	quit()


func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://../docs/qa/screenshots/field-investigation")
	DirAccess.make_dir_recursive_absolute(directory)
	assert(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK)
