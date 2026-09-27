class_name QuestCatalog
extends RefCounted

const FIRST = preload("res://data/quests/mq_01_01.tres")
const SECOND = preload("res://data/quests/mq_01_02.tres")
const Manifest = preload("res://scripts/save/save_content_manifest.gd")
# Shared definitions are read-only; character progress belongs to the Journal.
var definitions: Dictionary = {}
var _items: Dictionary = {}


func _init() -> void:
	for item in Manifest.ITEMS:
		_items[item.item_id] = item
	for definition in [FIRST, SECOND]:
		definitions[definition.quest_id] = definition
	var errors := definition_errors()
	if not errors.is_empty():
		push_error("Invalid quest catalog: %s" % errors)


func definition_errors() -> Dictionary:
	var errors := {}
	for id in definitions:
		var definition: QuestData = definitions[id]
		var error := definition.definition_error()
		if error.is_empty() and not definition.reward_item_id.is_empty():
			if not _items.has(definition.reward_item_id):
				error = "quest_reward_item"
		if not error.is_empty():
			errors[id] = error
	return errors
