## CB-3·CB-7 파이프라인 검증 — PlayerController.attack_hit 판정이 성립하면
## PlayerAttackResolver가 DamageCalculator로 데미지를 계산해 대상에 적용하고
## HitFeedback 프리셋을 재생하는지 확인한다(디버그 전투장 CB-9 이전 단계의 배선 검증).
## 대상 인터페이스는 scripts/ai/monster_base.gd(CB-6, 이미 구현됨)의 실제 계약
## (take_damage(amount, hit_grade, attacker), stats.defense 프로퍼티)을 그대로 모사한다.
##
## 치명타는 확률적으로 발생하므로(민첩 8 → 5.4%), 테스트는 실제 발생한
## hit_grade 값을 그대로 읽어 그에 맞는 기대값을 검증한다(둘 다 결정론적으로 통과).
extends GutTest

var _player: PlayerController
var _resolver: PlayerAttackResolver


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_resolver = _player.get_node("AttackResolver")


func test_attack_hit_applies_damage_to_target_with_get_combat_defense() -> void:
	var target := DummyCombatTarget.new()
	target.defense = 0.5  ## m2-monster-spec.md 3-1장 뿔토끼 방어력
	add_child_autofree(target)

	_resolver._on_attack_hit(0, target)  ## 1타, 계수 1.0

	assert_eq(target.take_damage_call_count, 1)
	assert_eq(target.last_attacker, _player)
	var base_reduced := 26.0 * (100.0 / 100.5)
	if target.last_hit_grade == "강":
		assert_between(target.last_damage, base_reduced * 1.5 * 0.95, base_reduced * 1.5 * 1.05)
	else:
		assert_between(target.last_damage, base_reduced * 0.95, base_reduced * 1.05)


func test_attack_hit_reads_defense_from_stats_property_when_no_getter() -> void:
	## scripts/ai/monster_base.gd 실제 방식: get_combat_defense() 없이 stats.defense만 노출.
	var target := DummyStatsCombatTarget.new()
	var stats := CombatantStats.new()
	stats.defense = 2.0  ## m2-monster-spec.md 3-2장 들개 마수 방어력
	target.stats = stats
	add_child_autofree(target)

	_resolver._on_attack_hit(0, target)

	assert_eq(target.take_damage_call_count, 1)
	var base_reduced := 26.0 * (100.0 / 102.0)
	if target.last_hit_grade == "강":
		assert_between(target.last_damage, base_reduced * 1.5 * 0.95, base_reduced * 1.5 * 1.05)
	else:
		assert_between(target.last_damage, base_reduced * 0.95, base_reduced * 1.05)


func test_attack_hit_plays_hitfeedback_matching_step_preset() -> void:
	var target := DummyCombatTarget.new()
	add_child_autofree(target)
	watch_signals(HitFeedback)

	_resolver._on_attack_hit(0, target)  ## 1타 hitstop_preset = "약"

	if target.last_hit_grade == "강":
		assert_signal_emitted_with_parameters(HitFeedback, "screen_shake_requested", [2])
	else:
		assert_signal_emitted_with_parameters(HitFeedback, "screen_shake_requested", [0])


func test_attack_hit_without_take_damage_method_does_not_error() -> void:
	var plain_target := Node2D.new()
	add_child_autofree(plain_target)

	_resolver._on_attack_hit(0, plain_target)  ## take_damage 없음 — 조용히 무시되어야 함

	assert_true(true, "예외 없이 통과하면 성공")


func test_attack_hit_flash_targets_the_hit_node() -> void:
	var target := DummyCombatTarget.new()
	add_child_autofree(target)
	watch_signals(HitFeedback)

	_resolver._on_attack_hit(0, target)

	assert_signal_emitted_with_parameters(HitFeedback, "hit_flash_requested", [target])
