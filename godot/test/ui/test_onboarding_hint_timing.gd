## UI-4 검증 — OnboardingHintTiming(onboarding.md 1장 원칙4 "절제된 재노출") 순수 로직.
extends GutTest

var _timing: OnboardingHintTiming


func before_each() -> void:
	_timing = OnboardingHintTiming.new()


func test_initial_state_is_not_showing() -> void:
	assert_false(_timing.is_showing())


func test_begin_starts_showing() -> void:
	_timing.begin()
	assert_true(_timing.is_showing())


func test_shows_for_8_seconds_then_hides() -> void:
	_timing.begin()
	_timing.update(7.9)
	assert_true(_timing.is_showing(), "8초 이전에는 계속 노출")
	_timing.update(0.2)
	assert_false(_timing.is_showing(), "8초가 지나면 숨는다")


func test_reshows_after_15_second_wait() -> void:
	_timing.begin()
	_timing.update(8.0)  ## 노출 종료 -> 대기 시작
	assert_false(_timing.is_showing())
	_timing.update(15.1)  ## 대기 종료 -> 재노출
	assert_true(_timing.is_showing())


func test_gives_up_silently_after_3_exposures() -> void:
	_timing.begin()
	for i in range(3):
		_timing.update(8.0)  ## 노출 종료
		_timing.update(15.1)  ## 대기 종료(3회째는 재노출 대신 포기)
	assert_true(_timing.is_done())
	assert_false(_timing.is_showing())


func test_begin_is_idempotent_while_showing() -> void:
	_timing.begin()
	_timing.update(1.0)
	_timing.begin()  ## 이미 진행 중 — 다시 불러도 타이머가 리셋되지 않아야 한다
	_timing.update(7.0)
	assert_false(_timing.is_showing(), "재호출로 타이머가 리셋됐다면 아직 8초가 안 지나 노출 중이어야 하는데 실패")


func test_complete_hides_immediately_and_stops_forever() -> void:
	_timing.begin()
	_timing.complete()
	assert_false(_timing.is_showing())
	_timing.update(100.0)
	assert_false(_timing.is_showing())
	assert_true(_timing.is_done())


func test_begin_after_done_does_nothing() -> void:
	_timing.begin()
	_timing.complete()
	_timing.begin()
	assert_false(_timing.is_showing())
