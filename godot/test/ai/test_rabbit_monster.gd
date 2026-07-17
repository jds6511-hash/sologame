## CB-6 검증 — 뿔토끼 상태 전이(m2-monster-spec.md 3-1장) 재현.
extends GutTest

var _rabbit: RabbitMonster
var _target: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/monsters/rabbit.tscn")
	_rabbit = scene.instantiate()
	add_child_autofree(_rabbit)
	_target = Node2D.new()
	add_child_autofree(_target)
	_rabbit.global_position = Vector2.ZERO
	_target.global_position = Vector2(1000, 1000)  ## 기본은 인지범위 밖
	_rabbit.target = _target


func test_initial_state_is_wander() -> void:
	assert_eq(_rabbit.state, RabbitMonster.State.WANDER)


func test_enters_flee_when_target_within_perception_range() -> void:
	_target.global_position = _rabbit.global_position + Vector2(2 * 16, 0)  ## 인지범위 3타일 이내
	_rabbit._physics_process(0.016)
	assert_eq(_rabbit.state, RabbitMonster.State.FLEE)


func test_stays_wander_when_target_out_of_perception_range() -> void:
	_rabbit._physics_process(0.016)
	assert_eq(_rabbit.state, RabbitMonster.State.WANDER)


func test_flee_transitions_to_melee_swing_when_caught() -> void:
	_rabbit._start_flee()
	_target.global_position = _rabbit.global_position + Vector2(20, 0)  ## 근접범위 1.5타일(24px) 이내
	_rabbit._physics_process(0.016)
	assert_eq(_rabbit.state, RabbitMonster.State.MELEE_SWING)


func test_flee_returns_to_wander_after_duration_when_distance_secured() -> void:
	_rabbit._start_flee()
	_target.global_position = _rabbit.global_position + Vector2(1000, 0)  ## 인지범위 밖으로 거리 확보
	_rabbit._physics_process(_rabbit.stats.flee_duration_sec + 0.1)
	assert_eq(_rabbit.state, RabbitMonster.State.WANDER)


func test_flee_does_not_return_to_wander_before_duration_ends() -> void:
	_rabbit._start_flee()
	_target.global_position = _rabbit.global_position + Vector2(1000, 0)
	_rabbit._physics_process(_rabbit.stats.flee_duration_sec - 0.1)
	assert_eq(_rabbit.state, RabbitMonster.State.FLEE, "도주 지속 시간이 끝나기 전에는 배회로 복귀하지 않음")


func test_melee_swing_full_cycle_returns_to_flee() -> void:
	_rabbit._start_melee_swing()
	_rabbit._physics_process(1.0)  ## 예고 -> 판정
	_rabbit._physics_process(1.0)  ## 판정 -> 후딜
	_rabbit._physics_process(1.0)  ## 후딜 종료 -> 도주 재시도
	assert_eq(_rabbit.state, RabbitMonster.State.FLEE, "spec: 근접 스윙 종료 후 도주 재시도")


func test_take_damage_reduces_hp_and_emits_signal() -> void:
	watch_signals(_rabbit)
	_rabbit.take_damage(50.0, "약")
	assert_eq(_rabbit.hp, _rabbit.stats.max_hp - 50.0)
	assert_signal_emitted(_rabbit, "took_damage")


func test_lethal_damage_emits_died() -> void:
	watch_signals(_rabbit)
	_rabbit.take_damage(9999.0)
	assert_signal_emitted(_rabbit, "died")
	assert_true(_rabbit.is_dead())


func test_attack_hitbox_body_entered_emits_attack_landed() -> void:
	watch_signals(_rabbit)
	_rabbit._on_attack_hitbox_body_entered(_target)
	assert_signal_emitted_with_parameters(_rabbit, "attack_landed", [_target])


## 디렉터 플레이 게이트 차단 버그(공격 시 자기 자신에게 피해)의 몬스터 쪽 대칭 확인 —
## 근접 스윙 히트박스는 몬스터 자신 위치에 겹쳐 생성되므로(monster_base.gd 주석),
## 충돌 레이어가 정리되어 있지 않으면 자기 자신이 attack_landed의 target으로 잡힌다.
func test_attack_hitbox_does_not_hit_itself_via_physics() -> void:
	watch_signals(_rabbit)
	_rabbit._enable_attack_hitbox()

	await wait_physics_frames(2)

	assert_signal_not_emitted(_rabbit, "attack_landed", "근접 판정이 몬스터 자기 자신을 target으로 잡으면 안 된다")
