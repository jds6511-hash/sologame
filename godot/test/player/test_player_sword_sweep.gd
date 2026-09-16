## 검은 판정 구간 안에서도 중간 베기 자세를 거쳐야 한다.
extends GutTest

var player: PlayerController
var sprite: AnimatedSprite2D


func before_each() -> void:
	player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	sprite = player.get_node("Sprite")


func test_active_sword_moves_through_distinct_poses_for_both_swings() -> void:
	for step in [0, 1]:
		player._start_attack_step(step)
		player.attack_state = PlayerController.AttackState.ACTIVE
		var frames: Array[int] = []
		for progress in [0.0, 0.5, 0.99]:
			player._attack_phase_timer = player.combo_data.steps[step].active_sec * progress
			player._update_visual()
			frames.append(sprite.frame)
		assert_ne(frames[0], frames[1], "판정 전반에 검이 이동해야 한다")
		assert_ne(frames[1], frames[2], "판정 후반에도 검이 이동해야 한다")


func test_sword_pose_does_not_advance_without_action_clock() -> void:
	player._start_attack_step(0)
	player.attack_state = PlayerController.AttackState.ACTIVE
	player._attack_phase_timer = player.combo_data.steps[0].active_sec * 0.5
	player._update_visual()
	var held := sprite.frame
	for index in range(5):
		player._update_visual()
	assert_eq(sprite.frame, held, "히트스톱처럼 판정 시계가 멈추면 검도 멈춘다")


func test_sweep_canvas_keeps_body_center_and_feet() -> void:
	for animation in ["attack_front", "attack_side", "attack_back", "attack2_side"]:
		assert_eq(sprite.sprite_frames.get_frame_count(animation), 8)
		var texture := sprite.sprite_frames.get_frame_texture(animation, 0)
		assert_eq(texture.get_size(), Vector2(64, 64), "몸 확대 없이 무기 회전 여백 확보")
	assert_eq(sprite.offset, Vector2(0, -18), "몸은 기존 중심에 패딩하여 발 위치 유지")
