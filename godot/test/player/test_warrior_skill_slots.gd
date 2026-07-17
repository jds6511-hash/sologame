## CB-2 검증 — m2-warrior-skills.md 3~5장 전사 스킬 세트(모험가 공용 3 + 전사 1차 4 +
## 우클릭 차지 강타)의 쿨다운·MP 소모·판정·자기 버프/힐·슈퍼아머가 문서 수치대로
## 동작하는지 확인한다. 히트박스 판정 성립 시 attack_hit(step, target)에 스킬 데이터
## 자체를 실어 보내 PlayerAttackResolver가 자동 소비하는지도 함께 검증한다
## (combo와 동일한 duck-typing 파이프라인, test_player_attack_resolver.gd와 대응).
extends GutTest

var _player: PlayerController
var _stats: PlayerStatsComponent


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_stats = _player.get_node("PlayerStats")


# --- 강타 (슬롯1, 즉발) ---


func test_slot1_strike_starts_startup_and_consumes_mp() -> void:
	var used := _player._try_use_skill("slot1", _player.skill_slot_1)
	assert_true(used)
	assert_eq(_player.skill_state, PlayerController.AttackState.STARTUP)
	assert_eq(_player.active_skill, _player.skill_slot_1)
	assert_almost_eq(_stats.current_mp, 72.0 - 72.0 * 0.08, 0.001)


func test_slot1_strike_respects_cooldown() -> void:
	_player._try_use_skill("slot1", _player.skill_slot_1)
	var second := _player._try_use_skill("slot1", _player.skill_slot_1)
	assert_false(second, "쿨다운(5초) 중 재사용은 실패해야 함")


func test_slot1_strike_fails_when_insufficient_mp() -> void:
	_stats.spend_mp(72.0)  ## MP 전부 소진
	var used := _player._try_use_skill("slot1", _player.skill_slot_1)
	assert_false(used)
	assert_eq(_player.skill_state, PlayerController.AttackState.NONE)


func test_slot1_strike_reaches_active_and_enables_hitbox_after_startup() -> void:
	_player._try_use_skill("slot1", _player.skill_slot_1)
	_player._process_skill_state(0.25)  ## 선딜 0.25초
	assert_eq(_player.skill_state, PlayerController.AttackState.ACTIVE)
	assert_eq(_player._current_action_step, _player.skill_slot_1)


func test_slot1_strike_hit_emits_attack_hit_with_skill_as_step() -> void:
	_player._try_use_skill("slot1", _player.skill_slot_1)
	_player._process_skill_state(0.25)  ## ACTIVE 진입 — 히트박스 활성화
	var target := Node2D.new()
	add_child_autofree(target)
	watch_signals(_player)

	_player._on_attack_hitbox_body_entered(target)

	assert_signal_emitted_with_parameters(_player, "attack_hit", [_player.skill_slot_1, target])


func test_slot1_strike_ends_after_full_motion() -> void:
	_player._try_use_skill("slot1", _player.skill_slot_1)
	_player._process_skill_state(0.25)  ## STARTUP -> ACTIVE
	_player._process_skill_state(0.1)  ## ACTIVE -> RECOVERY
	_player._process_skill_state(0.3)  ## RECOVERY -> NONE
	assert_eq(_player.skill_state, PlayerController.AttackState.NONE)
	assert_null(_player.active_skill)


# --- 응급 처치 (슬롯3, 버프·힐) ---


func test_slot3_first_aid_heals_20_percent_max_hp() -> void:
	_stats.take_damage(100.0)  ## 35 남음
	_player._try_use_skill("slot3", _player.skill_slot_3)
	_player._process_skill_state(0.3)  ## 선딜 종료 — 즉시 발동(active_sec=0)
	assert_almost_eq(_stats.current_hp, 35.0 + 135.0 * 0.20, 0.001)


# --- 결의의 외침 (슬롯E/슬롯6, 버프) ---


func test_slot_e_battle_shout_grants_superarmor_and_defense_buff() -> void:
	_player._try_use_skill("slot_e", _player.skill_slot_e)
	_player._process_skill_state(0.4)  ## 선딜 종료 — 버프 적용
	_player._update_superarmor_state(0.0)
	assert_true(_player.is_superarmor())
	assert_almost_eq(_stats.get_combat_defense(), 14.0 * 1.2, 0.001)


func test_superarmor_blocks_take_hit_stun_but_damage_still_applies_via_take_damage() -> void:
	_player._try_use_skill("slot_e", _player.skill_slot_e)
	_player._process_skill_state(0.4)
	_player._update_superarmor_state(0.0)

	_player.take_hit(false, Vector2.RIGHT)
	assert_false(_player.is_hit_stunned, "슈퍼아머 중에는 경직이 걸리지 않아야 함")

	_player.take_damage(10.0)
	assert_eq(_stats.current_hp, 125.0, "슈퍼아머는 무적이 아니므로 피해는 그대로 적용")


