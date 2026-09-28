extends RefCounted
## 수락한 의뢰의 읽기 전용 표시 모델. 저장·진행·보상을 변경하지 않는다.

const Presentation = preload("res://scripts/quests/quest_presentation.gd")
const Npcs = preload("res://scripts/npc/npc_registry.gd")
const STATE_TEXT := {"active": "진행 중", "ready": "보고 가능", "completed": "완료"}


static func entries(
	catalog: QuestCatalog, states: Dictionary, filter: String, query: String
) -> Array:
	var result := []
	var needle := query.strip_edges().to_lower()
	for id in catalog.ORDER:
		if not states.has(id) or not catalog.definitions.has(id):
			continue
		var state: String = states[id].state
		if filter == "active" and state not in ["active", "ready"]:
			continue
		if filter in ["ready", "completed"] and state != filter:
			continue
		var definition: QuestData = catalog.definitions[id]
		var searchable := (
			definition.title
			+ " "
			+ " ".join(definition.objective_labels)
			+ " "
			+ " ".join(definition.objective_location_hints)
		)
		if not needle.is_empty() and not searchable.to_lower().contains(needle):
			continue
		result.append({"quest_id": id, "title": definition.title, "state": state})
	return result


static func detail(catalog: QuestCatalog, states: Dictionary, id: String) -> Dictionary:
	if not states.has(id) or not catalog.definitions.has(id):
		return {}
	var definition: QuestData = catalog.definitions[id]
	var state: Dictionary = states[id]
	var objectives := []
	var found_current := false
	for index in definition.objective_counts.size():
		var done: bool = state.counts[index] >= definition.objective_counts[index]
		var status := "completed" if done else ("pending" if found_current else "current")
		if not done:
			found_current = true
		objectives.append(
			{
				"label": definition.objective_labels[index],
				"location": definition.objective_location_hints[index],
				"current": state.counts[index],
				"required": definition.objective_counts[index],
				"status": status
			}
		)
	var next_action := "현재 목표를 마친 뒤 %s에게 보고하세요." % Npcs.NAMES[definition.npc_id]
	if state.state == "ready":
		next_action = "목표 완료 · %s에게 보고하고 보상을 받으세요. [F]" % Npcs.NAMES[definition.npc_id]
	elif state.state == "completed":
		next_action = "보고 및 보상 수령 완료"
	return {
		"quest_id": id,
		"title": definition.title,
		"state": state.state,
		"description": definition.offer_text,
		"objectives": objectives,
		"reward": Presentation.reward_text(definition, catalog),
		"next_action": next_action
	}
