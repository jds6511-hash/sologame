## CB-6 검증 — 공격 토큰 규칙(combat.md 2-2 "공격 토큰 최대 2마리") 재현.
extends GutTest


func before_each() -> void:
	PackAggroCoordinator.reset_all()


func test_solo_pack_id_always_succeeds() -> void:
	assert_true(PackAggroCoordinator.try_acquire_attack_token(""))
	assert_true(PackAggroCoordinator.try_acquire_attack_token(""))
	assert_true(PackAggroCoordinator.try_acquire_attack_token(""), "빈 pack_id(솔로 개체)는 토큰 제한 없음")


func test_max_2_tokens_per_pack() -> void:
	assert_true(PackAggroCoordinator.try_acquire_attack_token("a"))
	assert_true(PackAggroCoordinator.try_acquire_attack_token("a"))
	assert_false(PackAggroCoordinator.try_acquire_attack_token("a"), "3번째 토큰 획득은 실패해야 함(최대 2마리)")


func test_release_frees_a_slot() -> void:
	PackAggroCoordinator.try_acquire_attack_token("a")
	PackAggroCoordinator.try_acquire_attack_token("a")
	PackAggroCoordinator.release_attack_token("a")
	assert_true(PackAggroCoordinator.try_acquire_attack_token("a"))
	assert_eq(PackAggroCoordinator.get_active_token_count("a"), 2)


func test_different_packs_have_independent_token_pools() -> void:
	PackAggroCoordinator.try_acquire_attack_token("a")
	PackAggroCoordinator.try_acquire_attack_token("a")
	assert_true(PackAggroCoordinator.try_acquire_attack_token("b"), "다른 무리는 별도 토큰 풀을 가짐")


func test_release_below_zero_clamps_to_zero() -> void:
	PackAggroCoordinator.release_attack_token("never_acquired")
	assert_eq(PackAggroCoordinator.get_active_token_count("never_acquired"), 0)
