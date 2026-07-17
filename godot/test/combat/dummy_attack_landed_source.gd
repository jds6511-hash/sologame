## MonsterBase(scripts/ai/monster_base.gd)의 attack_landed 시그널과 stats(공격력) 프로퍼티만
## 모사한 더미. MonsterAttackResolver가 이 시그널에 반응해 피격 반응(take_hit)뿐 아니라
## 실데미지(take_damage)까지 계산·적용하는지 몬스터 구현 없이 검증한다.
class_name DummyAttackLandedSource
extends Node2D

signal attack_landed(target: Node)

@export var stats: MonsterStatsData


func fire_attack_landed(target: Node) -> void:
	attack_landed.emit(target)
