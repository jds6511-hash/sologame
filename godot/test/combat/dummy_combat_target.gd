## PlayerAttackResolver(CB-3·CB-7) 연동 테스트용 더미 피격 대상.
## get_combat_defense()/take_damage()만 구현해, CB-6이 구현할 몬스터 접점을 모사한다.
class_name DummyCombatTarget
extends Node2D

@export var defense: float = 0.0

var take_damage_call_count: int = 0
var last_damage: float = -1.0
var last_hit_grade: String = ""
var last_attacker: Node = null


func get_combat_defense() -> float:
	return defense


## scripts/ai/monster_base.gd(CB-6)의 실제 take_damage 시그니처를 그대로 모사한다.
func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	take_damage_call_count += 1
	last_damage = amount
	last_hit_grade = hit_grade
	last_attacker = attacker
