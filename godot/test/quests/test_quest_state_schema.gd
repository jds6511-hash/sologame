extends GutTest

const Catalog = preload("res://scripts/quests/quest_catalog.gd")
const Schema = preload("res://scripts/quests/quest_state_schema.gd")
var catalog: QuestCatalog


func before_each() -> void:
	catalog = Catalog.new()


func test_data_rewards_and_shared_definitions() -> void:
	assert_eq(catalog.definitions["MQ-01-01"].reward_exp, 75)
	assert_eq(catalog.definitions["MQ-01-01"].reward_gold, 20)
	assert_true(catalog.definitions["MQ-01-01"].grants_adventurer_pass)
	var second: QuestData = catalog.definitions["MQ-01-02"]
	assert_eq(second.reward_exp, 325)
	assert_eq(second.reward_gold, 100)
	assert_eq(second.reward_item_id, "POT-HP-1")
	assert_eq(second.reward_item_count, 2)
	assert_eq(second.objective_sources, ["yeoulmok_rabbit_habitat"])


func test_all_catalog_definitions_and_rewards_are_valid() -> void:
	assert_true(catalog.has_method("definition_errors"))
	if not catalog.has_method("definition_errors"):
		return
	assert_eq(catalog.call("definition_errors"), {})
	var copy: QuestData = catalog.definitions["MQ-01-02"].duplicate(true)
	catalog.definitions[copy.quest_id] = copy
	copy.objective_counts = [0]
	assert_eq(catalog.call("definition_errors"), {"MQ-01-02": "quest_definition"})
	copy.objective_counts = [2]
	copy.reward_item_id = "missing_item"
	assert_eq(catalog.call("definition_errors"), {"MQ-01-02": "quest_reward_item"})
	assert_eq(Catalog.new().definitions[copy.quest_id].reward_item_id, "POT-HP-1")


func test_negative_rewards_and_inconsistent_item_counts_rejected() -> void:
	var original: QuestData = catalog.definitions["MQ-01-02"]
	for field in ["reward_exp", "reward_gold", "reward_item_count"]:
		var copy: QuestData = original.duplicate(true)
		copy.set(field, -1)
		assert_eq(copy.definition_error(), "quest_reward")
	var copy: QuestData = original.duplicate(true)
	copy.reward_item_count = 0
	assert_eq(copy.definition_error(), "quest_reward")
	copy.reward_item_count = 2
	copy.reward_item_id = ""
	assert_eq(copy.definition_error(), "quest_reward")


func test_catalog_reuses_save_registry_and_validates_npc_ids() -> void:
	var schema = load("res://scripts/save/save_schema.gd").new()
	assert_same(schema.quest_catalog.registry, schema.registry)
	var copy: QuestData = catalog.definitions["MQ-01-01"].duplicate(true)
	catalog.definitions[copy.quest_id] = copy
	copy.npc_id = "missing_npc"
	assert_eq(catalog.definition_errors(), {"MQ-01-01": "quest_npc"})


func test_valid_states_including_json_roundtrip() -> void:
	assert_eq(Schema.validate({}, catalog), "")
	for state in [
		{"state": "active", "counts": [0, 0]},
		{"state": "active", "counts": [1, 0]},
		{"state": "ready", "counts": [1, 1]},
		{"state": "completed", "counts": [1, 1]}
	]:
		var quests := {"MQ-01-01": state}
		assert_eq(Schema.validate(quests, catalog), "")
		assert_eq(Schema.validate(JSON.parse_string(JSON.stringify(quests)), catalog), "")


func test_invalid_counts_order_and_states() -> void:
	for counts in [[-1, 0], [0.5, 0], [2, 0], [0, 1], [true, 0], [NAN, 0], [1]]:
		assert_ne(Schema.validate({"MQ-01-01": {"state": "active", "counts": counts}}, catalog), "")
	for state in ["active", "ready", "completed", "unknown"]:
		var counts := [1, 1] if state == "active" else [0, 0]
		assert_ne(Schema.validate({"MQ-01-01": {"state": state, "counts": counts}}, catalog), "")


func test_unknown_id_prerequisite_and_shape_rejected() -> void:
	for quests in [
		[],
		{"unknown": {}},
		{"MQ-01-01": null},
		{"MQ-01-01": {"state": "active", "counts": [0, 0], "rewarded": true}},
		{"MQ-01-02": {"state": "active", "counts": [0]}}
	]:
		assert_ne(Schema.validate(quests, catalog), "")
	var quests := {
		"MQ-01-01": {"state": "ready", "counts": [1, 1]},
		"MQ-01-02": {"state": "active", "counts": [1]}
	}
	assert_eq(Schema.validate(quests, catalog), "quest_prerequisite")
	quests["MQ-01-01"].state = "completed"
	assert_eq(Schema.validate(quests, catalog), "")


func test_validator_uses_catalog_limits_without_duplicate_constants() -> void:
	var copy: QuestData = catalog.definitions["MQ-01-02"].duplicate(true)
	catalog.definitions["MQ-01-02"] = copy
	copy.objective_counts = [3]
	var quests := {
		"MQ-01-01": {"state": "completed", "counts": [1, 1]},
		"MQ-01-02": {"state": "ready", "counts": [2]}
	}
	assert_eq(Schema.validate(quests, catalog), "quest_state")
	quests["MQ-01-02"].counts = [3]
	assert_eq(Schema.validate(quests, catalog), "")
	copy.objective_kinds = ["ESCORT"]
	assert_eq(Schema.validate(quests, catalog), "unsupported_objective")
