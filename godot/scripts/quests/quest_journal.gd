class_name QuestJournal
extends RefCounted

signal changed

const Schema = preload("res://scripts/quests/quest_state_schema.gd")
var catalog: QuestCatalog
var _states: Dictionary = {}
var _kill_tokens: Dictionary = {}


func _init(definitions: QuestCatalog) -> void:
	catalog = definitions


func accept(quest_id: String) -> String:
	if not catalog.definition_errors().is_empty():
		return "quest_content_error"
	if not catalog.definitions.has(quest_id):
		return "unknown_quest"
	if _states.has(quest_id):
		return "quest_already_accepted"
	var definition: QuestData = catalog.definitions[quest_id]
	if not definition.prerequisite.is_empty():
		if _states.get(definition.prerequisite, {}).get("state") != "completed":
			return "quest_prerequisite"
	var counts := []
	counts.resize(definition.objective_counts.size())
	counts.fill(0)
	_states[quest_id] = {"state": "active", "counts": counts}
	changed.emit()
	return ""


func record_event(kind: String, target_id: String, source_id: String, token: int) -> void:
	if kind == "KILL":
		if token <= 0 or _kill_tokens.has(token):
			return
		_kill_tokens[token] = true
	for id in _states:
		var state: Dictionary = _states[id]
		if state.state != "active":
			continue
		var definition: QuestData = catalog.definitions[id]
		for index in state.counts.size():
			if state.counts[index] >= definition.objective_counts[index]:
				continue
			if (
				kind == definition.objective_kinds[index]
				and target_id == definition.objective_targets[index]
				and source_id == definition.objective_sources[index]
			):
				state.counts[index] += 1
				if state.counts == definition.objective_counts:
					state.state = "ready"
				changed.emit()
			break


func complete(quest_id: String) -> void:
	if _states.get(quest_id, {}).get("state") == "ready":
		_states[quest_id].state = "completed"
		changed.emit()


func export_state() -> Dictionary:
	return _states.duplicate(true)


func restore_state(data: Dictionary) -> String:
	if not catalog.definition_errors().is_empty():
		return "quest_content_error"
	var error := Schema.validate(data, catalog)
	if not error.is_empty():
		return error
	_states = data.duplicate(true)
	for state in _states.values():
		for index in state.counts.size():
			state.counts[index] = int(state.counts[index])
	_kill_tokens.clear()
	changed.emit()
	return ""
