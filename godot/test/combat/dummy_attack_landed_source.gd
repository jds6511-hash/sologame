## MonsterBase(scripts/ai/monster_base.gd)의 attack_landed 시그널만 모사한 더미.
## MonsterAttackResolver가 이 시그널에 정상적으로 반응하는지 몬스터 구현 없이 검증한다.
class_name DummyAttackLandedSource
extends Node2D

signal attack_landed(target: Node)


func fire_attack_landed(target: Node) -> void:
	attack_landed.emit(target)
