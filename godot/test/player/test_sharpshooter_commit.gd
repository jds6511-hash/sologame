extends GutTest

const JOB = preload("res://data/jobs/job_def_sharpshooter.tres")
var player: PlayerController


func before_each() -> void:
	player = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	player.apply_transition_loadout(JOB.skill_loadout(), JOB.basic_combo)
	player._stats.stats.max_mp = 200.0
	player._stats.current_mp = 200.0


func test_failed_or_cancelled_precision_spends_nothing() -> void:
	assert_false(player._skills.try_use("ultimate", JOB.skill_ultimate))
	assert_eq(player._stats.current_mp, 200.0)
	player._shots.focus.value = 50
	assert_true(player._skills.try_use("ultimate", JOB.skill_ultimate))
	assert_eq(player._stats.current_mp, 200.0)
	player._skills.cancel()
	assert_eq(player._shots.focus.value, 50.0)
	assert_eq(player._skills.remaining("ultimate"), 0.0)


func test_precision_costs_commit_at_first_projectile_only() -> void:
	player._shots.focus.value = 70
	assert_true(player._skills.try_use("ultimate", JOB.skill_ultimate))
	player._skills.process_state(JOB.skill_ultimate.startup_sec + 0.001)
	assert_eq(player._shots.focus.value, 20.0)
	assert_eq(player._stats.current_mp, 172.0)
	assert_eq(player._skills.remaining("ultimate"), 12.0)
	player._skills.cancel()
	assert_eq(player._shots.focus.value, 20.0)


func test_retreat_fires_and_pays_after_dash() -> void:
	assert_true(player._skills.try_use("slot_q", JOB.skill_slot_q))
	player._skills.process_state(JOB.skill_slot_q.startup_sec + 0.001)
	assert_eq(player._stats.current_mp, 200.0)
	assert_eq(player._skills.remaining("slot_q"), 0.0)
	player._skills.process_state(JOB.skill_slot_q.get_active_duration_sec() + 0.001)
	assert_eq(player._stats.current_mp, 184.0)
	assert_eq(player._skills.remaining("slot_q"), 8.0)


func test_breathing_and_death_reset_temporary_focus() -> void:
	assert_true(player._skills.try_use("slot_e", JOB.skill_slot_e))
	player._skills.process_state(JOB.skill_slot_e.startup_sec + 0.001)
	assert_eq(player._stats.current_mp, 180.0)
	assert_eq(player._shots.focus.breathing_remaining, 6.0)
	player._shots.focus.value = 80
	player._process_death_lock()
	assert_eq(player._shots.focus.value, 0.0)
	assert_eq(player._shots.focus.breathing_remaining, 0.0)
