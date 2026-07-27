## C-8 검증 — 순간이동 블록(BlinkBlock)이 m3-monster-spec.md 3-5장 규격(예고 0.3초 /
## 등장 후딜 0.3초 / 쿨다운 4.5초)대로 동작하는지 확인한다.
extends GutTest

var _blink: BlinkBlock


func before_each() -> void:
	_blink = BlinkBlock.new()


func test_default_values_match_spec() -> void:
	assert_eq(_blink.telegraph_sec, 0.3, "spec 3-5 예고 0.3초(균열 일렁임 — 무피해 예외)")
	assert_eq(_blink.recovery_sec, 0.3, "spec 3-5 등장 후딜 0.3초(딜찬스)")
	assert_eq(_blink.cooldown_sec, 4.5, "spec 3-5 쿨다운 4.5초")


func test_telegraph_then_blink_then_recovery_then_cooldown() -> void:
	watch_signals(_blink)
	_blink.start()
	assert_signal_emitted(_blink, "blink_telegraph_started")
	_blink.update(0.29)
	assert_signal_not_emitted(_blink, "blinked", "0.3초 전에는 아직 사라지지 않는다")
	_blink.update(0.02)
	assert_signal_emitted(_blink, "blinked")
	assert_true(_blink.is_recovering(), "재등장 직후 무방비 구간")
	_blink.update(0.3)
	assert_signal_emitted(_blink, "recovery_ended")
	assert_eq(_blink.phase, BlinkBlock.Phase.COOLDOWN)
	_blink.update(4.4)
	assert_false(_blink.is_ready(), "쿨다운 4.5초 이전에는 재순간이동 불가(딜 집중 창)")
	_blink.update(0.2)
	assert_true(_blink.is_ready())
	assert_signal_emitted(_blink, "cooldown_ended")


func test_cancel_during_telegraph_prevents_teleport() -> void:
	watch_signals(_blink)
	_blink.start()
	_blink.update(0.1)
	_blink.cancel()
	assert_signal_not_emitted(_blink, "blinked", "예고 캔슬(피격 경직) 시 이동하지 않는다")
	assert_eq(_blink.phase, BlinkBlock.Phase.COOLDOWN)


func test_elite_cooldown_override_is_data_driven() -> void:
	## 포효 임프장 아종(spec 7-4)은 쿨다운만 6.0초로 교체한다 — 블록 코드는 동일.
	_blink.cooldown_sec = 6.0
	_blink.start()
	_blink.update(0.3)
	_blink.update(0.3)
	_blink.update(5.9)
	assert_false(_blink.is_ready())
	_blink.update(0.2)
	assert_true(_blink.is_ready())
