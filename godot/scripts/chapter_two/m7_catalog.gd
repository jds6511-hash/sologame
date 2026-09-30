extends "res://scripts/quests/quest_catalog.gd"

const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")
const NEW_IDS := ["MQ-02-01", "MQ-02-02", "MQ-02-03", "MQ-02-04"]


func _init(content_registry: RefCounted = null) -> void:
	super(content_registry)
	npc_names["novera_receptionist"] = "노베라 조합 접수원"
	npc_names["novera_trainer"] = "전직 안내인"
	for id in RegionsM7.EDGES:
		npc_names[id] = RegionsM7.NAMES[RegionsM7.EDGES[id][1]] + " 안내인"
	for id in npc_names:
		npc_scenes[id] = "candidate"
	for index in 4:
		var definition: QuestData = load("res://data/quests/m7/mq_02_%02d.tres" % (index + 1))
		definitions[definition.quest_id] = definition


func ordered_ids() -> Array:
	return ORDER + NEW_IDS


func travel_destination(npc: String) -> String:
	return RegionsM7.EDGES[npc][1] if RegionsM7.EDGES.has(npc) else ""


func tracking_npc(states: Dictionary) -> String:
	return (
		"novera_receptionist"
		if states.get("MQ-01-05", {}).get("state") == "completed"
		else "yeoulmok_receptionist"
	)


func special_view(states: Dictionary, npc: String) -> Dictionary:
	if states.get("MQ-01-05", {}).get("state") != "completed":
		return {}
	if RegionsM7.EDGES.has(npc):
		var target: String = RegionsM7.NAMES[travel_destination(npc)]
		return {
			"quest_id": "MQ-01-05",
			"action": "travel",
			"button": target + "로 이동",
			"message": target + "로 이동합니다. 저장은 별도로 해 주세요.",
			"tracker": target + " 관문 [F]"
		}
	if npc == "novera_trainer":
		return {
			"quest_id": "",
			"action": "",
			"button": "",
			"message": "Lv10부터 [V] 전직 화면에서 전사 또는 궁수를 선택할 수 있습니다. 먼저 접수원에게 의뢰를 보고하세요.",
			"tracker": "접수원에게 보고 · Lv10 전직 [V]"
		}
	if states.get("MQ-02-04", {}).get("state") == "completed":
		return {
			"quest_id": "",
			"action": "",
			"button": "",
			"message": "이번 구간 완료 · 전직 [V]과 정비가 가능합니다. 2장 후반 의뢰는 아직 제공하지 않습니다.",
			"tracker": "노베라 첫 구간 완료 · 전직 [V] / 정비"
		}
	return {}
