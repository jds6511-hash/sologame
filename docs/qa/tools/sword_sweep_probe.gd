extends SceneTree
## 실제 판정 시계로 3방향·좌우 반전의 기본 2타를 60Hz 샘플링한다.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(960, 540)
	var output := ProjectSettings.globalize_path("res://../docs/qa/screenshots/sword-sweep/runtime")
	DirAccess.make_dir_recursive_absolute(output)
	var players: Array = []
	var angles := [0.0, PI, PI / 2.0, -PI / 2.0]
	for index in range(4):
		var player = load("res://scenes/player/player.tscn").instantiate()
		root.add_child(player)
		player.set_physics_process(false)
		player.position = Vector2(130 + index * 230, 320)
		player.scale = Vector2(3, 3)
		player.get_node("MeleeSwingVfx").set_process(false)
		players.append(player)
	var label := Label.new()
	label.position = Vector2(20, 25)
	root.add_child(label)
	var sample := 0
	for step in [0, 1]:
		for index in range(4):
			players[index]._start_attack_step(step)
			players[index].get_node("Facing").rotation = angles[index]
			players[index]._last_move_direction = Vector2.RIGHT.rotated(angles[index])
		for tick in range(28):
			label.text = "검 %d타 | %.3fs | 우 / 좌 / 정면 / 후면" % [step + 1, tick / 60.0]
			for player in players:
				player._update_visual()
				player.get_node("MeleeSwingVfx")._process(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("%03d.png" % sample))
			sample += 1
			for player in players:
				player._process_attack_state(1.0 / 60.0)
	for player in players:
		player.queue_free()
	await process_frame
	print("[검 연속 렌더] 2타 × 4방향, 60Hz 56샘플 저장")
	quit()
