class_name QuestCatalog
extends RefCounted

const FIRST = preload("res://data/quests/mq_01_01.tres")
const SECOND = preload("res://data/quests/mq_01_02.tres")
var definitions: Dictionary = {}


func _init() -> void:
	for definition in [FIRST, SECOND]:
		definitions[definition.quest_id] = definition
