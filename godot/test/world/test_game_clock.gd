## G2-4 검증 — GameClock(오토로드)의 시계 진행·낮/밤 전환 시그널·야간 배율 API·디버그
## 시간 점프를 확인한다. GameClock은 테스트 전체에서 하나뿐인 오토로드이므로 매 테스트
## 전후로 reset()해 상태 오염을 막는다(PackAggroCoordinator.reset_all()과 동일한 패턴).
##
## 시계 "로직"은 콘텐츠 튜닝값(하루 길이·낮 구간 길이)과 분리돼야 하므로, 테스트는
## 배포된 game_time_data.tres 값에 의존하지 않는다. before_each에서 자체 GameTimeData를
## 만들어 GameClock에 주입하고, 기대값은 하드코딩하지 않고 주입한 리소스 값에서 파생해
## 계산한다. 따라서 하루 길이 튜닝값이 바뀌어도(예: 야간 확인용 임시 180초) 이 테스트는
## 그대로 통과한다.
extends GutTest

## 시계 로직 검증용 표준 시간 규칙 — 배포값과 무관한 고정 기준.
## (real_seconds_per_game_day는 24로 나누어떨어지게, day_phase는 하루보다 작게 두기만 하면
##  된다. 값 자체가 아니라 "경계·환산"이 맞는지를 본다.)
const TEST_SECONDS_PER_GAME_DAY := 1800.0
const TEST_SECONDS_DAY_PHASE := 1200.0
const TEST_NIGHT_MONSTER_MULTIPLIER := 1.2
const TEST_NIGHT_DROP_MULTIPLIER := 1.15

var _orig_time_data: GameTimeData


func before_each() -> void:
	_orig_time_data = GameClock.time_data
	var test_data := GameTimeData.new()
	test_data.real_seconds_per_game_day = TEST_SECONDS_PER_GAME_DAY
	test_data.real_seconds_day_phase = TEST_SECONDS_DAY_PHASE
	test_data.night_monster_stat_multiplier = TEST_NIGHT_MONSTER_MULTIPLIER
	test_data.night_item_drop_rate_multiplier = TEST_NIGHT_DROP_MULTIPLIER
	GameClock.time_data = test_data
	GameClock.reset()


func after_each() -> void:
	GameClock.reset()
	GameClock.time_data = _orig_time_data


func test_scene_time_preparation_matches_restore_without_emitting_phase_signals() -> void:
	watch_signals(GameClock)
	for boundary in [300.0, 1200.0]:
		GameClock.time_data.real_seconds_day_phase = boundary
		for elapsed in [boundary - 0.1, boundary, boundary + 0.1]:
			GameClock.prepare_scene_time(3, elapsed)
			assert_eq(GameClock.is_day, elapsed < boundary)
			assert_signal_not_emitted(GameClock, "day_started")
			assert_signal_not_emitted(GameClock, "night_started")
			var prepared: bool = GameClock.is_day
			GameClock.restore_saved_time(3, elapsed)
			assert_eq(GameClock.is_day, prepared)


# --- 파생 계산 헬퍼 (주입한 리소스 값에서 기대값을 계산 — 하드코딩 금지) ---


## 게임 1시간에 해당하는 현실 초.
func _real_sec_per_game_hour() -> float:
	return GameClock.time_data.real_seconds_per_game_day / 24.0


## 낮 구간이 끝나고 밤으로 넘어가는 경계까지의 현실 초.
func _day_phase_real_sec() -> float:
	return GameClock.time_data.real_seconds_day_phase


## 밤 구간의 현실 초 (하루 - 낮 구간).
func _night_phase_real_sec() -> float:
	return (
		GameClock.time_data.real_seconds_per_game_day - GameClock.time_data.real_seconds_day_phase
	)


# --- 기본 상태·시계 진행 ---


func test_initial_state_is_day_one_hour_zero() -> void:
	assert_eq(GameClock.day_number, 1)
	assert_eq(GameClock.get_hour(), 0)
	assert_eq(GameClock.get_minute(), 0)
	assert_true(GameClock.is_day)


func test_advance_time_progresses_game_clock_hour() -> void:
	## 게임 1시간 분량(현실 초는 주입한 하루 길이에서 파생)을 흘리면 시계는 정확히 1시.
	GameClock.advance_time(_real_sec_per_game_hour())
	assert_eq(GameClock.get_hour(), 1)
	assert_eq(GameClock.get_minute(), 0)


func test_advance_time_progresses_game_clock_minute() -> void:
	GameClock.advance_time(_real_sec_per_game_hour() / 60.0)  ## 게임 1분 분량
	assert_eq(GameClock.get_hour(), 0)
	assert_eq(GameClock.get_minute(), 1)


# --- 낮/밤 전환 (낮:밤 = 2:1, reputation-territory.md 4장 / 경계는 주입값에서 파생) ---


func test_stays_day_just_before_day_phase_boundary() -> void:
	GameClock.advance_time(_day_phase_real_sec() - 0.1)  ## 낮 구간 종료 직전
	assert_true(GameClock.is_day)


func test_crosses_into_night_at_day_phase_boundary() -> void:
	watch_signals(GameClock)
	GameClock.advance_time(_day_phase_real_sec())  ## 낮 구간 종료 = 밤 진입
	assert_false(GameClock.is_day)
	assert_signal_emitted_with_parameters(GameClock, "night_started", [1])


func test_night_started_not_emitted_again_while_still_night() -> void:
	GameClock.advance_time(_day_phase_real_sec())
	watch_signals(GameClock)
	GameClock.advance_time(1.0)
	assert_signal_not_emitted(GameClock, "night_started")


func test_crosses_back_into_day_and_increments_day_number() -> void:
	GameClock.advance_time(_day_phase_real_sec())  ## 밤 시작
	watch_signals(GameClock)
	GameClock.advance_time(_night_phase_real_sec())  ## 밤 구간 종료 = 다음 날 낮 시작
	assert_true(GameClock.is_day)
	assert_eq(GameClock.day_number, 2)
	assert_signal_emitted_with_parameters(GameClock, "day_started", [2])


# --- 야간 배율 API (combat.md 2-3장 — 보스 제외, 골드 제외는 DropSystem 쪽에서 검증) ---


func test_monster_stat_multiplier_is_1_during_day() -> void:
	assert_eq(GameClock.get_monster_stat_multiplier(), 1.0)


func test_monster_stat_multiplier_at_night_matches_time_data() -> void:
	GameClock.advance_time(_day_phase_real_sec())
	assert_eq(
		GameClock.get_monster_stat_multiplier(), GameClock.time_data.night_monster_stat_multiplier
	)


func test_monster_stat_multiplier_excludes_boss_at_night() -> void:
	GameClock.advance_time(_day_phase_real_sec())
	assert_eq(GameClock.get_monster_stat_multiplier(true), 1.0, "보스는 야간 배율 제외 확정")


func test_item_drop_rate_multiplier_at_night_matches_time_data() -> void:
	GameClock.advance_time(_day_phase_real_sec())
	assert_eq(
		GameClock.get_item_drop_rate_multiplier(),
		GameClock.time_data.night_item_drop_rate_multiplier
	)


func test_item_drop_rate_multiplier_excludes_boss_at_night() -> void:
	GameClock.advance_time(_day_phase_real_sec())
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
	GameClock.debug_jump_hours(16.0)  ## 낮 16시간(00:00~16:00) 전부 점프 → 밤 진입
	assert_false(GameClock.is_day)
	assert_signal_emitted(GameClock, "night_started")
