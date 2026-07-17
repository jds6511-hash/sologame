## CB-6 검증 — 균열 점액 상태 전이·코어 파괴/자폭 분기(m2-monster-spec.md 3-3장) 재현.
extends GutTest

var _slime: RiftSlimeMonster
var _target: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/monsters/rift_slime.tscn")
	_slime = scene.instantiate()
	add_child_autofree(_slime)
	_target = Node2D.new()
	add_child_autofree(_target)
	_slime.global_position = Vector2.ZERO
	_target.global_position = Vector2(1000, 1000)
	_slime.target = _target


## self_destructed 분기가 get_tree().root에 직접 스폰하는 RiftSlimeAcidPool은
## add_child_autofree 대상이 아니라 각 테스트가 남긴 웅덩이가 다음 테스트로 새어나갈 수
## 있다 — queue_free()는 삭제를 다음 프레임으로 미루므로, 프레임 경계 없이 연달아 도는
## GUT 동기 테스트 사이에서는 즉시 free()로 확실히 정리한다.
func after_each() -> void:
	for child in get_tree().root.get_children():
		if child is RiftSlimeAcidPool:
			get_tree().root.remove_child(child)
			child.free()


func test_initial_state_is_wander() -> void:
	assert_eq(_slime.state, RiftSlimeMonster.State.WANDER)


func test_enters_aim_when_target_within_perception_range() -> void:
	_target.global_position = _slime.global_position + Vector2(3 * 16, 0)  ## 인지범위 4타일 이내
	_slime._physics_process(0.016)
	assert_eq(_slime.state, RiftSlimeMonster.State.AIM)


func test_fires_projectile_after_telegraph_and_enters_cooldown() -> void:
	_target.global_position = _slime.global_position + Vector2(3 * 16, 0)
	watch_signals(_slime)
	_slime._start_aim()
	_slime._physics_process(1.0)  ## 조준 예고 0.7초 초과 -> 발사
	assert_signal_emitted(_slime, "projectile_fired")
	assert_eq(_slime.state, RiftSlimeMonster.State.COOLDOWN)


func test_cooldown_returns_to_aim_after_cooldown_duration_when_still_in_range() -> void:
	_target.global_position = _slime.global_position + Vector2(3 * 16, 0)
	_slime._start_aim()
	_slime._physics_process(1.0)  ## AIM -> 발사 -> COOLDOWN
	_slime._physics_process(2.0)  ## 쿨다운 1.2초 초과 -> 재조준
	assert_eq(_slime.state, RiftSlimeMonster.State.AIM, "spec: 사거리 이내인 한 조준 재시도 반복")


func test_leaving_range_during_aim_returns_to_wander() -> void:
	_target.global_position = _slime.global_position + Vector2(3 * 16, 0)
	_slime._start_aim()
	_target.global_position = _slime.global_position + Vector2(1000, 0)  ## 사거리 이탈
	_slime._physics_process(0.1)
	assert_eq(_slime.state, RiftSlimeMonster.State.WANDER)


func test_strong_hit_finish_triggers_core_break_not_self_destruct() -> void:
	watch_signals(_slime)
	_slime.take_damage(9999.0, "강")
	assert_signal_emitted(_slime, "core_broken")
	assert_signal_not_emitted(_slime, "self_destructed")


func test_weak_hit_finish_triggers_self_destruct_not_core_break() -> void:
	watch_signals(_slime)
	_slime.take_damage(9999.0, "약")
	assert_signal_emitted(_slime, "self_destructed")
	assert_signal_not_emitted(_slime, "core_broken")


func test_medium_hit_finish_also_triggers_self_destruct() -> void:
	watch_signals(_slime)
	_slime.take_damage(9999.0, "중")
	assert_signal_emitted(_slime, "self_destructed")
	assert_signal_not_emitted(_slime, "core_broken")


# --- 산성 웅덩이 실제 스폰 (M2 후반 통합, 2026-07-17) ---


func test_self_destruct_spawns_acid_pool_at_death_position() -> void:
	_slime.global_position = Vector2(320, 240)
	_slime.take_damage(9999.0, "약")
	var pool: RiftSlimeAcidPool = null
	for child in get_tree().root.get_children():
		if child is RiftSlimeAcidPool:
			pool = child
	assert_not_null(pool, "약/중 등급 마무리 시 산성 웅덩이가 스폰되어야 함")
	assert_eq(pool.global_position, Vector2(320, 240))


func test_core_break_does_not_spawn_acid_pool() -> void:
	_slime.take_damage(9999.0, "강")
	for child in get_tree().root.get_children():
		assert_false(child is RiftSlimeAcidPool, "코어 파괴(강 등급 마무리)는 자폭 웅덩이가 없어야 함")
