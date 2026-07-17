## G2-4 검증 — GameClock(오토로드)의 시계 진행·낮/밤 전환 시그널·야간 배율 API·디버그
## 시간 점프를 확인한다. GameClock은 테스트 전체에서 하나뿐인 오토로드이므로 매 테스트
## 전후로 reset()해 상태 오염을 막는다(PackAggroCoordinator.reset_all()과 동일한 패턴).
extends GutTest


func before_each() -> void:
	GameClock.reset()


func after_each() -> void:
	GameClock.reset()


# --- 기본 상태·시계 진행 ---


func test_initial_state_is_day_one_hour_zero() -> void:
	assert_eq(GameClock.day_number, 1)
	assert_eq(GameClock.get_hour(), 0)
	assert_eq(GameClock.get_minute(), 0)
	assert_true(GameClock.is_day)


func test_advance_time_progresses_game_clock_hour() -> void:
	## 현실 75초 = 게임 1시간 (현실 30분=게임 24시간 → 1800/86400 = 초당 48게임초).
	GameClock.advance_time(75.0)
	assert_eq(GameClock.get_hour(), 1)
	assert_eq(GameClock.get_minute(), 0)


func test_advance_time_progresses_game_clock_minute() -> void:
	GameClock.advance_time(75.0 / 60.0)  ## 게임 1분 분량
	assert_eq(GameClock.get_hour(), 0)
	assert_eq(GameClock.get_minute(), 1)


# --- 낮/밤 전환 (낮 20분:밤 10분 확정, reputation-territory.md 4장) ---


func test_stays_day_just_before_day_phase_boundary() -> void:
	GameClock.advance_time(1199.9)  ## 낮 구간(현실 1200초) 직전
	assert_true(GameClock.is_day)


func test_crosses_into_night_at_day_phase_boundary() -> void:
	watch_signals(GameClock)
	GameClock.advance_time(1200.0)  ## 현실 20분 경과 = 낮 구간 종료
	assert_false(GameClock.is_day)
	assert_signal_emitted_with_parameters(GameClock, "night_started", [1])


func test_night_started_not_emitted_again_while_still_night() -> void:
	GameClock.advance_time(1200.0)
	watch_signals(GameClock)
	GameClock.advance_time(1.0)
	assert_signal_not_emitted(GameClock, "night_started")


func test_crosses_back_into_day_and_increments_day_number() -> void:
	GameClock.advance_time(1200.0)  ## 밤 시작
	watch_signals(GameClock)
	GameClock.advance_time(600.0)  ## 밤 구간(현실 600초) 종료 = 다음 날 낮 시작
	assert_true(GameClock.is_day)
	assert_eq(GameClock.day_number, 2)
	assert_signal_emitted_with_parameters(GameClock, "day_started", [2])


# --- 야간 배율 API (combat.md 2-3장 — 보스 제외, 골드 제외는 DropSystem 쪽에서 검증) ---


func test_monster_stat_multiplier_is_1_during_day() -> void:
	assert_eq(GameClock.get_monster_stat_multiplier(), 1.0)


func test_monster_stat_multiplier_is_1_2_at_night() -> void:
	GameClock.advance_time(1200.0)
	assert_eq(GameClock.get_monster_stat_multiplier(), 1.2)


func test_monster_stat_multiplier_excludes_boss_at_night() -> void:
	GameClock.advance_time(1200.0)
	assert_eq(GameClock.get_monster_stat_multiplier(true), 1.0, "보스는 야간 배율 제외 확정")


func test_item_drop_rate_multiplier_is_1_15_at_night() -> void:
	GameClock.advance_time(1200.0)
	assert_eq(GameClock.get_item_drop_rate_multiplier(), 1.15)


func test_item_drop_rate_multiplier_excludes_boss_at_night() -> void:
	GameClock.advance_time(1200.0)
	assert_eq(GameClock.get_item_drop_rate_multiplier(true), 1.0, "보스는 야간 드랍률 배율 제외")


func test_item_drop_rate_multiplier_is_1_during_day() -> void:
	assert_eq(GameClock.get_item_drop_rate_multiplier(), 1.0)


# --- 디버그 시간 점프 (F10, scripts/debug/debug_combat_arena.gd) ---


func test_debug_jump_hours_advances_clock_by_exact_amount() -> void:
	GameClock.debug_jump_hours(1.0)
	assert_eq(GameClock.get_hour(), 1)
	assert_eq(GameClock.get_minute(), 0)


func test_debug_jump_hours_can_trigger_night_started() -> void:
	watch_signals(GameClock)
	GameClock.debug_jump_hours(16.0)  ## 낮 16시간 전부 점프 → 밤 진입
	assert_false(GameClock.is_day)
	assert_signal_emitted(GameClock, "night_started")
