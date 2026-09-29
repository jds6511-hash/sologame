## 합성 테스트 프레임은 방향 선택/전환만 검증한다. 실제 오른손 원화 검수가 아니다.
extends GutTest

var player: PlayerController
var sprite: AnimatedSprite2D


func before_each() -> void:
	player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	sprite = player.get_node("Sprite")


func _left_fixture() -> SpriteFrames:
	var frames := sprite.sprite_frames.duplicate() as SpriteFrames
	for animation in frames.get_animation_names():
		if not animation.ends_with("_side"):
			continue
		var left := animation.trim_suffix("_side") + "_left"
		if frames.has_animation(left):
			frames.remove_animation(left)
		frames.add_animation(left)
		frames.set_animation_speed(left, frames.get_animation_speed(animation))
		frames.set_animation_loop(left, frames.get_animation_loop(animation))
		for index in frames.get_frame_count(animation):
			frames.add_frame(left, frames.get_frame_texture(animation, index))
	return frames


func test_complete_left_uses_unflipped_walk_and_attack_clock() -> void:
	sprite.sprite_frames = _left_fixture()
	player._move_input = Vector2.LEFT
	player._last_move_direction = Vector2.LEFT
	player._update_visual()
	assert_eq(sprite.animation, &"walk_left")
	assert_false(sprite.flip_h)
	player._move_input = Vector2.ZERO
	player._start_attack_step(0)
	player.get_node("Facing").rotation = PI
	player.attack_state = PlayerController.AttackState.ACTIVE
	player._attack_phase_timer = player.combo_data.steps[0].active_sec * 0.5
	player._update_visual()
	assert_eq(sprite.animation, &"attack_left")
	assert_false(sprite.flip_h)
	assert_eq(sprite.frame, 3)


func test_incomplete_left_never_mixes_left_walk_with_mirrored_attack() -> void:
	var frames := _left_fixture()
	frames.remove_animation(&"attack_left")
	sprite.sprite_frames = frames
	player._move_input = Vector2.LEFT
	player._last_move_direction = Vector2.LEFT
	player._update_visual()
	assert_eq(sprite.animation, &"walk_side")
	assert_true(sprite.flip_h)


func test_mismatched_left_frame_count_is_not_used() -> void:
	var frames := _left_fixture()
	frames.remove_frame(&"attack_left", 7)
	sprite.sprite_frames = frames
	player._move_input = Vector2.LEFT
	player._update_visual()
	assert_eq(sprite.animation, &"walk_side")
	assert_true(sprite.flip_h)


func test_complete_left_does_not_change_right_or_front() -> void:
	sprite.sprite_frames = _left_fixture()
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		player._move_input = direction
		player._update_visual()
		var expected := "walk_left" if direction == Vector2.LEFT else "walk_side"
		if direction == Vector2.DOWN:
			expected = "walk_front"
		assert_eq(str(sprite.animation), expected)
		assert_false(sprite.flip_h)


func test_mismatched_timing_never_enables_partial_left() -> void:
	for change_loop in [true, false]:
		var frames := _left_fixture()
		if change_loop:
			frames.set_animation_loop(&"walk_left", false)
		else:
			frames.set_animation_speed(&"walk_left", 1.0)
		sprite.sprite_frames = frames
		player._move_input = Vector2.LEFT
		player._update_visual()
		assert_eq(sprite.animation, &"walk_side")
		assert_true(sprite.flip_h)
