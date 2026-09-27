# gdlint: disable=max-returns
extends RefCounted


static func validate(quests: Variant, catalog: QuestCatalog) -> String:
	if not quests is Dictionary or quests.size() > catalog.definitions.size():
		return "quest_fields"
	for id in quests:
		if not id is String or not catalog.definitions.has(id):
			return "unknown_quest"
		var definition: QuestData = catalog.definitions[id]
		var error := definition.definition_error()
		if not error.is_empty():
			return error
		var state: Variant = quests[id]
		if not state is Dictionary or state.size() != 2 or not state.has_all(["state", "counts"]):
			return "quest_fields"
		if state.state not in ["active", "ready", "completed"] or not state.counts is Array:
			return "quest_state"
		if state.counts.size() != definition.objective_counts.size():
			return "quest_counts"
		var complete := true
		for index in state.counts.size():
			var value: Variant = state.counts[index]
			if not (value is int or value is float):
				return "quest_counts"
			if not is_finite(value) or value != floor(value):
				return "quest_counts"
			if value < 0 or value > definition.objective_counts[index]:
				return "quest_counts"
			if not complete and value != 0:
				return "quest_order"
			complete = complete and value == definition.objective_counts[index]
		if (state.state == "active") == complete:
			return "quest_state"
		if not definition.prerequisite.is_empty():
			var previous: Variant = quests.get(definition.prerequisite)
			if not previous is Dictionary or previous.get("state") != "completed":
				return "quest_prerequisite"
	return ""
