extends RefCounted
## Pure UI projection. No progress or reward mutations.

const Npcs = preload("res://scripts/npc/npc_registry.gd")


static func select(catalog: QuestCatalog, states: Dictionary, npc_id: String) -> Dictionary:
	for phase in ["current", "offer"]:
		for id in catalog.ORDER:
			var definition: QuestData = catalog.definitions.get(id)
			if definition == null or npc_id not in [definition.npc_id, definition.giver_id()]:
				continue
			var state: Dictionary = states.get(id, {})
			if phase == "current" and state.get("state") in ["active", "ready"]:
				return _view(definition, state, catalog, npc_id)
			if phase == "offer" and state.is_empty() and npc_id == definition.giver_id():
				if (
					definition.prerequisite.is_empty()
					or states.get(definition.prerequisite, {}).get("state") == "completed"
				):
					return _view(definition, {}, catalog, npc_id)
	if states.get("MQ-01-05", {}).get("state") == "completed":
		var travel := npc_id in ["yeoulmok_gatewarden", "novera_gatewarden"]
		var destination := "여울목" if npc_id == "novera_gatewarden" else "노베라 입구"
		return {
			"quest_id": "MQ-01-05",
			"action": "travel" if travel else "",
			"button": destination + "로 이동" if travel else "",
			"message":
			"1장 완료 · 공훈 100 기록\n2장 시작: 노베라 입구\n노베라 도시와 다음 의뢰는 아직 준비 중입니다. 관문에서 여울목과 입구를 오갈 수 있습니다.",
			"tracker": "1장 완료 · 공훈 100\n관문에서 " + destination + " 이동 [F]"
		}
	return {
		"quest_id": "",
		"action": "",
		"button": "",
		"message": "공훈부에 기록했습니다.\n여울목 출발 의뢰는 아직 준비 중입니다.",
		"tracker": "여울목 출발 의뢰 준비 중"
	}


static func _view(
	definition: QuestData, state: Dictionary, catalog: QuestCatalog, npc_id: String
) -> Dictionary:
	var action := ""
	var button := ""
	var message := definition.offer_text
	var objective := current_objective(definition, state)
	var tracker: String = objective.get("label", "")
	if state.is_empty():
		action = "accept"
		button = definition.title + " 수락"
		tracker = "%s에게 %s 수락 [F]" % [Npcs.NAMES[definition.giver_id()], definition.title]
	elif state.state == "ready":
		action = "report" if npc_id == definition.npc_id else ""
		button = "모험가 패 받기" if definition.grants_adventurer_pass else "보고하고 보상 받기"
		tracker = Npcs.NAMES[definition.npc_id] + "에게 보고 [F]"
		if not definition.grants_adventurer_pass:
			message = tracker + "\n보고하면 보상을 받습니다."
	elif not definition.grants_adventurer_pass:
		tracker = (
			"%s %d/%d · %s"
			% [objective.label, objective.current, objective.required, objective.location]
		)
		message = tracker + "\n목표를 마친 뒤 %s에게 보고하세요." % Npcs.NAMES[definition.npc_id]
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
	if definition.reward_reputation > 0:
		text += " · 공훈 %d" % definition.reward_reputation
	if definition.grants_adventurer_pass:
		text = "모험가 패 · " + text
	if definition.reward_item_count > 0:
		var item: ItemData = catalog.registry.items[definition.reward_item_id]
		text += " · %s %d개" % [item.item_name, definition.reward_item_count]
	return text
