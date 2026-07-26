## 재발 버그 근본 재현 — 2026-07-26 ("Vector2 cannot be normalized" 경고 스팸).
##
## 재현 테스트로 확인한 정확한 메커니즘:
##   CharacterBody2D.global_position(트랜스폼)이 한번 non-finite(NaN/Inf)가 되면, 그
##   이후 move_and_slide()는 velocity가 (0,0)이어도 매 물리 프레임 충돌 법선을 normalize
##   하며 "Vector2 cannot be normalized" 경고를 무한 반복한다(헤드리스 재현: NaN 위치 1개
##   개체가 350프레임 동안 4만 건 이상 경고 발생, velocity=(0,0)).
##
## 이전 수정(b0a9d2a)이 왜 못 잡았나: velocity만 ZERO로 눌렀는데, 경고의 원인은 velocity가
## 아니라 트랜스폼이다(위 backtrace의 velocity=(0,0)이 증거). 위치는 한번 NaN이 되면
## velocity를 고쳐도 스스로 낫지 않으므로 경고가 계속된다.
##
## 근본 수정: move_and_slide() 직전 가드가 velocity뿐 아니라 global_position 자체의
## 유한성을 확인해, 오염 시 유한한 기준점(home_position)으로 복구한다 → 오염된 개체가
## 스스로 1프레임 내 회복. 아래 테스트는 수정 전 FAIL(위치가 NaN으로 유지) → 수정 후 PASS.
extends GutTest

const WOLF_SCENE := preload("res://scenes/monsters/wolf.tscn")
const RABBIT_SCENE := preload("res://scenes/monsters/rabbit.tscn")


func test_wolf_recovers_from_nan_position_to_home() -> void:
	var wolf: WolfMonster = WOLF_SCENE.instantiate()
	add_child_autofree(wolf)
	wolf.home_position = Vector2(100.0, 50.0)  ## 알려진 유한 기준점(스폰 지점)
	wolf.global_position = Vector2(NAN, NAN)  ## 오염 주입
	assert_false(wolf.global_position.is_finite(), "사전 조건: 위치가 NaN이어야 함")

	wolf._physics_process(0.016)

	assert_true(wolf.global_position.is_finite(), "move_and_slide 직전 가드가 NaN 위치를 유한값으로 복구해야 함")
	assert_eq(wolf.global_position, wolf.home_position, "복구 기준점은 home_position이어야 함")


func test_rabbit_recovers_from_nan_position_to_home() -> void:
	var rabbit: RabbitMonster = RABBIT_SCENE.instantiate()
	add_child_autofree(rabbit)
	rabbit.home_position = Vector2(-30.0, 12.0)
	rabbit.global_position = Vector2(NAN, NAN)

	rabbit._physics_process(0.016)

	assert_true(rabbit.global_position.is_finite(), "뿔토끼도 NaN 위치에서 스스로 회복해야 함")
	assert_eq(rabbit.global_position, rabbit.home_position)


func test_recovers_during_stagger_branch() -> void:
	## 경직(넉백) 분기에서도 동일하게 회복해야 한다 — 넉백 경로가 오염의 유력 후보이므로.
	var wolf: WolfMonster = WOLF_SCENE.instantiate()
	add_child_autofree(wolf)
	wolf.home_position = Vector2(8.0, 8.0)
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.global_position = Vector2(0.0, 0.0)
	wolf.take_damage(1.0, "약", attacker)  ## 경직 진입
	assert_true(wolf.is_staggered(), "사전 조건: 경직 상태")
	wolf.global_position = Vector2(NAN, NAN)

	wolf._physics_process(0.016)

	assert_true(wolf.global_position.is_finite(), "경직 분기에서도 NaN 위치를 복구해야 함")


func test_falls_back_to_zero_when_home_also_corrupted() -> void:
	## home_position마저 오염된 극단 상황에서는 원점(ZERO)으로라도 복구해 유한성을 보장한다.
	var wolf: WolfMonster = WOLF_SCENE.instantiate()
	add_child_autofree(wolf)
	wolf.home_position = Vector2(NAN, NAN)
	wolf.global_position = Vector2(NAN, NAN)

	wolf._physics_process(0.016)

	assert_true(wolf.global_position.is_finite(), "home도 NaN이면 원점으로라도 복구해 유한성 보장")
