## 플레이어 이동 둔화 수신 API 검증 — 숲거미 거미줄(ai-dev) 등 몬스터가 duck-typing으로
## 호출하는 apply_move_speed_slow(percent, duration_sec)이 걷기 속도에 실제로 반영되고,
## 중첩 시 "더 강한 값·더 긴 지속으로 갱신"(포효 버프와 동일 규약)되는지 확인한다.
extends GutTest

const TOL := 0.0001

var _player: PlayerController


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)


func _walk_speed() -> float:
	return _player.movement_data.get_walk_speed_px_per_sec()


func test_slow_reduces_walk_speed_by_percent() -> void:
	_player.apply_move_speed_slow(0.4, 2.0)
	assert_almost_eq(_player._resolve_move_speed_px(false), _walk_speed() * 0.6, TOL)


func test_slow_expires_after_duration() -> void:
	_player.apply_move_speed_slow(0.4, 2.0)
	_player._update_move_slow(1.99)
	assert_almost_eq(_player._resolve_move_speed_px(false), _walk_speed() * 0.6, TOL, "지속 중")

	_player._update_move_slow(0.02)
	assert_almost_eq(_player._resolve_move_speed_px(false), _walk_speed(), TOL, "만료 후 원복")


func test_stacking_takes_stronger_percent_and_longer_duration() -> void:
	_player.apply_move_speed_slow(0.4, 2.0)
	_player.apply_move_speed_slow(0.2, 5.0)  ## 약하지만 더 긴 둔화

	assert_almost_eq(_player._move_slow_percent, 0.4, TOL, "더 강한 감소율 유지")
	assert_almost_eq(_player._move_slow_timer, 5.0, TOL, "더 긴 지속 유지")


func test_invalid_slow_values_are_ignored() -> void:
	_player.apply_move_speed_slow(0.0, 2.0)
	_player.apply_move_speed_slow(0.5, 0.0)
	assert_almost_eq(_player._resolve_move_speed_px(false), _walk_speed(), TOL)


func test_slow_compounds_with_attack_move_penalty() -> void:
	_player.apply_move_speed_slow(0.5, 2.0)
	assert_almost_eq(
		_player._resolve_move_speed_px(true),
		_walk_speed() * 0.5 * PlayerController.ATTACK_MOVE_SPEED_MULTIPLIER,
		TOL,
		"둔화와 공격 중 이동 페널티는 함께 적용된다"
	)
