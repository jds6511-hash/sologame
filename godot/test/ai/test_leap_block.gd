## C-8 검증 — 도약 블록(LeapBlock)이 m3-monster-spec.md 3-1장 규격(예고 0.5초 / 공중 이동
## 0.35초 / 착지 판정 0.15초 / 후딜 0.4초 / 쿨다운 3.5초)대로 단계 전이하는지 확인한다.
##
## update()는 한 번 호출에 최대 한 단계만 넘어가므로, 단계별 정확한 델타를 주입해
## 결정적으로 검증한다(부동소수 누적 오차 배제).
extends GutTest

var _leap: LeapBlock


func before_each() -> void:
	_leap = LeapBlock.new()


func test_default_values_match_spec() -> void:
	assert_eq(_leap.telegraph_sec, 0.5, "spec 3-1 예고(웅크림) 0.5초")
	assert_eq(_leap.travel_sec, 0.35, "spec 3-1 도약 이동 0.35초")
	assert_eq(_leap.active_sec, 0.15, "spec 3-1 착지 판정 지속 0.15초")
	assert_eq(_leap.recovery_sec, 0.4, "spec 3-1 후딜 0.4초")
	assert_eq(_leap.cooldown_sec, 3.5, "spec 3-1 쿨다운 3.5초")


func test_starts_ready_and_is_not_busy() -> void:
	assert_true(_leap.is_ready())
	assert_false(_leap.is_busy())


func test_start_enters_telegraph_and_emits_signal() -> void:
	watch_signals(_leap)
	_leap.start()
	assert_eq(_leap.phase, LeapBlock.Phase.TELEGRAPH)
	assert_signal_emitted(_leap, "telegraph_started")
	assert_false(_leap.is_ready())


func test_telegraph_holds_until_spec_duration_then_travels() -> void:
	watch_signals(_leap)
	_leap.start()
	_leap.update(0.49)
	assert_eq(_leap.phase, LeapBlock.Phase.TELEGRAPH, "0.5초 전에는 예고 유지(회피 판단 시간)")
	_leap.update(0.02)
	assert_true(_leap.is_traveling())
	assert_signal_emitted(_leap, "leap_started")


func test_landing_judgement_lasts_only_active_sec() -> void:
	watch_signals(_leap)
	_leap.start()
	_leap.update(0.5)
	_leap.update(0.35)
	assert_true(_leap.is_active(), "이동이 끝나면 착지 판정 구간")
	assert_signal_emitted(_leap, "became_active")
	_leap.update(0.14)
	assert_true(_leap.is_active(), "0.15초 이내에는 판정 유지")
	_leap.update(0.02)
	assert_false(_leap.is_active(), "판정은 0.15초만 유지(플레이어 회피 무적 0.25초보다 짧게)")
	assert_signal_emitted(_leap, "active_ended")
	assert_eq(_leap.phase, LeapBlock.Phase.RECOVERY)


func test_recovery_then_cooldown_then_ready_full_cycle() -> void:
	watch_signals(_leap)
	_leap.start()
	_leap.update(0.5)
	_leap.update(0.35)
	_leap.update(0.15)
	_leap.update(0.4)
	assert_eq(_leap.phase, LeapBlock.Phase.COOLDOWN, "후딜이 끝나면 쿨다운 진입")
	assert_signal_emitted(_leap, "ended")
	_leap.update(3.4)
	assert_false(_leap.is_ready(), "쿨다운 3.5초 이전에는 재도약 불가")
	_leap.update(0.2)
	assert_true(_leap.is_ready())
	assert_signal_emitted(_leap, "cooldown_ended")


func test_cancel_during_telegraph_skips_judgement_and_starts_cooldown() -> void:
	watch_signals(_leap)
	_leap.start()
	_leap.update(0.2)
	_leap.cancel()
	assert_eq(_leap.phase, LeapBlock.Phase.COOLDOWN, "예고 캔슬(피격 경직) 시 판정 없이 쿨다운")
	assert_signal_not_emitted(_leap, "became_active")
	assert_signal_emitted(_leap, "ended")


func test_cancel_during_active_closes_judgement_window() -> void:
	watch_signals(_leap)
	_leap.start()
	_leap.update(0.5)
	_leap.update(0.35)
	assert_true(_leap.is_active())
	_leap.cancel()
	assert_signal_emitted(_leap, "active_ended", "판정 중 캔슬되면 히트박스를 끌 수 있게 알려야 함")
	assert_false(_leap.is_active())


func test_cancel_does_nothing_when_ready() -> void:
	_leap.cancel()
	assert_true(_leap.is_ready())
