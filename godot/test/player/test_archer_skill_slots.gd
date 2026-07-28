## M3 C-4 검증 ① — m3-archer-skills.md 1·4장 궁수 스킬 세트(모험가 공용 3 재사용 + 궁수 1차
## 4종)의 슬롯 개방·계수·쿨다운·MP·투사체 발사가 문서 수치대로 동작하는지 확인한다.
## 기본 공격(활 사격)·조준 모드·후방 회피는 test_archer_aim_and_dodge.gd가 담당한다.
##
## player.tscn은 정식 흐름대로 모험가(공용 3종만 개방)로 시작하므로, 전직이 실제로 통과하는
## 경로와 동일한 apply_transition_loadout(job_def_archer.tres)로 궁수 로드아웃을 적용한다
## (test_warrior_skill_slots.gd와 같은 방식 — 공유 CombatantStats를 건드리는 실제 레벨업/
## 스탯 재계산 경로는 다른 테스트를 오염시키므로 쓰지 않는다).
##
## 화살은 씬 루트에 스폰되므로(플레이어를 따라가지 않게) after_each에서 직접 정리한다.
extends GutTest

const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")

const TOL := 0.0001

var _player: PlayerController
var _stats: PlayerStatsComponent


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_player.apply_transition_loadout(ARCHER_DEF.skill_loadout(), ARCHER_DEF.basic_combo)
	_stats = _player.get_node("PlayerStats")


func after_each() -> void:
	for arrow in _spawned_arrows():
		arrow.free()


## 씬 루트에 스폰된 화살 목록(발사 검증·정리 공용).
func _spawned_arrows() -> Array:
	var found: Array = []
	for child in get_tree().root.get_children():
		if child is ArrowProjectile:
			found.append(child)
	return found


func _max_mp() -> float:
	return _stats.stats.max_mp


# --- 전직 로드아웃: 8슬롯 개방 (1장 슬롯 구성 표) ---


func test_archer_job_definition_fills_all_eight_slots() -> void:
	var loadout := ARCHER_DEF.skill_loadout()
	assert_not_null(ARCHER_DEF.basic_combo, "궁수 기본 공격(활 연사) 콤보가 배선되어야 함")
	for slot in ["slot_1", "slot_2", "slot_3", "slot_4", "slot_q", "slot_e", "ultimate", "charge"]:
		assert_not_null(loadout.get(slot), "궁수 슬롯 %s 미개방" % slot)


func test_archer_transition_opens_named_slots_on_controller() -> void:
	assert_eq(_player.skill_slot_1.skill_name, "강타", "공용 3종은 그대로 재사용(3장)")
	assert_eq(_player.skill_slot_2.skill_name, "질주")
	assert_eq(_player.skill_slot_3.skill_name, "응급 처치")
	assert_eq(_player.skill_slot_4.skill_name, "속사")
	assert_eq(_player.skill_slot_q.skill_name, "곡예 사격")
	assert_eq(_player.skill_slot_e.skill_name, "매의 눈")
	assert_eq(_player.skill_ultimate.skill_name, "관통 폭사")
	assert_eq(_player.skill_charge.skill_name, "조준 모드")


# --- 속사 (슬롯 4 — 계수 0.8x3=2.4 / cd 7초 / MP 10% / 3연사 0.08초 간격) ---


func test_rapid_shot_spec_values() -> void:
	var skill: ArcherSkillData = _player.skill_slot_4
	assert_almost_eq(skill.damage_coefficient, 0.8, TOL, "발당 계수")
	assert_almost_eq(skill.damage_coefficient * skill.projectile_count, 2.4, TOL, "합계 계수 2.4")
	assert_almost_eq(skill.cooldown_sec, 7.0, TOL)
	assert_almost_eq(skill.mp_cost_percent, 0.10, TOL)
	assert_eq(skill.projectile_count, 3)
	assert_almost_eq(skill.projectile_interval_sec, 0.08, TOL)


