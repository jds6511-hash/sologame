extends "res://scripts/npc/quest_npc.gd"
var _manager: Node


func _init() -> void:
	npc_id = "defense_rally"


func configure(manager: Node) -> void:
	_manager = manager


func update_target() -> void:
	_available = can_interact()


func can_interact() -> bool:
	return _can_interact() and is_instance_valid(_manager) and _manager.can_resume()


func interact() -> bool:
	return can_interact() and _manager.resume()


func interaction_verb() -> String:
	return "방어 재개"
