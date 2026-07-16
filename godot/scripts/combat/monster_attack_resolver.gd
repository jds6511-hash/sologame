## 몬스터 공격 판정 → 플레이어 피격 반응 연결부 (CB-4).
##
## scripts/ai/monster_base.gd(CB-6, 이미 구현됨)가 노출하는 attack_landed(target)
## 시그널— 헤더 주석에 "판정 성립만 알리고, 실제 플레이어 피해 적용은 CB-3/CB-4가
## 담당한다"고 명시된 연동 지점 —에 연결해, 대상이 플레이어(take_hit 보유)면
## take_hit()을 호출해 경직(0.25초)·무적(0.6초)·넉백을 트리거한다.
##
## 데미지(HP 차감)는 플레이어 체력 시스템이 아직 없어 이 범위 밖이다 — 후속 태스크에서
## 플레이어 스탯/체력 컴포넌트가 생기면 이 스크립트에서 함께 호출하면 된다.
##
## M2 몬스터 3종(뿔토끼·들개 마수·균열 점액)은 전부 잡몹이라 "강공격/보스 공격"이
## 없다 — is_heavy는 항상 false(combat.md 5-1 "일반 피격")로 고정한다.
##
## 사용법 (ai-dev/level-designer, scripts/ai·scenes/monsters·scenes/world는 본 태스크
## 범위 밖이라 씬 배선은 하지 않는다 — CB-8이 히트피드백 셰이더를 넘겨준 방식과 동일):
##   몬스터 씬에 이 스크립트를 자식 노드로 추가하고 monster_path를 지정한다.
class_name MonsterAttackResolver
extends Node

@export var monster_path: NodePath

@onready var _monster: Node2D = get_node(monster_path)


func _ready() -> void:
	_monster.attack_landed.connect(_on_attack_landed)


func _on_attack_landed(target: Node) -> void:
	if not target.has_method("take_hit"):
		return
	var knockback_direction := Vector2.ZERO
	if target is Node2D:
		knockback_direction = target.global_position - _monster.global_position
	target.take_hit(false, knockback_direction)
