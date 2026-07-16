## MonsterBase(scripts/ai/monster_base.gd, CB-6)의 실제 인터페이스 —
## get_combat_defense() 메서드 없이 stats(Resource).defense 프로퍼티로 방어력을
## 노출하는 방식—를 그대로 모사한 더미. PlayerAttackResolver의 방어력 폴백 조회
## 경로(stats.defense)를 검증하기 위한 테스트 전용 더블이다.
class_name DummyStatsCombatTarget
extends Node2D

@export var stats: CombatantStats

var take_damage_call_count: int = 0
var last_damage: float = -1.0
var last_hit_grade: String = ""
var last_attacker: Node = null


func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	take_damage_call_count += 1
	last_damage = amount
	last_hit_grade = hit_grade
	last_attacker = attacker
