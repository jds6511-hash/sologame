class_name QuestCatalog
extends RefCounted

const FIRST = preload("res://data/quests/mq_01_01.tres")
const SECOND = preload("res://data/quests/mq_01_02.tres")
const THIRD = preload("res://data/quests/mq_01_03.tres")
const FOURTH = preload("res://data/quests/mq_01_04.tres")
const FIFTH = preload("res://data/quests/mq_01_05.tres")
const ORDER := ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04", "MQ-01-05"]
const Registry = preload("res://scripts/save/save_content_registry.gd")
const Npcs = preload("res://scripts/npc/npc_registry.gd")
# Shared definitions are read-only; character progress belongs to the Journal.
var npc_scenes := Npcs.SCENES.duplicate()
var npc_names := Npcs.NAMES.duplicate()
var definitions: Dictionary = {}
var registry: RefCounted


func _init(content_registry: RefCounted = null) -> void:
	registry = content_registry if content_registry != null else Registry.new()
	for definition in [FIRST, SECOND, THIRD, FOURTH, FIFTH]:
		definitions[definition.quest_id] = definition
	var errors := definition_errors()
	if not errors.is_empty():
		push_error("Invalid quest catalog: %s" % errors)


func definition_errors() -> Dictionary:
	var errors := {}
	for id in definitions:
		var definition: QuestData = definitions[id]
		var error := definition.definition_error()
		if error.is_empty() and not npc_scenes.has(definition.npc_id):
			error = "quest_npc"
		if error.is_empty() and not npc_scenes.has(definition.giver_id()):
			error = "quest_npc"
		if error.is_empty() and not definition.reward_item_id.is_empty():
			if not registry.items.has(definition.reward_item_id):
				error = "quest_reward_item"
		if not error.is_empty():
			errors[id] = error
	return errors


func ordered_ids() -> Array:
	return ORDER
