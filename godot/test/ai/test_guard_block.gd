## C-8 검증 — 가드 블록(GuardBlock)이 m3-monster-spec.md 3-4장 규격(진입 0.2초 / 지속 최대
## 1.5초 또는 1회 피격 / 브레이크 경직 1.0초 / 해제 후딜 0.4초 / 쿨다운 6.0초)대로
## 동작하는지 확인한다.
extends GutTest

var _guard: GuardBlock


func before_each() -> void:
	_guard = GuardBlock.new()


func test_default_values_match_spec() -> void:
	assert_eq(_guard.enter_sec, 0.2, "spec 3-4 진입 예고 0.2초(무피해라 4장 예외)")
	assert_eq(_guard.duration_sec, 1.5, "spec 3-4 지속 최대 1.5초")
	assert_eq(_guard.break_stun_sec, 1.0, "spec 3-4 가드 브레이크 경직 1.0초")
	assert_eq(_guard.recovery_sec, 0.4, "spec 3-4 해제 후딜 0.4초")
	assert_eq(_guard.cooldown_sec, 6.0, "spec 3-4 쿨다운 6.0초")


func test_damage_reduction_is_not_active_during_enter_phase() -> void:
	_guard.start()
	assert_false(_guard.is_guarding(), "진입 0.2초 동안은 아직 감쇄가 걸리지 않는다")
	_guard.update(0.2)
	assert_true(_guard.is_guarding())


func test_guard_expires_after_duration_then_recovery_then_cooldown() -> void:
	watch_signals(_guard)
	_guard.start()
	_guard.update(0.2)
	assert_signal_emitted(_guard, "guard_entered")
	_guard.update(1.5)
	assert_false(_guard.is_guarding())
	assert_signal_emitted(_guard, "guard_ended")
	assert_eq(_guard.phase, GuardBlock.Phase.RECOVERY, "지속 종료 후 0.4초 무방비")
	_guard.update(0.4)
	assert_eq(_guard.phase, GuardBlock.Phase.COOLDOWN)
	_guard.update(6.0)
	assert_true(_guard.is_ready())
	assert_signal_emitted(_guard, "cooldown_ended")


func test_absorbed_hit_ends_guard_immediately() -> void:
	watch_signals(_guard)
	_guard.start()
	_guard.update(0.2)
	_guard.notify_absorbed_hit()
	assert_false(_guard.is_guarding(), "spec 3-4 '1회 피격까지' — 한 번 흘리면 해제")
	assert_signal_emitted(_guard, "guard_ended")
	assert_eq(_guard.phase, GuardBlock.Phase.RECOVERY)


func test_guard_break_gives_stun_and_skips_recovery() -> void:
	watch_signals(_guard)
	_guard.start()
	_guard.update(0.2)
	_guard.notify_guard_break()
	assert_true(_guard.is_broken())
	assert_signal_emitted(_guard, "guard_broken")
	_guard.update(0.9)
	assert_true(_guard.is_broken(), "브레이크 경직 1.0초 동안 무방비(딜찬스)")
	_guard.update(0.2)
	assert_eq(_guard.phase, GuardBlock.Phase.COOLDOWN, "spec 4-2 전이도: 브레이크 후 해제 후딜 없이 복귀")


func test_absorbed_hit_outside_guarding_phase_is_ignored() -> void:
	_guard.start()
	_guard.notify_absorbed_hit()  ## 진입(0.2초) 중에는 흘릴 수 없다
	assert_eq(_guard.phase, GuardBlock.Phase.ENTERING)


func test_guard_break_during_enter_phase_still_breaks() -> void:
	_guard.start()
	_guard.notify_guard_break()
	assert_true(_guard.is_broken(), "자세를 잡는 중 강 등급을 맞으면 그대로 무너진다")


func test_is_busy_covers_enter_through_recovery_but_not_cooldown() -> void:
	_guard.start()
	assert_true(_guard.is_busy())
	_guard.update(0.2)
	_guard.update(1.5)
	_guard.update(0.4)
	assert_eq(_guard.phase, GuardBlock.Phase.COOLDOWN)
	assert_false(_guard.is_busy(), "쿨다운은 추적 복귀 가능 구간")
