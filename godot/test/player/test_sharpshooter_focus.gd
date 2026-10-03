extends GutTest

var focus: RefCounted


func before_each() -> void:
	var script = load("res://scripts/player/sharpshooter_focus.gd")
	if script != null:
		focus = script.new()


func _success(cap: int = 15) -> int:
	var id: int = focus.begin_cast(1, cap)
	focus.landed(id, 0)
	focus.end(id, 0)
	return id


func test_valid_cast_charges_once_and_consecutive_cast_adds_five() -> void:
	assert_not_null(focus)
	if focus == null:
		return
	var id: int = focus.begin_cast(3)
	focus.landed(id, 0)
	focus.landed(id, 0)
	focus.landed(id, 1)
	assert_eq(focus.value, 10.0)
	_success()
	assert_eq(focus.value, 25.0)


func test_whole_cast_miss_breaks_chain_only_after_last_projectile() -> void:
	_success()
	var miss: int = focus.begin_cast(3)
	focus.end(miss, 0)
	focus.end(miss, 0)
	focus.end(miss, 1)
	_success()
	assert_eq(focus.value, 20.0)
	focus.end(miss, 2)
	assert_eq(focus.value, 20.0)
	_success()
	assert_eq(focus.value, 35.0)


func test_out_of_order_success_awards_only_direct_predecessor_bonus() -> void:
	var first: int = focus.begin_cast(1)
	var second: int = focus.begin_cast(1)
	_success()
	assert_eq(focus.value, 10.0)
	focus.landed(second, 0)
	assert_eq(focus.value, 25.0)
	focus.landed(first, 0)
	assert_eq(focus.value, 40.0)
	focus.end(first, 0)
	focus.end(second, 0)
	assert_lte(focus._casts.size(), 1)


func test_rapid_cap_and_piercing_shot_never_charge_themselves() -> void:
	_success()
	_success(10)
	assert_eq(focus.value, 20.0)
	focus.start_breathing()
	_success(0)
	assert_eq(focus.value, 20.0)
	_success(10)
	assert_eq(focus.value, 50.0)
	_success()
	assert_eq(focus.value, 65.0)


func test_breathing_is_next_valid_hit_once_not_cast_and_does_not_stack() -> void:
	focus.start_breathing()
	focus.start_breathing()
	assert_eq(focus.value, 0.0)
	var first: int = focus.begin_cast(1)
	_success()
	assert_eq(focus.value, 30.0)
	focus.landed(first, 0)
	assert_eq(focus.value, 45.0)


func test_breathing_expires_at_six_seconds() -> void:
	focus.start_breathing()
	focus.advance(6.0)
	_success()
	assert_eq(focus.value, 10.0)


func test_decay_crosses_five_second_boundary_with_large_delta() -> void:
	_success()
	_success()
	focus.advance(4.5)
	assert_eq(focus.value, 25.0)
	focus.advance(1.0)
	assert_eq(focus.value, 20.0)
	focus.advance(100.0)
	assert_eq(focus.value, 0.0)


func test_invalid_delta_and_pause_do_not_advance_time() -> void:
	_success()
	focus.start_breathing()
	for delta in [0.0, -1.0, INF, NAN]:
		focus.advance(delta)
	assert_eq(focus.value, 10.0)
	assert_eq(focus.breathing_remaining, 6.0)


func test_each_valid_hit_restarts_idle_timer_but_duplicate_landed_does_not() -> void:
	var id: int = _success()
	focus.advance(4.0)
	focus.landed(id, 0)
	focus.advance(2.0)
	assert_eq(focus.value, 0.0)
	_success()
	focus.advance(4.0)
	_success()
	focus.advance(2.0)
	assert_eq(focus.value, 30.0)