func test_rapid_shot_consumes_mp_and_enters_cooldown() -> void:
	var before := _stats.current_mp
	assert_true(_player._try_use_skill("slot4", _player.skill_slot_4))
	assert_almost_eq(_stats.current_mp, before - _max_mp() * 0.10, TOL)
	assert_almost_eq(_player.get_skill_cooldown_remaining("slot4"), 7.0, TOL)
	assert_false(_player._try_use_skill("slot4", _player.skill_slot_4), "쿨다운 중 재사용 실패")


func test_rapid_shot_fires_three_arrows_at_interval() -> void:
	_player._try_use_skill("slot4", _player.skill_slot_4)
	_player._process_skill_state(0.2)  ## 선딜 종료 → ACTIVE, 1발째 발사
	assert_eq(_spawned_arrows().size(), 1, "연사 시작 시 1발째")

	_player._shots.advance(0.08)
	assert_eq(_spawned_arrows().size(), 2, "0.08초 후 2발째")

	_player._shots.advance(0.08)
	assert_eq(_spawned_arrows().size(), 3, "0.16초 후 3발째 — 총 3발")

	_player._shots.advance(0.08)
	assert_eq(_spawned_arrows().size(), 3, "예정 발수를 넘겨 쏘지 않아야 함")


func test_rapid_shot_arrows_are_non_piercing_with_5_5_tile_range() -> void:
	_player._try_use_skill("slot4", _player.skill_slot_4)
	_player._process_skill_state(0.2)
	var arrow: ArrowProjectile = _spawned_arrows()[0]
	assert_almost_eq(arrow._remaining_distance, 5.5 * 16.0, TOL)
	assert_eq(arrow._pierce_remaining, 0, "속사 화살은 단일 명중(비관통)")


func test_rapid_shot_burst_is_cancelled_when_interrupted() -> void:
	_player._try_use_skill("slot4", _player.skill_slot_4)
	_player._process_skill_state(0.2)
	_player._cancel_skill()  ## 피격 경직 등으로 중단

	_player._shots.advance(0.08)
	assert_eq(_spawned_arrows().size(), 1, "중단 후 남은 연사는 발사되지 않아야 함")


# --- 곡예 사격 (슬롯 Q — 계수 1.3 / cd 10초 / MP 10% / 2.5타일 0.3초 구르기 + 사격 1발) ---


func test_acrobatic_shot_spec_values() -> void:
	var skill: ArcherSkillData = _player.skill_slot_q
	assert_almost_eq(skill.damage_coefficient, 1.3, TOL)
	assert_almost_eq(skill.cooldown_sec, 10.0, TOL)
	assert_almost_eq(skill.mp_cost_percent, 0.10, TOL)
	assert_almost_eq(skill.dash_distance_tiles, 2.5, TOL)
	assert_almost_eq(skill.dash_duration_sec, 0.3, TOL)


func test_acrobatic_shot_moves_and_fires_one_arrow() -> void:
	_player._last_move_direction = Vector2.UP  ## 이동 방향은 입력, 사격 방향은 조준(독립)
	_player._try_use_skill("slot_q", _player.skill_slot_q)
	_player._process_skill_state(0.1)  ## 선딜 종료 → ACTIVE(구르기 시작 + 발사)
	_player._process_skill_state(0.0)  ## ACTIVE 프레임 — 이동 속도 반영

	assert_eq(_player.velocity, Vector2.UP * (16.0 * 2.5 / 0.3), "입력 방향으로 2.5타일/0.3초 구르기")
	assert_eq(_spawned_arrows().size(), 1, "구르며 화살 1발")
	assert_false(_player._attack_hitbox.monitoring, "곡예 사격은 근접 판정이 아니다")


# --- 매의 눈 (슬롯 E — 치명타 +15%p / 사거리 +1타일 / 공속 +15%, 8초 / cd 20초 / MP 20%) ---


