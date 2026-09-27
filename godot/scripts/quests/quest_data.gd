# gdlint: disable=max-returns
class_name QuestData
extends Resource

@export var quest_id: String = ""
@export var title: String = ""
@export var prerequisite: String = ""
@export var npc_id: String = "yeoulmok_receptionist"
@export var objective_kinds: Array[String] = []
@export var objective_targets: Array[String] = []
@export var objective_sources: Array[String] = []
@export var objective_counts: Array[int] = []
@export var reward_exp: int = 0
@export var reward_gold: int = 0
@export var reward_item_id: String = ""
@export var reward_item_count: int = 0
@export var grants_adventurer_pass: bool = false


func definition_error() -> String:
	var count := objective_counts.size()
	if quest_id.is_empty() or count == 0:
		return "quest_definition"
	if objective_kinds.size() != count or objective_targets.size() != count:
		return "quest_definition"
	if objective_sources.size() != count:
		return "quest_definition"
	if reward_exp < 0 or reward_gold < 0 or reward_item_count < 0:
		return "quest_reward"
	if reward_item_id.is_empty() != (reward_item_count == 0):
		return "quest_reward"
	for index in count:
		if objective_kinds[index] not in ["REACH", "TALK", "KILL"]:
			return "unsupported_objective"
		if objective_counts[index] <= 0 or objective_targets[index].is_empty():
			return "quest_definition"
	return ""
