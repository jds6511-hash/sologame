## CB-1 검증 — PlayerMovementData 역산 공식이 combat.md 4장 확정 수치와 일치하는지 확인.
## (걷기 이동속도는 growth.md에 px/s 절대값이 없어 대시 3수치에서 역산한다 — 클래스 주석 참조)
extends GutTest

const DATA_PATH := "res://data/player/player_movement.tres"


func test_dash_distance_is_3_tiles() -> void:
	var data: PlayerMovementData = load(DATA_PATH)
	assert_eq(data.get_dash_distance_px(), 48.0, "16px x 3타일")


func test_dash_speed_from_distance_and_duration() -> void:
	var data: PlayerMovementData = load(DATA_PATH)
	assert_almost_eq(data.get_dash_speed_px_per_sec(), 48.0 / 0.35, 0.001)


func test_walk_speed_derived_from_dash_speed_and_multiplier() -> void:
	var data: PlayerMovementData = load(DATA_PATH)
	var expected := (48.0 / 0.35) / 2.6
	assert_almost_eq(data.get_walk_speed_px_per_sec(), expected, 0.001)


func test_dash_invincibility_window_is_0_25_sec_starting_at_0_05() -> void:
	var data: PlayerMovementData = load(DATA_PATH)
	assert_eq(data.dash_invincibility_start_sec, 0.05)
	assert_eq(data.dash_invincibility_duration_sec, 0.25)
	assert_almost_eq(data.get_dash_invincibility_end_sec(), 0.30, 0.0001)


func test_dash_charge_max_is_2_and_recharge_is_4_sec() -> void:
	var data: PlayerMovementData = load(DATA_PATH)
	assert_eq(data.dash_charge_max, 2, "전사 = 표준 2회 (jobs.md 3장)")
	assert_eq(data.dash_recharge_sec, 4.0, "충전당 4초, 전 직업 공통")
