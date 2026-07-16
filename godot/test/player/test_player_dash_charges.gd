## CB-1 검증 — 회피 대시 충전 횟수(2회)·재충전(4초)·무적 프레임(0.25초) 수치 재현.
## combat.md 4장 확정값을 PlayerController의 실제 상태 변화로 검증한다.
extends GutTest

var _player: PlayerController


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)


func test_initial_dash_charges_is_2() -> void:
	assert_eq(_player.dash_charges, 2)


func test_start_dash_consumes_1_charge() -> void:
	_player._start_dash()
	assert_eq(_player.dash_charges, 1)


func test_two_dashes_consume_both_charges() -> void:
	_player._start_dash()
	_player.is_dashing = false  ## 두 번째 회피를 즉시 테스트하기 위해 상태만 초기화
	_player._start_dash()
	assert_eq(_player.dash_charges, 0)


func test_recharge_takes_exactly_4_seconds() -> void:
	_player._start_dash()
	_player.is_dashing = false
	assert_eq(_player.dash_charges, 1, "1회 소모 직후")
	_player._update_dash_recharge(3.99)
	assert_eq(_player.dash_charges, 1, "3.99초에는 아직 재충전 안 됨")
	_player._update_dash_recharge(0.02)
	assert_eq(_player.dash_charges, 2, "4초 경과 후 1회 재충전(최대 2 복귀)")


func test_recharge_does_not_exceed_charge_max() -> void:
	_player._update_dash_recharge(100.0)
	assert_eq(_player.dash_charges, 2, "충전 중이 아니었으므로 최대 2회 유지")


func test_dash_invincibility_window_matches_0_05_to_0_30() -> void:
	_player._start_dash()
	_player._process_dash(0.04)
	assert_false(_player.is_dash_invincible, "0.04초 시점은 무적 시작 전")

	_player._process_dash(0.02)  ## 누적 0.06초
	assert_true(_player.is_dash_invincible, "0.05~0.30초 구간은 무적")

	_player._process_dash(0.25)  ## 누적 0.31초
	assert_false(_player.is_dash_invincible, "0.30초 이후는 무적 해제")


func test_dash_ends_after_0_35_seconds() -> void:
	_player._start_dash()
	_player._process_dash(0.34)
	assert_true(_player.is_dashing)
	_player._process_dash(0.02)  ## 누적 0.36초
	assert_false(_player.is_dashing, "대시 지속 시간 0.35초 종료")
