# gdlint: disable=max-returns
extends "res://scripts/chapter_two/m7_catalog.gd"

const RegionsClosure = preload("res://scripts/chapter_two_closure/closure_regions.gd")
const CLOSURE_IDS := ["MQ-02-05", "MQ-02-06", "SQ-NOV-001", "SQ-NOV-002"]
var selected_quest_id := ""


func _init(content_registry: RefCounted = null) -> void:
	super(content_registry)
	npc_names["novera_gareth"] = "가레스"
	for id in RegionsClosure.EDGES:
		npc_names[id] = RegionsClosure.NAMES[RegionsClosure.EDGES[id][1]] + " 안내인"
	for id in npc_names:
		npc_scenes[id] = "candidate"
	for file in ["mq_02_05", "mq_02_06", "sq_nov_001", "sq_nov_002"]:
		var definition: QuestData = load("res://data/quests/m7_closure/%s.tres" % file)
		definitions[definition.quest_id] = definition


func ordered_ids() -> Array:
	return super.ordered_ids() + CLOSURE_IDS


func available_ids(states: Dictionary, npc: String = "") -> Array:
	var result := []
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
		result.append(id)
	return result


func select_quest(id: String, states: Dictionary) -> bool:
	if id not in available_ids(states):
		return false
	selected_quest_id = id
	return true


func travel_destination(npc: String) -> String:
	return RegionsClosure.EDGES[npc][1] if RegionsClosure.EDGES.has(npc) else ""


func special_view(states: Dictionary, npc: String) -> Dictionary:
	if states.get("MQ-01-05", {}).get("state") != "completed":
		return {}
	if RegionsClosure.EDGES.has(npc):
		if npc == "outskirts_rift_gate" and states.get("MQ-02-04", {}).get("state") != "completed":
			return _notice("균열 입장 준비", "다음 길을 고르다 의뢰를 먼저 보고하세요.")
		var target: String = RegionsClosure.NAMES[travel_destination(npc)]
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
