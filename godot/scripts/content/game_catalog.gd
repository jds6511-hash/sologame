# gdlint: disable=max-returns
extends "res://scripts/quests/quest_catalog.gd"
const Content = preload("res://scripts/content/game_content.gd")

func _init(content_registry: RefCounted = null) -> void:
	registry = content_registry if content_registry != null else Registry.new()
	for id in Content.NPCS:
		npc_names[id] = Content.NPCS[id][2]
	for id in Content.EDGES:
		npc_names[id] = Content.NAMES[Content.EDGES[id][1]] + " 안내인"
	for id in npc_names:
		npc_scenes[id] = "res://scenes/npc/quest_receptionist.tscn"
	for id in Content.QUESTS:
		definitions[id] = load(Content.QUESTS[id])

func ordered_ids() -> Array:
	return Content.QUESTS.keys()

func tracking_npc(states: Dictionary) -> String:
	return "novera_receptionist" if states.get("MQ-01-05", {}).get("state") == "completed" else "yeoulmok_receptionist"

func available_ids(states: Dictionary, npc: String = "") -> Array:
	var current := []
	var offers := []
	for id in ordered_ids():
		var definition: QuestData = definitions[id]
		if npc != "" and npc not in [definition.giver_id(), definition.npc_id]:
			continue
		if states.get(id, {}).get("state") == "completed":
			continue
		if (
			definition.prerequisite != ""
			and states.get(definition.prerequisite, {}).get("state") != "completed"
		):
			continue
		if not states.has(id) and npc != "" and npc != definition.giver_id():
			continue
		if states.has(id):
			current.append(id)
		else:
			offers.append(id)
	return current + offers


func travel_destination(npc: String) -> String:
	return Content.EDGES[npc][1] if Content.EDGES.has(npc) else ""


func special_view(states: Dictionary, npc: String) -> Dictionary:
	return selected_view(states, npc, "")


func selected_view(states: Dictionary, npc: String, selected_quest_id: String) -> Dictionary:
	if states.get("MQ-01-05", {}).get("state") != "completed":
		return {}
	if Content.EDGES.has(npc):
		var destination := travel_destination(npc)
		var required: String = Content.REGION_REQUIREMENTS.get(destination, "")
		if required != "" and states.get(required, {}).get("state") != "completed":
			return _notice("지역 이동 준비", definitions[required].title + " 의뢰를 먼저 보고하세요.")
		var target: String = Content.NAMES[travel_destination(npc)]
		return {
			"quest_id": "MQ-01-05",
			"action": "travel",
			"button": target + "로 이동",
			"message": target + "로 이동합니다. 저장은 별도로 해 주세요.",
			"tracker": target + " 관문 [F]"
		}
	if npc == "novera_trainer":
		return _notice("전직 안내", "Lv10부터 [V]에서 전직할 수 있습니다. 전직은 균열 입장의 필수 조건이 아닙니다.")
	var choices := available_ids(states, npc)
	if not choices.is_empty():
		var id: String = selected_quest_id if selected_quest_id in choices else choices[0]
		return load("res://scripts/quests/quest_presentation.gd")._view(
			definitions[id], states.get(id, {}), self, npc
		)
	if states.get("MQ-02-06", {}).get("state") == "completed":
		return _notice("2장 메인 완료", "후속 이야기 준비 중 · 남은 서브 의뢰는 접수원에게 선택할 수 있습니다.")
	return _notice("노베라 조합", "접수원에게 의뢰를 확인해 주세요.")


func _notice(title: String, message: String) -> Dictionary:
	return {
		"quest_id": "",
		"action": "",
		"button": "",
		"message": title + "\n" + message,
		"tracker": title + " · " + message
	}
