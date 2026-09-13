extends SceneTree
## 실제 플레이어의 단계별 자세를 렌더링한다. 원본 에셋·프로젝트 설정은 변경하지 않는다.

const OUTPUT := "res://../docs/qa/screenshots/attack-motion/"
var stage: Node2D
var player_scene: PackedScene


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	player_scene = load("res://scenes/player/player.tscn")
	stage = Node2D.new()
	root.add_child(stage)
	var jobs := ["adventurer", "warrior", "archer", "gladiator"]
	for row in range(jobs.size()):
		var player = player_scene.instantiate()
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
	_clear_projectiles()
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(OUTPUT).simplify_path()
	DirAccess.make_dir_recursive_absolute(directory)
	var error := root.get_texture().get_image().save_png(directory.path_join("phases.png"))
	print("[모션 완료] 4직업 × 3방향 × 5시점, 캡처 결과: %s" % error)
	var travel_ok := await _capture_travel_skills()
	var charge_ok := await _capture_charge_pose()
	var archer_ok := await _capture_archer_poses()
	quit(0 if error == OK and travel_ok and charge_ok and archer_ok else 1)


func _capture_archer_poses() -> bool:
	for child in stage.get_children():
		child.queue_free()
	await process_frame
	var definition = load("res://data/jobs/job_def_archer.tres")
	var frames: SpriteFrames = definition.sprite_frames
	var animations := ["attack_front", "attack_side", "attack_back", "rollshot_back"]
	for row in range(animations.size()):
		_label(animations[row], Vector2(30, 30 + row * 240))
		for column in range(frames.get_frame_count(animations[row])):
			var pose := Sprite2D.new()
			pose.texture = frames.get_frame_texture(animations[row], column)
			pose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pose.scale = Vector2(4, 4)
			pose.position = Vector2(300 + column * 200, 110 + row * 240)
			stage.add_child(pose)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUTPUT).path_join("archer-fixed.png")
	var error := root.get_texture().get_image().save_png(path)
	print("[궁수 캡처] 공격 3방향 + 곡예 사격 후면, 결과=%s" % error)
	return error == OK


func _capture_charge_pose() -> bool:
	for child in stage.get_children():
		child.queue_free()
	await process_frame
	var player = player_scene.instantiate()
	stage.add_child(player)
	player.set_physics_process(false)
	player.hide()
	player._is_charging_secondary = true
	for row in range(3):
		player.get_node("Facing").rotation = [PI / 2.0, 0.0, -PI / 2.0][row]
		player._update_visual()
		var source: AnimatedSprite2D = player.get_node("Sprite")
		_label(["정면", "측면", "후면"][row], Vector2(30, 40 + row * 230))
		for column in range(2):
			var pose := Sprite2D.new()
			pose.texture = source.sprite_frames.get_frame_texture(source.animation, column)
			pose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pose.scale = Vector2(4, 4)
			pose.position = Vector2(300 + column * 200, 110 + row * 230)
			stage.add_child(pose)
	player.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUTPUT).path_join("charge-fixed.png")
	var error := root.get_texture().get_image().save_png(path)
	print("[차지 캡처] 3방향 × 2프레임, 결과=%s" % error)
	return error == OK


func _capture_travel_skills() -> bool:
	for child in stage.get_children():
		child.queue_free()
	await process_frame
	var passed := true
	var jobs := ["warrior", "archer", "gladiator"]
	for row in range(jobs.size()):
		var player = player_scene.instantiate()
		stage.add_child(player)
		player.set_physics_process(false)
		player.hide()
		var definition = load("res://data/jobs/job_def_%s.tres" % jobs[row])
		player.visual.set_job_sprite_frames(definition.sprite_frames)
		player._last_move_direction = Vector2.UP
		player.get_node("Facing").rotation = 0.0
		var skill = definition.skill_slot_q if row == 2 else definition.skill_slot_2
		player._skills.start(skill)
		_label("%s / %s" % [jobs[row], skill.skill_name], Vector2(15, 30 + row * 230))
		for column in range(3):
			if column == 1:
				player._skills.process_state(skill.startup_sec)
			elif column == 2:
				player._skills.process_state(skill.get_active_duration_sec())
			player._update_visual()
			var source: AnimatedSprite2D = player.get_node("Sprite")
			var valid := source.animation == &"dodge_back" and source.frame == column
			passed = passed and valid
			print("[돌진 검사] %s 단계%d: %s" % [jobs[row], column, valid])
			var pose := Sprite2D.new()
			pose.texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
			pose.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pose.scale = Vector2(4, 4)
			pose.position = Vector2(400 + column * 200, 110 + row * 230)
			stage.add_child(pose)
			_label(["선딜", "돌진", "착지"][column], pose.position + Vector2(-20, 80))
		player.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUTPUT).path_join("travel-skills.png")
	var error := root.get_texture().get_image().save_png(path)
	print("[돌진 완료] 검사9건, 통과=%s, 캡처=%s" % [passed, error])
	return passed and error == OK


func _clear_projectiles() -> void:
	# 단계 진행 중 생긴 화살은 비교용 자세 표에 포함하지 않는다.
	for child in root.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == "res://scripts/player/arrow_projectile.gd":
			child.queue_free()


func _label(value: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	stage.add_child(label)
