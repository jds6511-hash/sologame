## 정지한 동일 월드에서 이전 교대 순서와 현행 묶음 순서를 비교한다.
extends RefCounted


static func run(tree: SceneTree, world: Node2D, art: Node2D) -> bool:
	print(
		"SURFACE_PROFILE_CONTEXT ",
		JSON.stringify(
			{
				"engine": Engine.get_version_info().string,
				"vsync_mode": DisplayServer.window_get_vsync_mode(),
				"window_size": str(tree.root.size),
				"warmup_frames": 30,
				"samples": 120,
				"world_disabled": world.process_mode == Node.PROCESS_MODE_DISABLED
			}
		)
	)
	var surface := art.get_node("NativeSurface")
	var grouped := surface.get_children()
	var objects := {}
	for child in grouped:
		if child.has_meta("original_object"):
			objects[child.position] = child
	var alternating: Array[Node] = []
	for child in grouped:
		if child.has_meta("base_kind"):
			alternating.append(child)
			if objects.has(child.position):
				alternating.append(objects[child.position])
	for child in grouped:
		if not child.has_meta("base_kind") and not child.has_meta("original_object"):
			alternating.append(child)
	var passed := true
	var player := world.get_node("Player") as Node2D
	var original_position := player.position
	for position in [Vector2(152, 504), Vector2(152, 200), Vector2(560, 320)]:
		player.position = position
		world.get_node("Player/Camera2D").reset_smoothing()
		_order(surface, alternating)
		var before := await _sample(tree)
		_order(surface, grouped)
		var after := await _sample(tree)
		var identical: bool = before.pixels == after.pixels
		passed = passed and identical
		before.erase("pixels")
		after.erase("pixels")
		print(
			"SURFACE_PROFILE ",
			JSON.stringify(
				{
					"position": str(position),
					"alternating": before,
					"grouped": after,
					"pixels_equal": identical
				}
			)
		)
	player.position = original_position
	world.get_node("Player/Camera2D").reset_smoothing()
	return passed


static func _order(surface: Node, order: Array) -> void:
	for index in range(order.size()):
		surface.move_child(order[index], index)


static func _sample(tree: SceneTree) -> Dictionary:
	for index in range(30):
		await tree.process_frame
	var elapsed: Array[float] = []
	var calls: Array[float] = []
	var last := Time.get_ticks_usec()
	for index in range(120):
		await tree.process_frame
		var now := Time.get_ticks_usec()
		elapsed.append(float(now - last) / 1000.0)
		last = now
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	elapsed.sort()
	calls.sort()
	await RenderingServer.frame_post_draw
	return {
		"frames": 120,
		"frame_interval_p50_ms": elapsed[59],
		"frame_interval_p95_ms": elapsed[113],
		"draw_calls_p50": calls[59],
		"pixels": tree.root.get_texture().get_image().get_data()
	}
