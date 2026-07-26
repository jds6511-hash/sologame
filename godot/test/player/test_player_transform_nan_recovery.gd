## 재발 버그 근본 재현(플레이어) — 2026-07-26 ("Vector2 cannot be normalized" 경고 스팸).
##
## monster_base는 b04494b에서 이미 트랜스폼 유한성 가드를 갖췄으나, player_controller는
## _clamp_velocity_to_finite()가 velocity만 ZERO로 눌렀고 위치는 복구하지 않았다 —
## 플레이어 global_position이 한번 NaN이 되면 move_and_slide()가 매 프레임 경고를
## 무한 반복한다(위치는 velocity를 고쳐도 스스로 낫지 않음).
##
## 근본 수정: move_and_slide() 직전 가드(_guard_finite_before_move)가 global_position의
## 유한성을 확인해, 오염 시 마지막 유한 좌표(_last_finite_position)로 복구한다.
## 아래 테스트는 수정 전 FAIL(위치 NaN 유지) → 수정 후 PASS.
extends GutTest

const PLAYER_SCENE := "res://scenes/player/player.tscn"


func _make_player() -> PlayerController:
	var player: PlayerController = load(PLAYER_SCENE).instantiate()
	add_child_autofree(player)
	return player


func test_recovers_from_nan_position_to_last_finite() -> void:
	var player := _make_player()
	player.global_position = Vector2(120.0, -40.0)
	player._physics_process(0.016)  ## 유한 좌표를 캐시
	player.global_position = Vector2(NAN, NAN)  ## 오염 주입
	assert_false(player.global_position.is_finite(), "사전 조건: 위치가 NaN이어야 함")

	player._physics_process(0.016)

	assert_true(player.global_position.is_finite(), "가드가 NaN 위치를 유한값으로 복구해야 함")
	assert_eq(player.global_position, Vector2(120.0, -40.0), "복구 기준점은 마지막 유한 좌표여야 함")


func test_recovers_during_hit_stun_branch() -> void:
	## 피격 경직(넉백) 분기에서도 동일하게 회복해야 한다 — 넉백 경로가 오염의 유력 후보.
	var player := _make_player()
	player.global_position = Vector2(50.0, 50.0)
	player._physics_process(0.016)  ## 유한 좌표 캐시
	player.take_hit(false, Vector2.RIGHT)
	assert_true(player.is_hit_stunned, "사전 조건: 피격 경직 상태")
	player.global_position = Vector2(NAN, NAN)

	player._physics_process(0.016)

	assert_true(player.global_position.is_finite(), "경직 분기에서도 NaN 위치를 복구해야 함")


func test_recovers_to_finite_when_corrupted_before_any_finite_frame() -> void:
	## 유한 프레임을 한 번도 거치지 않고 곧바로 오염돼도 유한성을 보장한다(_ready 캐시 대체).
	var player := _make_player()
	player.global_position = Vector2(NAN, NAN)

	player._physics_process(0.016)

	assert_true(player.global_position.is_finite(), "캐시가 없어도 유한값으로라도 복구해야 함")