func test_hawk_eye_spec_values() -> void:
	var skill: ArcherSkillData = _player.skill_slot_e
	assert_almost_eq(skill.crit_chance_bonus, 0.15, TOL)
	assert_almost_eq(skill.attack_range_bonus_tiles, 1.0, TOL)
	assert_almost_eq(skill.attack_speed_bonus_percent, 0.15, TOL)
	assert_almost_eq(skill.buff_duration_sec, 8.0, TOL)
	assert_almost_eq(skill.cooldown_sec, 20.0, TOL)
	assert_almost_eq(skill.mp_cost_percent, 0.20, TOL)


func test_hawk_eye_applies_and_expires_buff() -> void:
	_player._try_use_skill("slot_e", _player.skill_slot_e)
	_player._process_skill_state(0.3)  ## 선딜 종료 → 즉시 발동

	assert_almost_eq(_player.get_crit_chance_bonus(), 0.15, TOL)
	assert_almost_eq(_player.get_attack_range_bonus_tiles(), 1.0, TOL)

	_player._shots.advance(7.99)
	assert_almost_eq(_player.get_crit_chance_bonus(), 0.15, TOL, "8초 지속 — 아직 유효")
	_player._shots.advance(0.02)
	assert_almost_eq(_player.get_crit_chance_bonus(), 0.0, TOL, "만료 후 가산 해제")
	assert_almost_eq(_player.get_attack_range_bonus_tiles(), 0.0, TOL)


func test_hawk_eye_extends_arrow_range_by_one_tile() -> void:
	_player._try_use_skill("slot_e", _player.skill_slot_e)
	_player._process_skill_state(0.3)
	_player._end_skill()

	_player._start_attack_step(0)
	_player._process_attack_state(0.2)
	var arrow: ArrowProjectile = _spawned_arrows()[0]
	assert_almost_eq(arrow._remaining_distance, (5.0 + 1.0) * 16.0, TOL)


func test_hawk_eye_speeds_up_basic_attack_cycle() -> void:
	var step: WarriorAttackStep = _player.combo_data.steps[0]
	assert_almost_eq(_player._attack_rate_for_step(step), 1.0, TOL)

	_player._try_use_skill("slot_e", _player.skill_slot_e)
	_player._process_skill_state(0.3)
	assert_almost_eq(_player._attack_rate_for_step(step), 1.15, TOL, "공격 속도 +15%")


# --- 관통 폭사 (궁극기 R — 계수 8.0 / cd 75초 / MP 30% / 무제한 관통 / 선딜 슈퍼아머) ---


func test_piercing_burst_spec_values() -> void:
	var skill: ArcherSkillData = _player.skill_ultimate
	assert_almost_eq(skill.damage_coefficient, 8.0, TOL)
	assert_almost_eq(skill.cooldown_sec, 75.0, TOL)
	assert_almost_eq(skill.mp_cost_percent, 0.30, TOL)
	assert_almost_eq(skill.startup_sec, 0.6, TOL, "고정 선딜 0.6초(전사식 이산 차지 아님)")
	assert_eq(skill.hitstop_preset, "강")
	assert_true(skill.self_superarmor_during_cast)


func test_piercing_burst_grants_superarmor_during_startup() -> void:
	_player._try_use_skill("ultimate", _player.skill_ultimate)
	_player._update_superarmor_state(0.0)
	assert_true(_player.is_superarmor(), "정조준 선딜 구간은 슈퍼아머")


func test_piercing_burst_fires_unlimited_pierce_arrow() -> void:
	_player._try_use_skill("ultimate", _player.skill_ultimate)
	_player._process_skill_state(0.6)  ## 선딜 0.6초 종료 → 발사

	var arrows := _spawned_arrows()
	assert_eq(arrows.size(), 1, "초고속 관통 화살 1발")
	var arrow: ArrowProjectile = arrows[0]
	assert_eq(arrow._pierce_remaining, -1, "무제한 관통")
	assert_almost_eq(arrow._speed_px, 24.0 * 16.0, TOL, "24타일·초")
	assert_almost_eq(arrow._remaining_distance, 12.0 * 16.0, TOL, "사거리 12타일")
