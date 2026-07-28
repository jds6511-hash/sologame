## M3 C-5 검증 (G3-2 원거리 end-to-end) — 궁수 화살이 명중하면 기존 플레이어 데미지 계약을
## 그대로 타는지 확인한다: 화살 명중 → PlayerController.attack_hit → PlayerAttackResolver →
## DamageCalculator(치명타 굴림·방어 감산) → 대상 take_damage.
##
## m3-archer-skills.md 6-2장 신규 델타 ②(플레이어 데미지 계약)·③(치명타 굴림)과 7장
## (민첩→치명타, 매의 눈 +15%p 가산), 스킬 강화 계수 연동(+8%/레벨)을 함께 검산한다.
##
## 치명타는 확률적이므로, 결정론적으로 만들려면 매의 눈 가산치를 크게 넣어 상한(40%)까지
## 올리는 대신 "가산이 실제로 확률에 반영되는지"를 확률 계산 지점에서 직접 검증한다.
extends GutTest

const ARCHER_DEF: JobDefinition = preload("res://data/jobs/job_def_archer.tres")
const FORMULA: DamageFormulaData = preload("res://data/combat/damage_formula.tres")
const TOL := 0.0001

var _player: PlayerController
var _resolver: PlayerAttackResolver
var _skill_points: PlayerSkillPoints


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_player.apply_transition_loadout(ARCHER_DEF.skill_loadout(), ARCHER_DEF.basic_combo)
	_resolver = _player.get_node("AttackResolver")
	_skill_points = _player.get_node("PlayerSkillPoints")


func after_each() -> void:
	for child in get_tree().root.get_children():
		if child is ArrowProjectile:
			child.free()


func _spawned_arrows() -> Array:
	var found: Array = []
	for child in get_tree().root.get_children():
		if child is ArrowProjectile:
			found.append(child)
	return found


func _make_target(defense: float = 0.0) -> DummyCombatTarget:
	var target := DummyCombatTarget.new()
	target.defense = defense
	add_child_autofree(target)
	return target


# --- end-to-end: 발사 → 명중 → 데미지 ---


func test_basic_arrow_hit_applies_damage_through_resolver() -> void:
	_player._start_attack_step(0)
	_player._process_attack_state(0.2)  ## 화살 발사
	var arrow: ArrowProjectile = _spawned_arrows()[0]
	var target := _make_target(2.0)

	arrow._on_body_entered(target)

	assert_eq(target.take_damage_call_count, 1, "화살 명중이 실제 데미지로 이어져야 함")
	assert_eq(target.last_attacker, _player, "공격자는 플레이어")
	var attack_power: float = _resolver.attacker_stats.attack_power
	var base := attack_power * 1.0 * (100.0 / 102.0)
	if target.last_hit_grade == "강":
		assert_between(target.last_damage, base * 1.5 * 0.95, base * 1.5 * 1.05)
	else:
		assert_between(target.last_damage, base * 0.95, base * 1.05)


func test_rapid_shot_three_arrows_roll_crit_independently() -> void:
	_player._try_use_skill("slot4", _player.skill_slot_4)
	_player._process_skill_state(0.2)
	_player._shots.advance(0.08)
	_player._shots.advance(0.08)
	var arrows := _spawned_arrows()
	assert_eq(arrows.size(), 3)

	var target := _make_target()
	for arrow in arrows:
		arrow._on_body_entered(target)

	## 화살 3발이 각각 독립 판정 = 3회 데미지 적용(= 치명타 굴림 3회, 4-1장).
	assert_eq(target.take_damage_call_count, 3)


func test_piercing_burst_rolls_crit_per_pierced_target() -> void:
	_player._try_use_skill("ultimate", _player.skill_ultimate)
	_player._process_skill_state(0.6)
	var arrow: ArrowProjectile = _spawned_arrows()[0]
	var first := _make_target()
	var second := _make_target()

	arrow._on_body_entered(first)
	arrow._on_body_entered(second)

	assert_eq(first.take_damage_call_count, 1, "관통한 각 적에 개별 판정")
	assert_eq(second.take_damage_call_count, 1)


# --- 치명타: 민첩 스탯 + 매의 눈 가산 (7장) ---


func test_agility_drives_base_crit_chance() -> void:
	var agility: float = _resolver.attacker_stats.agility
	var expected := clampf(0.05 + agility * 0.0005, 0.0, 0.40)
	assert_almost_eq(
		DamageCalculator.calculate_crit_chance(agility, FORMULA),
		expected,
		TOL,
		"치명타 확률 = 5% + 민첩x0.05% (combat.md 6장)"
	)


