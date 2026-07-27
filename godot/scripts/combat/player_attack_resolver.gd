## 전사 공격 판정 → 데미지 계산 → 타격 피드백 연결부 (CB-3·CB-7).
##
## player_controller.gd(CB-1/CB-2)가 노출하는 attack_hit(step, target) 시그널에 연결해,
## 판정이 성립한 순간 DamageCalculator(CB-3)로 데미지를 계산하고 HitFeedback(CB-7) 프리셋을
## 재생한다. Player 씬의 자식 노드로 배치하며, 부모(PlayerController)를 그대로 참조한다.
##
## step은 기본 콤보의 WarriorAttackStep일 수도, 스킬(CB-2)의 WarriorSkillData일 수도 있다
## — PlayerController가 어느 쪽이든 damage_coefficient/hitstop_preset 필드를 노출하는
## 리소스를 그대로 넘겨주므로(duck typing), 이 리졸버는 어느 쪽인지 구분할 필요가 없다.
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

## 스킬(WarriorSkillData) 명중 전용 SFX — 기본 콤보 히트음(프리셋 sfx_stream)과 별개로
## 스킬 명중에만 덧씌운다. 몬스터 사망(died 시그널 소비) SFX도 함께 담당한다(SD-1).
const SKILL_HIT_SFX := preload("res://assets/audio/sfx/sfx_combat_skill_hit.wav")
const MONSTER_DEATH_SFX := preload("res://assets/audio/sfx/sfx_combat_monster_death.wav")

@export var attacker_stats: CombatantStats
@export var formula_data: DamageFormulaData
@export var preset_weak: HitFeedbackPreset
@export var preset_medium: HitFeedbackPreset
@export var preset_strong: HitFeedbackPreset

@onready var _player: PlayerController = get_parent()
## 스킬 강화 계수 반영용(M3 B-3). 스킬(WarriorSkillData) 판정에만 런타임 강화 배율을 곱한다.
## 노드가 없는 씬/테스트에서는 null → base 계수 그대로(하위 호환).
@onready var _skill_points: PlayerSkillPoints = get_node_or_null("../PlayerSkillPoints")


func _ready() -> void:
	_player.attack_hit.connect(_on_attack_hit)


func _on_attack_hit(step, target: Node) -> void:
	var target_defense := _resolve_target_defense(target)

	## 스킬은 강화 레벨에 따라 계수가 오른다(spec 6-2, +8%/레벨). 기본 콤보(WarriorAttackStep)는
	## 강화 대상이 아니므로 base 계수를 그대로 쓴다. 차지 강타는 홀드 비율로 이미 덮어쓴
	## damage_coefficient에 배율이 곱해지는데, k x lerp(a,b,t) = lerp(k*a, k*b, t)이므로
	## "charge_min/max 두 값에 동일 배율" 규격과 결과가 일치한다.
	var coefficient: float = step.damage_coefficient
	if step is WarriorSkillData and _skill_points != null:
		coefficient = _skill_points.effective_coefficient(
			step.damage_coefficient, StringName(step.skill_name)
		)

	var crit_chance := DamageCalculator.calculate_crit_chance(attacker_stats.agility, formula_data)
	var is_critical := DamageCalculator.roll_critical(crit_chance)
	## 마지막 인자 false = 위치 보정 미적용(전사는 후방 보정 없음, 도적 계열 전용 — combat.md 6장).
	var damage := DamageCalculator.calculate_damage(
		attacker_stats.attack_power, coefficient, target_defense, formula_data, is_critical, false
	)

	## 치명타는 등급과 무관하게 항상 "강"으로 승격한다
	## (m2-warrior-skills.md 7장 "치명타(전 스킬 공통) = 강").
	var hit_grade: String = "강" if is_critical else step.hitstop_preset
	var target_position: Vector2 = (
		target.global_position if target is Node2D else _player.global_position
	)
	## 몬스터 died 시그널은 take_damage() 안에서 동기(synchronous)로 발신되므로(scripts/ai/
	## monster_base.gd), take_damage 호출 전에 미리 연결해 둬야 사망 SFX를 놓치지 않는다.
	if target.has_signal("died"):
		target.died.connect(_on_target_died.bind(target_position), CONNECT_ONE_SHOT)
	if target.has_method("take_damage"):
		target.take_damage(damage, hit_grade, _player)

	if step is WarriorSkillData:
		HitFeedback.play_sfx(SKILL_HIT_SFX, target_position)

	var preset := _preset_for_grade(hit_grade)
	HitFeedback.play(preset, target_position, target)


func _on_target_died(at_position: Vector2) -> void:
	HitFeedback.play_sfx(MONSTER_DEATH_SFX, at_position)


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
