extends SceneTree
## 실제 플레이어의 단계별 자세를 렌더링한다. 원본 에셋·프로젝트 설정은 변경하지 않는다.

const OUTPUT := "res://../docs/qa/screenshots/attack-motion/"
var stage: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	stage = Node2D.new()
	root.add_child(stage)
	var jobs := ["adventurer", "warrior", "archer", "gladiator"]
	for row in range(jobs.size()):
		var player = load("res://scenes/player/player.tscn").instantiate()
		stage.add_child(player)
		player.position = Vector2(960, 540)
		player.set_physics_process(false)
		player.hide()
		var job: String = jobs[row]
		var combo_job := "warrior" if job == "gladiator" else job
		player.combo_data = load("res://data/player/%s_basic_combo.tres" % combo_job)
		if job != "adventurer":
			var definition = load("res://data/jobs/job_def_%s.tres" % job)
			player.visual.set_job_sprite_frames(definition.sprite_frames)
		_label(job, Vector2(15, row * 240 + 15))
		for direction in range(3):
			player.get_node("Facing").rotation = [0.0, PI / 2.0, -PI / 2.0][direction]
			var aim := Vector2.RIGHT.rotated(player.get_node("Facing").rotation) * 100.0
			var motion := InputEventMouseMotion.new()
			motion.position = player.get_global_transform_with_canvas() * aim
			motion.global_position = motion.position
			root.push_input(motion, true)
			root.warp_mouse(motion.position)
			player._start_attack_step(0)
			var step = player.combo_data.steps[0]
			for column in range(5):
				if column == 1:
					player._process_attack_state(step.startup_sec * 0.75)
				elif column == 2:
					player._process_attack_state(step.startup_sec * 0.25 + 0.00001)
				elif column == 3:
					player._process_attack_state(step.active_sec)
				elif column == 4:
					player._process_attack_state(step.recovery_sec * 0.75)
				player._update_visual()
				var source: AnimatedSprite2D = player.get_node("Sprite")
				var pose := Sprite2D.new()
				pose.texture = source.sprite_frames.get_frame_texture(
					source.animation, source.frame
				)
				pose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				pose.scale = Vector2(2, 2)
				pose.position = Vector2(230 + column * 145, 55 + row * 240 + direction * 75)
				stage.add_child(pose)
				print("[모션] %s 방향%d 단계%d 프레임%d" % [job, direction, column, source.frame])
		player.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(OUTPUT).simplify_path()
	DirAccess.make_dir_recursive_absolute(directory)
	var error := root.get_texture().get_image().save_png(directory.path_join("phases.png"))
	print("[모션 완료] 4직업 × 3방향 × 5시점, 캡처 결과: %s" % error)
	quit(0 if error == OK else 1)


func _label(value: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	stage.add_child(label)