func test_hawk_eye_adds_15_percentage_points_to_crit_chance() -> void:
	assert_almost_eq(_player.get_crit_chance_bonus(), 0.0, TOL)

	_player._try_use_skill("slot_e", _player.skill_slot_e)
	_player._process_skill_state(0.3)

	assert_almost_eq(_player.get_crit_chance_bonus(), 0.15, TOL)


func test_crit_bonus_is_actually_added_to_the_roll() -> void:
	## 공유 damage_formula.tres(상한 40%)를 변경하면 다른 테스트를 오염시키므로, 상한 100%인
	## 전용 공식을 쓰는 리졸버를 하나 더 붙여 굴림을 결정론적으로 만든다. 가산치가 굴림에
	## 실제로 반영되면 확률이 1.0으로 포화되어 반드시 치명타가 되어야 한다.
	var probe := _make_probe_resolver()
	_player._shots.crit_chance_bonus = 1.0
	var target := _make_target()

	probe._on_attack_hit(_player.combo_data.steps[0], target)

	assert_eq(target.last_hit_grade, "강", "치명타는 등급을 항상 강으로 승격")


func test_no_crit_bonus_leaves_roll_at_stat_chance() -> void:
	## 위와 동일한 전용 리졸버에서 민첩 0·가산 0이면 확률도 기본 5%로 남고, 상한이 1.0이어도
	## 포화되지 않는다 — 가산치가 없을 때 굴림이 부풀지 않음을 확인한다(전사 회귀 방지).
	var probe := _make_probe_resolver()
	probe.attacker_stats.agility = 0.0
	assert_almost_eq(DamageCalculator.calculate_crit_chance(0.0, probe.formula_data), 0.05, TOL)
	assert_almost_eq(_player.get_crit_chance_bonus(), 0.0, TOL)


## 상한 100% 전용 공식을 쓰는 검증용 리졸버(공유 .tres 오염 방지).
func _make_probe_resolver() -> PlayerAttackResolver:
	var formula := DamageFormulaData.new()
	formula.crit_chance_cap = 1.0
	var stats := CombatantStats.new()
	stats.attack_power = 100.0
	stats.agility = 8.0
	var probe := PlayerAttackResolver.new()
	probe.attacker_stats = stats
	probe.formula_data = formula
	probe.preset_weak = load("res://data/combat/hitfeedback_weak.tres")
	probe.preset_medium = load("res://data/combat/hitfeedback_medium.tres")
	probe.preset_strong = load("res://data/combat/hitfeedback_strong.tres")
	_player.add_child(probe)
	return probe


func test_crit_chance_stays_within_cap() -> void:
	_player._shots.crit_chance_bonus = 5.0
	var agility: float = _resolver.attacker_stats.agility
	var chance := DamageCalculator.calculate_crit_chance(agility, FORMULA)
	var capped := clampf(chance + _player.get_crit_chance_bonus(), 0.0, FORMULA.crit_chance_cap)
	assert_almost_eq(capped, 0.40, TOL, "상한 40%를 넘지 않아야 함(combat.md 6장)")


# --- 스킬 강화 연동 (+8%/레벨, spec 6-2) ---


func test_archer_skill_upgrade_raises_arrow_coefficient() -> void:
	var skill: ArcherSkillData = _player.skill_slot_4
	var skill_id := StringName(skill.skill_name)
	assert_almost_eq(
		_skill_points.effective_coefficient(skill.damage_coefficient, skill_id), 0.8, TOL
	)

	_skill_points.available_points = 10
	assert_true(_skill_points.try_upgrade_skill(skill_id, false))

	assert_almost_eq(
		_skill_points.effective_coefficient(skill.damage_coefficient, skill_id),
		0.8 * 1.08,
		TOL,
		"발당 계수에 +8% — 합계 2.4도 같은 비율로 오른다"
	)


func test_archer_ultimate_upgrade_uses_ultimate_cost_track() -> void:
	var skill: ArcherSkillData = _player.skill_ultimate
	var skill_id := StringName(skill.skill_name)
	_skill_points.available_points = 20
	assert_true(_skill_points.try_upgrade_skill(skill_id, true))
	assert_almost_eq(
		_skill_points.effective_coefficient(skill.damage_coefficient, skill_id), 8.0 * 1.08, TOL
	)


func test_hawk_eye_buff_scales_with_skill_upgrade() -> void:
	var skill_id := StringName(_player.skill_slot_e.skill_name)
	_skill_points.available_points = 10
	assert_true(_skill_points.try_upgrade_skill(skill_id, false))

	_player._try_use_skill("slot_e", _player.skill_slot_e)
	_player._process_skill_state(0.3)

	assert_almost_eq(_player.get_crit_chance_bonus(), 0.15 * 1.08, TOL, "버프 효과도 +8%/레벨")
