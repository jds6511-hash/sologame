extends GutTest
const Model = preload("res://scripts/territory/territory_model.gd")


func quests(baron: bool = false) -> Dictionary:
	var result := {"MQ-03-05": {"state": "completed"}}
	if baron:
		result["MQ-08-04"] = {"state": "completed"}
	return result


func test_succession_preserves_property_order_and_partial_day() -> void:
	var state := Model.initial(quests())
	var economy := {"gold": 100000, "bag": []}
	Model.act(state, economy, "market", "yeoulmok")
	Model.act(state, economy, "develop", "yeoulmok")
	Model.advance(state, Model.DAY_MS + 100)
	var before := state.duplicate(true)
	Model.sync_ownership(state, quests(true))
	assert_eq(state.representative, "jaetgol")
	assert_eq(state.revision, 2)
	assert_eq(state.holdings.yeoulmok, before.holdings.yeoulmok)
	for field in ["treasury", "elapsed_ms", "day_ms", "frozen_rate", "order"]:
		assert_eq(state[field], before[field], field)
	assert_eq(Model.validate(state, quests(true)), "")
	var promoted := state.duplicate(true)
	Model.sync_ownership(state, quests(true))
	assert_eq(state, promoted)
	Model.advance(state, Model.DAY_MS - 100)
	assert_eq(state.treasury, before.treasury + before.frozen_rate)
	assert_eq(state.frozen_rate, 4242)


func test_exact_day_and_new_order_use_village_rates() -> void:
	var state := Model.initial(quests(true))
	assert_eq(state.frozen_rate, 4242)
	Model.advance(state, Model.DAY_MS * 7)
	assert_eq(state.treasury, 4242 * 7)
	assert_eq(state.order.reward, 14140)
	assert_eq(state.order.serial, 2)
	assert_eq(Model.validate(state, quests(true)), "")


func test_old_order_delivered_anywhere_benefits_current_representative() -> void:
	var state := Model.initial(quests())
	var order: Dictionary = state.order.duplicate(true)
	Model.sync_ownership(state, quests(true))
	assert_eq(state.order, order)
	var economy := {"gold": 0, "bag": [{"item_id": "MAT-DOG-FANG", "quantity": 3}]}
	assert_eq(Model.act(state, economy, "order", "yeoulmok"), "")
	assert_eq(economy.gold, 1260)
	assert_eq(state.holdings.get("jaetgol", {}).get("order_prosperity"), 2)
	assert_eq(state.holdings.yeoulmok.order_prosperity, 0)
	assert_ne(Model.act(state, economy, "order", "jaetgol"), "")


func test_facility_prices_and_ungranted_state_rejected() -> void:
	var state := Model.initial(quests(true))
	var economy := {"gold": 141399, "bag": []}
	assert_eq(Model.act(state, economy, "market", "jaetgol"), "gold")
	economy.gold = 141400
	assert_eq(Model.act(state, economy, "market", "jaetgol"), "")
	assert_eq(economy.gold, 0)
	assert_eq(Model.daily_rate(state), 4807)
	assert_ne(Model.validate(state, quests()), "")
	assert_eq(Model.validate(state, quests(true)), "")
