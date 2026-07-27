## C-8 검증 — 포효 버프 블록(RoarBuffBlock)이 m3-monster-spec.md 3-6장 규격(예고 0.5초 /
## 쿨다운 12.0초 / 판정 없음)대로 동작하고, 지속 6초 < 쿨다운 12초 = 가동률 50%가
## 성립하는지 확인한다.
extends GutTest

var _roar: RoarBuffBlock


func before_each() -> void:
	_roar = RoarBuffBlock.new()


func test_default_values_match_spec() -> void:
	assert_eq(_roar.telegraph_sec, 0.5, "spec 3-6 예고 0.5초(고개 젖힘 — '임프를 끊어라' 신호)")
	assert_eq(_roar.cooldown_sec, 12.0, "spec 3-6 쿨다운 12.0초")


func test_telegraph_then_roar_then_cooldown() -> void:
	watch_signals(_roar)
	_roar.start()
	assert_signal_emitted(_roar, "roar_telegraph_started")
	_roar.update(0.49)
	assert_signal_not_emitted(_roar, "roared", "0.5초 전에는 버프가 걸리지 않는다")
	_roar.update(0.02)
	assert_signal_emitted(_roar, "roared")
	assert_eq(_roar.phase, RoarBuffBlock.Phase.COOLDOWN, "발동 즉시 쿨다운 — 후딜 없음(무피해 버프)")


func test_uptime_is_fifty_percent() -> void:
	## 버프 지속 6.0초(소유 몬스터가 관리) < 쿨다운 12.0초 → 상시 유지 불가.
	_roar.start()
	_roar.update(0.5)
	_roar.update(6.0)
	assert_false(_roar.is_ready(), "버프가 끝난 직후에도 쿨다운이 절반 남아 있어야 한다")
	_roar.update(6.0)
	assert_true(_roar.is_ready())


func test_cancel_during_telegraph_prevents_buff() -> void:
	watch_signals(_roar)
	_roar.start()
	_roar.update(0.2)
	_roar.cancel()
	assert_signal_not_emitted(_roar, "roared", "예고 캔슬(피격 경직) = 딜찬스, 버프 없음")
	assert_eq(_roar.phase, RoarBuffBlock.Phase.COOLDOWN)


func test_is_busy_only_during_telegraph() -> void:
	_roar.start()
	assert_true(_roar.is_busy())
	_roar.update(0.5)
	assert_false(_roar.is_busy(), "포효 후에는 곧바로 추적으로 복귀(spec 4-3 전이도)")
