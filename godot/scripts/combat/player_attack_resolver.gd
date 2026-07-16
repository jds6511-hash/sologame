## 전사 공격 판정 → 데미지 계산 → 타격 피드백 연결부 (CB-3·CB-7).
##
## player_controller.gd(CB-1)가 노출하는 attack_hit 시그널에 연결해, 판정이 성립한
## 순간 DamageCalculator(CB-3)로 데미지를 계산하고 HitFeedback(CB-7) 프리셋을 재생한다.
## Player 씬의 자식 노드로 배치하며, 부모(PlayerController)를 그대로 참조한다.
##
## 피격 대상 인터페이스는 scripts/ai/monster_base.gd(CB-6, 이미 구현됨)의 실제 계약을
## 그대로 따른다 — 구체 클래스를 몰라도 되는 오리 타이핑이다:
##   - 방어력 조회: get_combat_defense() -> float 메서드가 있으면 그것을 쓰고,
##     없으면 stats(Resource) 프로퍼티의 defense 필드를 읽는다(MonsterBase 방식).
##     둘 다 없으면 방어력 0으로 취급한다.
##   - 데미지 적용: take_damage(amount: float, hit_grade: String = "약",
##     attacker: Node2D = null) -> void. amount는 방어 감산·치명타·위치 보정까지
##     전부 반영된 "최종 데미지"이며(MonsterBase 주석: "최종 데미지 값을 그대로
##     HP에서 뺀다"), hit_grade는 "약"/"중"/"강" — 균열 점액 코어 파괴 분기(마지막
##     피격 등급) 등에 쓰인다. take_damage가 없는 대상은 데미지 적용을 건너뛰되
##     히트피드백은 그대로 재생한다(대상 없는 디버그 판정에도 타격감 확인 가능).
##
## 위치 보정(후방 공격 1.15)은 combat.md 6장에 "도적 계열 핵심 보너스"로 명시되어 있어
## 전사는 항상 1.0을 쓴다 — is_backattack은 항상 false로 고정한다.
class_name PlayerAttackResolver
extends Node

@export var attacker_stats: CombatantStats
@export var formula_data: DamageFormulaData
@export var preset_weak: HitFeedbackPreset
@export var preset_medium: HitFeedbackPreset
@export var preset_strong: HitFeedbackPreset

@onready var _player: PlayerController = get_parent()


func _ready() -> void:
	_player.attack_hit.connect(_on_attack_hit)


func _on_attack_hit(step_index: int, target: Node) -> void:
	var step: WarriorAttackStep = _player.combo_data.steps[step_index]
	var target_defense := _resolve_target_defense(target)

	var crit_chance := DamageCalculator.calculate_crit_chance(attacker_stats.agility, formula_data)
	var is_critical := DamageCalculator.roll_critical(crit_chance)
	var damage := DamageCalculator.calculate_damage(
		attacker_stats.attack_power,
		step.damage_coefficient,
		target_defense,
		formula_data,
		is_critical,
		false  ## 전사는 위치 보정 미적용 (도적 계열 전용, combat.md 6장)
	)

	## 치명타는 등급과 무관하게 항상 "강"으로 승격한다
	## (m2-warrior-skills.md 7장 "치명타(전 스킬 공통) = 강").
	var hit_grade := "강" if is_critical else step.hitstop_preset
	if target.has_method("take_damage"):
		target.take_damage(damage, hit_grade, _player)

	var preset := _preset_for_grade(hit_grade)
	var target_position: Vector2 = (
		target.global_position if target is Node2D else _player.global_position
	)
	HitFeedback.play(preset, target_position, target)


## MonsterBase(scripts/ai/monster_base.gd)는 get_combat_defense() 메서드가 없고,
## 대신 stats(Resource) 프로퍼티의 defense 필드로 방어력을 노출한다
## (scripts/ai/monster_stats_data.gd "CB-3 데미지 공식이 참조하는 방어력 값") — 두 접근
## 방식을 모두 지원해 어느 쪽 대상이든 동작한다.
func _resolve_target_defense(target: Node) -> float:
	if target.has_method("get_combat_defense"):
		return target.get_combat_defense()
	var target_stats: Variant = target.get("stats")
	if target_stats:
		var defense_value: Variant = target_stats.get("defense")
		if defense_value != null:
			return defense_value
	return 0.0


func _preset_for_grade(hit_grade: String) -> HitFeedbackPreset:
	match hit_grade:
		"중":
			return preset_medium
		"강":
			return preset_strong
		_:
			return preset_weak