func test_hit_and_spend_clamp_and_insufficient_spend_is_atomic() -> void:
	_success()
	assert_false(focus.spend())
	assert_eq(focus.value, 10.0)
	focus.take_hit()
	assert_eq(focus.value, 0.0)
	for index in range(20):
		_success()
	assert_eq(focus.value, 100.0)
	assert_true(focus.spend())
	assert_eq(focus.value, 50.0)
	focus.take_hit()
	assert_eq(focus.value, 30.0)
	assert_false(focus.spend())
	assert_eq(focus.value, 30.0)


func test_cancel_unspawned_preserves_first_projectile_and_resolves_miss() -> void:
	var id: int = focus.begin_cast(3)
	focus.cancel_unspawned(id, 1)
	focus.landed(id, 1)
	assert_eq(focus.value, 0.0)
	focus.end(id, 0)
	_success()
	assert_eq(focus.value, 10.0)


func test_invalid_cast_and_projectile_events_have_no_effect() -> void:
	assert_eq(focus.begin_cast(0), -1)
	assert_eq(focus.begin_cast(-1), -1)
	var id: int = focus.begin_cast(1)
	for index in [-1, 1, 100]:
		focus.landed(id, index)
		focus.end(id, index)
	focus.landed(-999, 0)
	focus.end(-999, 0)
	assert_eq(focus.value, 0.0)
	focus.landed(id, 0)
	assert_eq(focus.value, 10.0)


func test_reset_invalidates_old_ids_pending_bonus_and_breathing() -> void:
	var old: int = focus.begin_cast(3)
	_success()
	focus.start_breathing()
	focus.reset()
	var fresh: int = focus.begin_cast(1)
	assert_ne(old, fresh)
	focus.landed(old, 0)
	focus.end(old, 0)
	focus.cancel_unspawned(old, 1)
	assert_eq(focus.value, 0.0)
	assert_eq(focus.breathing_remaining, 0.0)
	focus.landed(fresh, 0)
	assert_eq(focus.value, 10.0)


func test_finished_failure_history_stays_bounded_behind_unresolved_cast() -> void:
	var old: int = focus.begin_cast(1)
	for index in range(5000):
		var id: int = focus.begin_cast(1)
		focus.end(id, 0)
	assert_lte(focus._casts.size(), 3)
	focus.landed(old, 0)
	focus.end(old, 0)
	_success()
	assert_eq(focus.value, 20.0)
	assert_lte(focus._casts.size(), 1)


func test_last_projectile_hit_makes_whole_cast_success() -> void:
	_success()
	var id: int = focus.begin_cast(3)
	focus.end(id, 0)
	focus.end(id, 1)
	focus.landed(id, 2)
	focus.end(id, 2)
	assert_eq(focus.value, 25.0)
	_success()
	assert_eq(focus.value, 40.0)


func test_late_predecessor_failure_never_adds_bonus_to_finished_success() -> void:
	var old: int = focus.begin_cast(1)
	_success()
	_success()
	assert_eq(focus.value, 25.0)
	focus.end(old, 0)
	focus.landed(old, 0)
	assert_eq(focus.value, 25.0)
	assert_lte(focus._casts.size(), 1)


func test_exact_fifty_spend_succeeds_once() -> void:
	for index in range(5):
		_success(10)
	assert_true(focus.spend())
	assert_eq(focus.value, 0.0)
	assert_false(focus.spend())
	assert_eq(focus.value, 0.0)


func test_breathing_just_before_expiry_and_decay_frame_partition() -> void:
	focus.start_breathing()
	focus.advance(5.99)
	_success()
	assert_eq(focus.value, 30.0)
	for index in range(60):
		focus.advance(0.1)
	assert_almost_eq(focus.value, 20.0, 0.00001)


func test_multiple_projectiles_refresh_idle_without_multiple_charge() -> void:
	var id: int = focus.begin_cast(2)
	focus.landed(id, 0)
	focus.end(id, 0)
	focus.advance(4.0)
	focus.landed(id, 1)
	focus.end(id, 1)
	focus.advance(4.0)
	assert_eq(focus.value, 10.0)
	focus.advance(2.0)
	assert_eq(focus.value, 0.0)
