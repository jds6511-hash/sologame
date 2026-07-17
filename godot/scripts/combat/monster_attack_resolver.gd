## 몬스터 공격 판정 → 플레이어 피격 반응·실데미지 연결부 (CB-4, M2 Phase3 실데미지 연동).
##
## scripts/ai/monster_base.gd(CB-6, 이미 구현됨)가 노출하는 attack_landed(target)
## 시그널— 헤더 주석에 "판정 성립만 알리고, 실제 플레이어 피해 적용은 CB-3/CB-4가
## 담당한다"고 명시된 연동 지점 —에 연결해, 대상이 플레이어(take_hit 보유)면
## take_hit()을 호출해 경직(0.25초)·무적(0.6초)·넉백을 트리거하고, DamageCalculator(CB-3)로
## 실제 데미지를 계산해 take_damage()를 호출한다.
##
## 데미지 공식(combat.md 8-1장): 몬스터 공격력은 "이 값을 그대로 combat.md 6장 공식의
## 공격력 입력값으로 쓰면 결과가 플레이어 최대 HP의 10%가 되도록" 역산되어 있다 — 즉
## 스킬 계수 1.0(몬스터는 스킬이 없는 기본 근접 공격만 수행)·치명타 없음(몬스터는 민첩 기반
## 치명타 스탯이 없다)으로 DamageCalculator.calculate_damage()에 그대로 넣으면 된다.
##
## M2 몬스터 3종(뿔토끼·들개 마수·균열 점액)은 전부 잡몹이라 "강공격/보스 공격"이
## 없다 — is_heavy는 항상 false(combat.md 5-1 "일반 피격")로 고정한다.
##
## 사용법 (ai-dev/level-designer, scripts/ai·scenes/monsters·scenes/world는 본 태스크
## 범위 밖이라 씬 배선은 하지 않는다 — CB-8이 히트피드백 셰이더를 넘겨준 방식과 동일):
##   몬스터 씬에 이 스크립트를 자식 노드로 추가하고 monster_path·formula_data를 지정한다.
class_name MonsterAttackResolver
extends Node

@export var monster_path: NodePath
@export var formula_data: DamageFormulaData

@onready var _monster: Node2D = get_node(monster_path)


func _ready() -> void:
	_monster.attack_landed.connect(_on_attack_landed)


func _on_attack_landed(target: Node) -> void:
	if not target.has_method("take_hit"):
		return
	if target.has_method("is_invincible") and target.is_invincible():
		return
	var knockback_direction := Vector2.ZERO
	if target is Node2D:
		knockback_direction = target.global_position - _monster.global_position
	target.take_hit(false, knockback_direction)
	_apply_damage(target)


func _apply_damage(target: Node) -> void:
	if not target.has_method("take_damage") or formula_data == null:
		return
	var monster_stats: Variant = _monster.get("stats")
	if monster_stats == null:
		return
	var target_defense := _resolve_target_defense(target)
	var damage := DamageCalculator.calculate_damage(
		monster_stats.attack_power, 1.0, target_defense, formula_data, false, false
	)
	target.take_damage(damage, "약", _monster)


## PlayerController(또는 그 스탯 컴포넌트)의 duck-typing 계약 — get_combat_defense()가
## 있으면 그것을 쓰고, 없으면 stats(Resource).defense 필드를 읽는다
## (PlayerAttackResolver._resolve_target_defense와 동일한 패턴, 방향만 반대).
func _resolve_target_defense(target: Node) -> float:
	if target.has_method("get_combat_defense"):
		return target.get_combat_defense()
	var target_stats: Variant = target.get("stats")
	if target_stats:
		var defense_value: Variant = target_stats.get("defense")
		if defense_value != null:
			return defense_value
	return 0.0
