## M2 Phase3 검증 — PlayerStatsComponent의 HP/MP 실체(growth.md 1~3장), HP 차감·사망,
## 포션(쿨다운 8초·회복 30%·보스전 5회 캡), 자연 회복(전투 이탈 5초 후 초당 2%)이
## combat.md 5-4장 수치대로 동작하는지 확인한다.
##
## 사망은 M3 D3-2에서 "즉시 임시 리스폰"에서 **"HP 0 유지 + died 통보"**로 바뀌었다 — 실제
## 부활은 PlayerDeathSequence가 암전 구간에서 respawn()을 호출해 일으킨다. 이 파일은 그
## 계약의 스탯 쪽(사망 상태 유지·respawn 수치)만 보고, 단계 진행·연출은
## `test_player_death_sequence.gd`가 본다.
extends GutTest

var _player: PlayerController
var _stats: PlayerStatsComponent


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_stats = _player.get_node("PlayerStats")


func test_initial_hp_and_mp_match_combatant_stats() -> void:
	assert_eq(_stats.current_hp, 135.0, "growth.md 2-2 Lv1 전사 HP")
	assert_eq(_stats.current_mp, 72.0, "growth.md 1-2 공식: 30 + 지력8x5 + 레벨1x2 = 72")


func test_take_damage_reduces_hp() -> void:
	_stats.take_damage(50.0)
	assert_eq(_stats.current_hp, 85.0)


func test_take_damage_exceeding_hp_triggers_death_instead_of_negative_hp() -> void:
	## 초과 데미지를 받아도 HP는 음수가 아니라 정확히 0에서 멈추고, 그 상태가 **유지**된다 —
	## 사망 모션이 재생될 구간(is_dead() == true인 관측 가능한 시간)을 만드는 것이 목적이다.
	watch_signals(_stats)

	_stats.take_damage(9999.0)

	assert_eq(_stats.current_hp, 0.0)
	assert_true(_stats.is_dead(), "부활은 PlayerDeathSequence가 암전 구간에서 일으킨다")
	assert_signal_emitted(_stats, "died")


func test_get_combat_defense_matches_stats_defense_without_buff() -> void:
	assert_eq(_stats.get_combat_defense(), 14.0)


func test_respawn_restores_percent_and_teleports() -> void:
	_stats.set_respawn_position(Vector2(320, 192))
	_player.global_position = Vector2(500, 500)
	_stats.take_damage(9999.0)
	watch_signals(_stats)

	_stats.respawn(0.5, 0.5)

	assert_false(_stats.is_dead())
	assert_eq(_stats.current_hp, _stats.stats.max_hp * 0.5)
	assert_eq(_stats.current_mp, _stats.stats.max_mp * 0.5)
	assert_eq(_player.global_position, Vector2(320, 192))
	assert_signal_emitted(_stats, "respawned")


## hp_percent가 0이어도 HP 1은 남는다 — 부활 직후 다시 is_dead()가 되는 재사망 루프 방지.
func test_respawn_with_zero_percent_still_leaves_one_hp() -> void:
	_stats.take_damage(9999.0)

	_stats.respawn(0.0, 0.0)

	assert_eq(_stats.current_hp, 1.0)
	assert_false(_stats.is_dead())


func test_heal_does_not_exceed_max_hp() -> void:
	_stats.heal(9999.0)
	assert_eq(_stats.current_hp, _stats.stats.max_hp)


func test_mp_spend_and_has() -> void:
	assert_true(_stats.has_mp(72.0))
	assert_false(_stats.has_mp(72.1))
	_stats.spend_mp(20.0)
	assert_eq(_stats.current_mp, 52.0)


func test_mp_spend_does_not_go_below_zero() -> void:
	_stats.spend_mp(9999.0)
	assert_eq(_stats.current_mp, 0.0)


func test_defense_buff_increases_combat_defense_then_expires() -> void:
	_stats.apply_defense_buff(0.20, 5.0)
	assert_almost_eq(_stats.get_combat_defense(), 14.0 * 1.2, 0.001)
	_stats._process(4.99)
	assert_almost_eq(_stats.get_combat_defense(), 14.0 * 1.2, 0.001, "5초 전에는 유지")
	_stats._process(0.02)
	assert_eq(_stats.get_combat_defense(), 14.0, "5초 경과 후 버프 종료")


# --- 포션 (combat.md 5-4장) ---


func test_use_potion_heals_30_percent_and_starts_cooldown() -> void:
	_stats.take_damage(100.0)  ## 35 남음
	var healed := _stats.use_potion()
	assert_true(healed)
	assert_almost_eq(_stats.current_hp, 35.0 + 135.0 * 0.30, 0.001)
	assert_eq(_stats.get_potion_cooldown_remaining_sec(), 8.0)


func test_use_potion_fails_during_cooldown() -> void:
	_stats.use_potion()
	var second_attempt := _stats.use_potion()
	assert_false(second_attempt, "쿨다운 8초 이내 재사용은 실패해야 함")


func test_use_potion_succeeds_again_after_8_seconds() -> void:
	_stats.take_damage(100.0)
	_stats.use_potion()
	_stats._process(7.99)
	assert_false(_stats.use_potion(), "8초 전에는 아직 쿨다운 중")
	_stats._process(0.02)
	assert_true(_stats.use_potion(), "8초 경과 후 다시 사용 가능")


func test_boss_encounter_potion_hard_cap_is_5() -> void:
	_stats.start_boss_encounter()
	for i in range(5):
		_stats.take_damage(10.0)
		assert_true(_stats.use_potion(), "보스전 %d번째 포션은 성공해야 함" % (i + 1))
		_stats._process(8.0)  ## 쿨다운만 넘기고 캡은 유지
	_stats.take_damage(10.0)
	assert_false(_stats.use_potion(), "보스전 6번째 포션은 5회 하드 캡에 막혀야 함")


func test_boss_encounter_end_resets_cap() -> void:
	_stats.start_boss_encounter()
	for i in range(5):
		_stats.take_damage(10.0)
		_stats.use_potion()
		_stats._process(8.0)
	_stats.end_boss_encounter()
	_stats.start_boss_encounter()
	_stats.take_damage(10.0)
	assert_true(_stats.use_potion(), "보스 조우 재시작 시 캡 카운터가 초기화되어야 함")


# --- 자연 회복 (전투 이탈 5초 후 초당 2%) ---


func test_natural_regen_does_not_happen_within_5_sec_of_combat_action() -> void:
	_stats.take_damage(50.0)  ## 85 남음, 전투 행동 타이머 리셋
	_stats._process(4.99)
	assert_eq(_stats.current_hp, 85.0, "5초 전에는 자연 회복 없음")


func test_natural_regen_applies_2_percent_per_sec_after_5_sec_idle() -> void:
	_stats.take_damage(50.0)  ## 85 남음
	_stats._process(5.0)  ## 지연 시간(5초) 정확히 경과 — 아직 회복 없음
	assert_eq(_stats.current_hp, 85.0, "5초 시점까지는 회복이 없어야 함")
	_stats._process(1.0)  ## 이후 1초간 회복 적용
	assert_almost_eq(_stats.current_hp, 85.0 + 135.0 * 0.02, 0.01)


func test_natural_regen_stops_at_max_hp() -> void:
	_stats.take_damage(1.0)
	_stats._process(100.0)
	assert_eq(_stats.current_hp, _stats.stats.max_hp)
