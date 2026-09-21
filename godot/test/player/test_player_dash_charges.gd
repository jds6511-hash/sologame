## 회피 대시 충전 횟수(2회)·재충전(4초)·즉시 무적(0.30초) 수치 재현.
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


func test_dash_invincibility_starts_immediately_and_ends_at_0_30() -> void:
	_player._start_dash()
	assert_true(_player.is_invincible(), "회피 입력을 받은 순간부터 보호")
	_player._process_dash(0.04)
	assert_true(_player.is_dash_invincible, "시작 직후 피격 공백 없음")

	_player._process_dash(0.02)  ## 누적 0.06초
	assert_true(_player.is_dash_invincible, "0~0.30초 구간은 무적")

	_player._process_dash(0.25)  ## 누적 0.31초
	assert_false(_player.is_dash_invincible, "0.30초 이후는 무적 해제")


func test_dash_cancels_attack_and_disables_its_hitbox() -> void:
	_player.attack_state = PlayerController.AttackState.ACTIVE
	(_player.get_node("Facing/AttackHitbox") as Area2D).monitoring = true
	_player._start_dash()
	assert_eq(_player.attack_state, PlayerController.AttackState.NONE)
	assert_true(_player.is_invincible(), "공격 중에도 즉시 회피")
	assert_false((_player.get_node("Facing/AttackHitbox") as Area2D).monitoring)


func test_dash_ends_after_0_35_seconds() -> void:
	_player._start_dash()
	_player._process_dash(0.34)
	assert_true(_player.is_dashing)
	_player._process_dash(0.02)  ## 누적 0.36초
	assert_false(_player.is_dashing, "대시 지속 시간 0.35초 종료")
