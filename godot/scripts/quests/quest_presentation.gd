extends RefCounted
## Pure UI projection. No progress or reward mutations.


static func select(catalog: QuestCatalog, states: Dictionary, npc_id: String) -> Dictionary:
	for phase in ["current", "offer"]:
		for id in catalog.ORDER:
			var definition: QuestData = catalog.definitions.get(id)
			if definition == null or definition.npc_id != npc_id:
				continue
			var state: Dictionary = states.get(id, {})
			if phase == "current" and state.get("state") in ["active", "ready"]:
				return _view(definition, state, catalog)
			if phase == "offer" and state.is_empty():
				if (
					definition.prerequisite.is_empty()
					or states.get(definition.prerequisite, {}).get("state") == "completed"
				):
					return _view(definition, {}, catalog)
	return {
		"quest_id": "",
		"action": "",
		"button": "",
		"message": "공훈부에 기록했습니다.\n여울목 출발 의뢰는 아직 준비 중입니다.",
		"tracker": "여울목 출발 의뢰 준비 중"
	}


static func _view(definition: QuestData, state: Dictionary, catalog: QuestCatalog) -> Dictionary:
	var action := ""
	var button := ""
	var message := definition.offer_text
	var objective := current_objective(definition, state)
	var tracker: String = objective.get("label", "")
	if state.is_empty():
		action = "accept"
		button = definition.title + " 수락"
		tracker = "접수원에게 %s 수락 [F]" % definition.title
	elif state.state == "ready":
		action = "report"
		button = "모험가 패 받기" if definition.grants_adventurer_pass else "보고하고 보상 받기"
		tracker = "접수원에게 보고 [F]"
		if not definition.grants_adventurer_pass:
			message = "목표를 완료했습니다. 보고하면 아래 보상을 받습니다."
	elif not definition.grants_adventurer_pass:
		tracker = (
			"%s %d/%d · %s"
			% [objective.label, objective.current, objective.required, objective.location]
		)
		message = tracker + "\n목표를 마친 뒤 접수원에게 돌아와 주세요."
	if action != "":
		message += "\n" + reward_text(definition, catalog)
	return {
		"quest_id": definition.quest_id,
		"action": action,
		"button": button,
		"message": definition.title + "\n" + message,
		"tracker": definition.title + "\n" + tracker
	}


static func current_objective(definition: QuestData, state: Dictionary) -> Dictionary:
	var counts: Array = state.get("counts", [])
	for index in definition.objective_counts.size():
		var value: int = counts[index] if index < counts.size() else 0
		if value < definition.objective_counts[index]:
			return {
				"kind": definition.objective_kinds[index],
				"label": definition.objective_labels[index],
				"location": definition.objective_location_hints[index],
				"current": value,
				"required": definition.objective_counts[index]
			}
	return {}


static func reward_text(definition: QuestData, catalog: QuestCatalog) -> String:
	var text := "경험치 %d · %d골드" % [definition.reward_exp, definition.reward_gold]
	if definition.grants_adventurer_pass:
		text = "모험가 패 · " + text
	if definition.reward_item_count > 0:
		var item: ItemData = catalog.registry.items[definition.reward_item_id]
		text += " · %s %d개" % [item.item_name, definition.reward_item_count]
	return text
