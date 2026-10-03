extends GutTest

var player: PlayerController


func before_each() -> void:
	PlayerController.run_toggle_mode = false
	player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)


func after_each() -> void:
	PlayerController.run_toggle_mode = false
	Input.action_release("walk_toggle")
	Input.action_release("move_right")
	Input.action_release("skill_secondary")


func test_toggle_is_cleared_by_pause_and_death_without_accelerating_aim() -> void:
	PlayerController.run_toggle_mode = true
	Input.action_press("walk_toggle")
	player._update_run_input()
	Input.action_release("walk_toggle")
	var normal := player.movement_data.get_walk_speed_px_per_sec()
	assert_almost_eq(player._resolve_move_speed_px(false), normal * 1.5, 0.001)
	player._shots.refresh_stance(load("res://data/player/skills/archer/skill_secondary_aim_mode.tres"))
	Input.action_press("skill_secondary")
	player._shots.update_stance()
	assert_almost_eq(player._resolve_move_speed_px(false), normal * 0.4, 0.001)
	Input.action_release("skill_secondary")
	player._shots.update_stance()
	player._notification(Node.NOTIFICATION_PAUSED)
	assert_almost_eq(player._resolve_move_speed_px(false), normal, 0.001)
	Input.action_press("walk_toggle")
	player._update_run_input()
	Input.action_release("walk_toggle")
	player.is_input_locked = true
	player._physics_process(1.0 / 60.0)
	assert_false(player._run_latched)


func test_run_keeps_slow_and_does_not_spend_dash_charge() -> void:
	Input.action_press("walk_toggle")
	player._move_slow_percent = 0.5
	assert_almost_eq(
		player._resolve_move_speed_px(false),
		player.movement_data.get_walk_speed_px_per_sec() * 0.75,
		0.001
	)
	assert_eq(player.dash_charges, player.movement_data.dash_charge_max)


func test_shift_increases_normal_movement_but_not_attack() -> void:
	var normal := player.movement_data.get_walk_speed_px_per_sec()
	Input.action_press("walk_toggle")
	assert_almost_eq(player._resolve_move_speed_px(false), normal * 1.5, 0.001)
	assert_almost_eq(player._resolve_move_speed_px(true), normal * 0.45, 0.001)
	Input.action_press("move_right")
	player._physics_process(1.0 / 60.0)
	assert_almost_eq(player.velocity.x, normal * 1.5, 0.001)
	Input.action_release("walk_toggle")
	assert_almost_eq(player._resolve_move_speed_px(false), normal, 0.001)


func test_arrow_reach_preserves_speed_and_ultimate() -> void:
	var basic = load("res://data/player/arrows/arrow_basic.tres")
	var aimed = load("res://data/player/arrows/arrow_aimed.tres")
	var skill = load("res://data/player/arrows/arrow_skill.tres")
	var ultimate = load("res://data/player/arrows/arrow_piercing_burst.tres")
	assert_eq(basic.range_tiles, 10.0)
	assert_eq(aimed.range_tiles, 12.0)
	assert_eq(skill.range_tiles, 10.5)
	assert_eq(ultimate.range_tiles, 12.0)
