# gdlint: disable=max-returns
class_name QuestController
extends Node

signal reward_claimed(quest_id: String)

const MAX_VALUE := 2147483647
var journal: QuestJournal
var registry: RefCounted
var _player: Node
var _reward_busy := false


func setup(player: Node, character_journal: QuestJournal) -> void:
	_player = player
	journal = character_journal
	registry = journal.catalog.registry


func is_reward_busy() -> bool:
	return _reward_busy


func report_from_journal(quest_id: String) -> String:
	if not journal.catalog.has_method("allows_field_report"):
		return "field_report_unavailable"
	if not journal.catalog.allows_field_report(quest_id):
		return "field_report_unavailable"
	var stats = _player.get_node_or_null("PlayerStats")
	if stats != null and stats.is_dead():
		return "player_dead"
	return report(quest_id, journal.catalog.definitions[quest_id].npc_id)


func report(quest_id: String, npc_id: String) -> String:
	if _reward_busy:
		return "reward_busy"
	if not journal.catalog.definition_errors().is_empty():
		return "quest_content_error"
	if journal.export_state().get(quest_id, {}).get("state") != "ready":
		return "quest_not_ready"
	var definition: QuestData = journal.catalog.definitions[quest_id]
	if npc_id != definition.npc_id:
		return "wrong_npc"
	if journal.catalog.has_method("eligibility_error"):
		var error: String = journal.catalog.eligibility_error(quest_id, journal.export_state())
		if error != "":
			return error
	var inventory: InventoryComponent = _player.get_node("Inventory")
	var progression: PlayerProgression = _player.get_node("PlayerProgression")
	if (
		inventory.gold > MAX_VALUE - definition.reward_gold
		or progression.current_exp > MAX_VALUE - definition.reward_exp
	):
		return "reward_overflow"
	var item: ItemData = registry.items.get(definition.reward_item_id)
	if item != null:
		if not inventory.can_add_to_bag(item, definition.reward_item_count):
			return "inventory_full"
		if inventory.get_bag_quantity(item.item_id) > MAX_VALUE - definition.reward_item_count:
			return "reward_overflow"
	_reward_busy = true
	if item != null and not inventory.add_to_bag(item, definition.reward_item_count):
		_reward_busy = false
		return "inventory_full"
	inventory.add_gold(definition.reward_gold)
	progression.add_exp(definition.reward_exp)
	journal.complete(quest_id)
	_reward_busy = false
	reward_claimed.emit(quest_id)
	return ""