# --- 질주 (슬롯2, 이동기 — 판정 범위 미기재로 히트박스 없이 이동만 구현) ---


func test_slot2_sprint_moves_without_enabling_hitbox() -> void:
	_player._last_move_direction = Vector2.RIGHT
	_player._try_use_skill("slot2", _player.skill_slot_2)
	_player._process_skill_state(0.1)  ## STARTUP -> ACTIVE (전이만, 속도는 다음 호출에 반영)
	_player._process_skill_state(0.0)  ## ACTIVE 프레임 — 이동 속도 반영
	assert_eq(_player.velocity, Vector2.RIGHT * (16.0 * 2.0 / 0.25))
	assert_false(_player._attack_hitbox.monitoring, "질주는 판정 범위 미기재 스킬 — 히트박스 없음")


# --- 돌격 (슬롯Q/슬롯5, 이동기 — 히트박스 있음) ---


func test_slot_q_charge_rush_moves_and_enables_hitbox() -> void:
	_player._last_move_direction = Vector2.UP
	_player._try_use_skill("slot_q", _player.skill_slot_q)
	_player._process_skill_state(0.1)  ## STARTUP -> ACTIVE (전이만, 속도는 다음 호출에 반영)
	_player._process_skill_state(0.0)  ## ACTIVE 프레임 — 이동 속도 반영
	assert_eq(_player.velocity, Vector2.UP * (16.0 * 2.5 / 0.3))
	assert_true(_player._attack_hitbox.monitoring)


# --- 대지 분쇄 (궁극기, R) ---


func test_ultimate_earth_smash_grants_superarmor_during_cast() -> void:
	_player._try_use_skill("ultimate", _player.skill_ultimate)
	assert_true(_player.skill_state == PlayerController.AttackState.STARTUP)
	_player._update_superarmor_state(0.0)
	assert_true(_player.is_superarmor(), "대지 분쇄는 선딜~판정 구간 슈퍼아머 유지")


func test_ultimate_cooldown_is_75_sec() -> void:
	_player._try_use_skill("ultimate", _player.skill_ultimate)
	_player._update_skill_cooldowns(74.99)
	assert_false(_player._try_use_skill("ultimate", _player.skill_ultimate))
	## 진행 중인 스킬 상태를 정리해야 재사용 조건(쿨다운)만 검증 가능
	_player._cancel_skill()
	_player._update_skill_cooldowns(0.02)
	assert_true(_player._try_use_skill("ultimate", _player.skill_ultimate))


# --- 차지 강타 (우클릭 홀드) ---


func test_charge_release_below_min_hold_cancels_without_cost() -> void:
	_player._is_charging_secondary = true
	_player._charge_hold_timer = 0.1  ## 최소 홀드 0.3초 미만
	_player._release_charge()
	assert_eq(_player.skill_state, PlayerController.AttackState.NONE, "취소 — 스킬 발동 없음")
	assert_eq(_stats.current_mp, 72.0, "취소 시 MP 소모 없음")


func test_charge_release_at_min_hold_uses_min_coefficient_and_recovery() -> void:
	_player._is_charging_secondary = true
	_player._charge_hold_timer = 0.3
	_player._release_charge()
	assert_eq(_player.skill_state, PlayerController.AttackState.ACTIVE)
	assert_almost_eq(_player.skill_charge.damage_coefficient, 1.6, 0.001)
	assert_almost_eq(_player.skill_charge.recovery_sec, 0.5, 0.001)


func test_charge_release_at_max_hold_uses_max_coefficient_and_recovery() -> void:
	_player._is_charging_secondary = true
	_player._charge_hold_timer = 1.2
	_player._release_charge()
	_player._update_superarmor_state(0.0)
	assert_almost_eq(_player.skill_charge.damage_coefficient, 3.0, 0.001)
	assert_almost_eq(_player.skill_charge.recovery_sec, 0.7, 0.001)
	assert_true(_player.is_superarmor(), "차지 강타는 홀드~타격 종료까지 슈퍼아머")


func test_charge_hold_cancelled_by_movement_input() -> void:
	_player._is_charging_secondary = true
	_player._charge_hold_timer = 0.5
	_player._move_input = Vector2.RIGHT
	_player._process_charge_hold(0.1)
	assert_false(_player._is_charging_secondary, "이동 시 차징이 취소되어야 함(combat.md 3장)")
	assert_eq(_player.skill_state, PlayerController.AttackState.NONE)
