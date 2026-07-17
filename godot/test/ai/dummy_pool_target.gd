## RiftSlimeAcidPool(scripts/ai/rift_slime_acid_pool.gd) 테스트 전용 더미 피격 대상.
## PlayerController/MonsterBase와 동일한 duck-typing 계약(take_damage/is_invincible/
## get_combat_defense)만 최소 구현한다 — Area2D.get_overlapping_bodies()가 실제로
## 감지하려면 PhysicsBody2D 계열이어야 하므로 Node2D가 아닌 CharacterBody2D를 쓴다.
class_name DummyPoolTarget
extends CharacterBody2D

var damage_taken: float = 0.0
var invincible: bool = false
var defense: float = 0.0


func take_damage(amount: float, _hit_grade: String = "약", _attacker: Node2D = null) -> void:
	damage_taken += amount


func is_invincible() -> bool:
	return invincible


func get_combat_defense() -> float:
	return defense
