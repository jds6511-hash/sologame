extends GutTest

const Catalog = preload("res://scripts/quests/quest_catalog.gd")
const Schema = preload("res://scripts/quests/quest_state_schema.gd")
const VIEW_PATH := "res://scripts/quests/quest_presentation.gd"
const NPC := "yeoulmok_receptionist"
var catalog: QuestCatalog


func before_each() -> void:
	catalog = Catalog.new()


func _view(states: Dictionary, npc: String = NPC) -> Dictionary:
	assert_true(ResourceLoader.exists(VIEW_PATH), "presentation must exist")
	if not ResourceLoader.exists(VIEW_PATH):
		return {}
	return load(VIEW_PATH).select(catalog, states, npc)


func _completed_first_two() -> Dictionary:
	return {
		"MQ-01-01": {"state": "completed", "counts": [1, 1]},
		"MQ-01-02": {"state": "completed", "counts": [2]}
	}


func test_third_definition_matches_existing_reward_budget() -> void:
	assert_true(catalog.definitions.has("MQ-01-03"))
	if not catalog.definitions.has("MQ-01-03"):
		return
	var definition: QuestData = catalog.definitions["MQ-01-03"]
	assert_eq(definition.prerequisite, "MQ-01-02")
	assert_eq(definition.objective_kinds, ["KILL"])
	assert_eq(definition.objective_targets, ["feral_dog"])
	assert_eq(definition.objective_sources, ["yeoulmok_dog_habitat"])
	assert_eq(definition.objective_counts, [2])
	assert_eq(
		[definition.reward_exp, definition.reward_gold, definition.reward_item_count], [490, 150, 0]
	)


func test_active_first_blocks_premature_second_offer_and_selection_is_pure() -> void:
	var states := {"MQ-01-01": {"state": "active", "counts": [1, 0]}}
	var before := states.duplicate(true)
	var view := _view(states)
	assert_eq(view.get("quest_id"), "MQ-01-01")
	assert_eq(view.get("action"), "")
	assert_eq(states, before)
	assert_eq(_view(states, "wrong_npc").get("quest_id", ""), "")


func test_followup_offer_then_progress_report_and_end() -> void:
	var states := _completed_first_two()
	assert_eq(_view(states).get("action"), "accept")
	assert_eq(_view(states).get("quest_id"), "MQ-01-03")
	states["MQ-01-03"] = {"state": "active", "counts": [1]}
	assert_eq(_view(states).get("action"), "")
	assert_string_contains(_view(states).get("tracker", ""), "1/2")
	states["MQ-01-03"] = {"state": "ready", "counts": [2]}
	assert_eq(_view(states).get("action"), "report")
	assert_string_contains(_view(states).get("message", ""), "490")
	states["MQ-01-03"].state = "completed"
	assert_eq(_view(states).get("action"), "")
	assert_string_contains(_view(states).get("tracker", ""), "준비 중")


func test_old_catalog_rejects_three_entries_before_unknown_id_check() -> void:
	var old := Catalog.new()
	old.definitions.erase("MQ-01-03")
	var states := _completed_first_two()
	states["MQ-01-03"] = {"state": "active", "counts": [1]}
	assert_eq(Schema.validate(states, old), "quest_fields")
