## CB-6 검증 — 들개 마수 상태 전이·무리 어그로 공유·공격 토큰 규칙(m2-monster-spec.md 3-2장,
## combat.md 2-2장) 재현.
extends GutTest

const WOLF_SCENE := preload("res://scenes/monsters/wolf.tscn")

var _wolf: WolfMonster
var _target: Node2D


func before_each() -> void:
	PackAggroCoordinator.reset_all()
	_wolf = WOLF_SCENE.instantiate()
	add_child_autofree(_wolf)
	_target = Node2D.new()
	add_child_autofree(_target)
	_wolf.global_position = Vector2.ZERO
	_target.global_position = Vector2(1000, 1000)
	_wolf.target = _target


func test_initial_state_is_wander() -> void:
	assert_eq(_wolf.state, WolfMonster.State.WANDER)


func test_enters_chase_when_target_within_perception_range() -> void:
	_target.global_position = _wolf.global_position + Vector2(4 * 16, 0)  ## 인지범위 5타일 이내
	_wolf._physics_process(0.016)
	assert_eq(_wolf.state, WolfMonster.State.CHASE)


func test_chase_enters_melee_swing_when_in_range_with_token() -> void:
	_wolf._enter_chase(_target)
	_target.global_position = _wolf.global_position + Vector2(20, 0)  ## 근접범위 1.5타일(24px) 이내
	_wolf._physics_process(0.016)
	assert_eq(_wolf.state, WolfMonster.State.MELEE_SWING)


func test_chase_waits_when_no_attack_token_available() -> void:
	_wolf.pack_id = "pack_a"
	PackAggroCoordinator.try_acquire_attack_token("pack_a")
	PackAggroCoordinator.try_acquire_attack_token("pack_a")  ## 토큰 2개 모두 소모(다른 무리원 2마리 가정)
	_wolf._enter_chase(_target)
	_target.global_position = _wolf.global_position + Vector2(20, 0)
	_wolf._physics_process(0.016)
	assert_eq(_wolf.state, WolfMonster.State.CHASE, "토큰이 없으면 근접 스윙 대신 포위 대기(추적 유지)")


func test_melee_swing_full_cycle_releases_token_and_returns_to_chase() -> void:
	_wolf.pack_id = "pack_b"
	_wolf._enter_chase(_target)
	_target.global_position = _wolf.global_position + Vector2(20, 0)
	_wolf._physics_process(0.016)  ## CHASE -> 토큰 획득 -> MELEE_SWING
	assert_eq(_wolf.state, WolfMonster.State.MELEE_SWING)
	assert_eq(PackAggroCoordinator.get_active_token_count("pack_b"), 1)
	_wolf._physics_process(1.0)  ## 예고 -> 판정
	_wolf._physics_process(1.0)  ## 판정 -> 후딜
	_wolf._physics_process(1.0)  ## 후딜 종료 -> 추적 복귀 + 토큰 반납
	assert_eq(_wolf.state, WolfMonster.State.CHASE, "spec: 쿨다운 없이 추적 재접근")
	assert_eq(PackAggroCoordinator.get_active_token_count("pack_b"), 0)


func test_chase_transitions_to_return_when_leash_exceeded() -> void:
	_wolf._enter_chase(_target)
	_wolf.home_position = Vector2.ZERO
	_wolf.global_position = Vector2(9 * 16, 0)  ## 추적 한계 8타일 초과
	_target.global_position = _wolf.global_position + Vector2(1000, 0)  ## 근접범위 밖 유지
	_wolf._physics_process(0.016)
	assert_eq(_wolf.state, WolfMonster.State.RETURN)


func test_return_restores_hp_and_goes_to_wander_on_arrival() -> void:
	_wolf.hp = 1.0
	_wolf.home_position = Vector2.ZERO
	_wolf.global_position = Vector2(1.0, 0.0)  ## 도착 허용 오차 이내
	_wolf._process_return()
	assert_eq(_wolf.state, WolfMonster.State.WANDER)
	assert_eq(_wolf.hp, _wolf.stats.max_hp, "spec: 귀환 시 HP 완전 회복")


func test_pack_member_aggro_shared_when_one_member_hit() -> void:
	var wolf_b: WolfMonster = WOLF_SCENE.instantiate()
	add_child_autofree(wolf_b)
	_wolf.pack_id = "shared"
	wolf_b.pack_id = "shared"
	_wolf.add_to_group(_wolf._pack_group_name())
	wolf_b.add_to_group(wolf_b._pack_group_name())

	wolf_b.take_damage(10.0, "약", _target)

	assert_eq(_wolf.state, WolfMonster.State.CHASE, "무리원 1마리가 피격되면 배회 중인 다른 무리원도 추적 돌입(어그로 공유)")


func test_take_damage_reduces_hp_and_emits_signal() -> void:
	watch_signals(_wolf)
	_wolf.take_damage(50.0, "중")
	assert_eq(_wolf.hp, _wolf.stats.max_hp - 50.0)
	assert_signal_emitted(_wolf, "took_damage")


func test_attack_hitbox_body_entered_emits_attack_landed() -> void:
	watch_signals(_wolf)
	_wolf._on_attack_hitbox_body_entered(_target)
	assert_signal_emitted_with_parameters(_wolf, "attack_landed", [_target])
