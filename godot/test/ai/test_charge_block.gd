## C-8 검증 — 돌진 블록(ChargeBlock)이 m3-monster-spec.md 3-3장 규격(예고 0.6초 / 돌진
## 6타일@8타일초 ≈ 0.75초 / 후딜 0.5초 / 벽 충돌 추가 경직 0.8초 / 쿨다운 4.0초)대로
## 동작하는지 확인한다.
extends GutTest

var _charge: ChargeBlock


func before_each() -> void:
	_charge = ChargeBlock.new()


func test_default_values_match_spec() -> void:
	assert_eq(_charge.telegraph_sec, 0.6, "spec 3-3 예고 0.6초(방향 고정)")
	assert_eq(_charge.charge_sec, 0.75, "spec 3-3 돌진 6타일 ÷ 8타일/초 = 0.75초")
	assert_eq(_charge.recovery_sec, 0.5, "spec 3-3 후딜 0.5초")
	assert_eq(_charge.wall_stun_sec, 0.8, "spec 3-3 벽 충돌 추가 경직 0.8초")
	assert_eq(_charge.cooldown_sec, 4.0, "spec 3-3 쿨다운 4.0초")


func test_telegraph_then_charge_then_recovery_then_cooldown() -> void:
	watch_signals(_charge)
	_charge.start()
	assert_signal_emitted(_charge, "telegraph_started")
	_charge.update(0.59)
	assert_false(_charge.is_charging(), "0.6초 전에는 예고 유지(측면 회피 판단 시간)")
	_charge.update(0.02)
	assert_true(_charge.is_charging())
	assert_signal_emitted(_charge, "charge_started")
	_charge.update(0.75)
	assert_eq(_charge.phase, ChargeBlock.Phase.RECOVERY)
	assert_signal_emitted(_charge, "charge_ended")
	_charge.update(0.5)
	assert_eq(_charge.phase, ChargeBlock.Phase.COOLDOWN)
	assert_signal_emitted(_charge, "ended")
	_charge.update(4.0)
	assert_true(_charge.is_ready())
	assert_signal_emitted(_charge, "cooldown_ended")


func test_wall_collision_ends_charge_early_and_extends_recovery() -> void:
	watch_signals(_charge)
	_charge.start()
	_charge.update(0.6)
	_charge.update(0.1)  ## 돌진 도중 벽에 박힘
	_charge.hit_wall()
	assert_eq(_charge.phase, ChargeBlock.Phase.RECOVERY, "벽 충돌 시 즉시 후딜로 전환")
	assert_signal_emitted(_charge, "charge_ended")
	_charge.update(1.2)
	assert_eq(_charge.phase, ChargeBlock.Phase.RECOVERY, "후딜 0.5 + 벽 경직 0.8 = 1.3초 무방비")
	_charge.update(0.2)
	assert_eq(_charge.phase, ChargeBlock.Phase.COOLDOWN)


func test_hit_wall_is_ignored_outside_charging_phase() -> void:
	_charge.start()
	_charge.hit_wall()  ## 예고 중에는 아직 이동하지 않으므로 무시돼야 함
	assert_eq(_charge.phase, ChargeBlock.Phase.TELEGRAPH)


func test_next_charge_recovery_is_not_polluted_by_previous_wall_stun() -> void:
	_charge.start()
	_charge.update(0.6)
	_charge.hit_wall()
	_charge.update(1.3)
	_charge.update(4.0)
	assert_true(_charge.is_ready())
	_charge.start()
	_charge.update(0.6)
	_charge.update(0.75)
	_charge.update(0.5)
	assert_eq(_charge.phase, ChargeBlock.Phase.COOLDOWN, "벽에 박지 않은 다음 돌진은 후딜 0.5초")


func test_cancel_during_telegraph_starts_cooldown_without_charging() -> void:
	watch_signals(_charge)
	_charge.start()
	_charge.update(0.3)
	_charge.cancel()
	assert_eq(_charge.phase, ChargeBlock.Phase.COOLDOWN, "예고 캔슬(피격 경직) 시 돌진 없이 쿨다운")
	assert_signal_not_emitted(_charge, "charge_started")
	assert_signal_emitted(_charge, "ended")
