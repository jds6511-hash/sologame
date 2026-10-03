extends GutTest
const Model = preload("res://scripts/territory/territory_model.gd")
const Travel = preload("res://scripts/territory/territory_travel.gd")


func owned() -> Dictionary:
	return {"MQ-03-05": {"state": "completed"}, "MQ-01-05": {"state": "completed"}}


func test_daily_frozen_rate_and_cap() -> void:
	var state = Model.initial(owned())
	Model.advance(state, Model.DAY_MS - 1)
	assert_eq(state.treasury, 0)
	var economy = {"gold": 50000, "bag": []}
	assert_eq(Model.act(state, economy, "market", "yeoulmok"), "")
	Model.advance(state, 1)
	assert_eq(state.treasury, 189)
	assert_eq(state.frozen_rate, 214)
	Model.advance(state, Model.DAY_MS * 100)
	assert_eq(state.treasury, 214 * 7)


func test_atomic_order_and_duplicate() -> void:
	var state = Model.initial(owned())
	var economy = {"gold": 0, "bag": [{"item_id": "MAT-DOG-FANG", "quantity": 3}]}
	assert_eq(Model.act(state, economy, "order", "remote"), "onsite")
	assert_eq(economy.gold, 0)
	assert_eq(Model.act(state, economy, "order", "yeoulmok"), "")
	assert_eq(economy.gold, 1260)
	assert_eq(economy.bag, [])
	var before = state.duplicate(true)
	assert_ne(Model.act(state, economy, "order", "yeoulmok"), "")
	assert_eq(state, before)


func test_market_does_not_move_existing_deadline() -> void:
	var state = Model.initial(owned())
	var economy = {"gold": 12600, "bag": []}
	assert_eq(Model.act(state, economy, "market", "yeoulmok"), "")
	assert_eq(state.order.deadline_ms, Model.DAY_MS * 7)
	Model.advance(state, Model.DAY_MS * 7)
	assert_eq(state.order.serial, 2)
	assert_eq(state.order.deadline_ms, Model.DAY_MS * 10 + Model.DAY_MS / 2)


func test_validation_and_restore_conservation() -> void:
	assert_eq(Model.validate(JSON.parse_string(JSON.stringify(Model.initial({}))), {}), "")
	var state = Model.initial(owned())
	Model.advance(state, Model.DAY_MS)
	assert_eq(Model.validate(state, owned()), "")
	var restored = JSON.parse_string(JSON.stringify(state))
	assert_eq(Model.validate(restored, owned()), "")
	var economy = {"gold": 10, "bag": []}
	assert_eq(Model.act(restored, economy, "claim", "yeoulmok"), "")
	assert_eq(int(restored.treasury + economy.gold), int(state.treasury + 10))
	state.holdings.yeoulmok.facilities = ["market", "market"]
	assert_ne(Model.validate(state, owned()), "")


func test_travel_unlock_discount_and_commit() -> void:
	var travel = Travel.initial(owned(), "eastern_frontier_start")
	var territory = Model.initial(owned())
	assert_eq(travel.unlocked, ["novera"])
	assert_eq(
		Travel.quote(travel, territory, "eastern_frontier_start", "gransia", 500).error, "locked"
	)
	Travel.visit(travel, "gransia")
	var full = Travel.quote(travel, territory, "eastern_frontier_start", "gransia", 0)
	var cheap = Travel.quote(travel, territory, "eastern_frontier_start", "gransia", 7500)
	assert_gt(full.cost, 0)
	assert_eq(cheap.cost, 0)
	var economy = {"gold": 0}
	assert_eq(Travel.commit(travel, economy, full), "gold")
	assert_eq(economy.gold, 0)


func test_money_overflow_and_insufficient_gold_are_atomic() -> void:
	var state = Model.initial(owned())
	Model.advance(state, Model.DAY_MS)
	var economy = {"gold": Model.LIMIT, "bag": [{"item_id": "MAT-DOG-FANG", "quantity": 3}]}
	var before = state.duplicate(true)
	var wallet = economy.duplicate(true)
	assert_eq(Model.act(state, economy, "collect", "yeoulmok"), "gold_limit")
	assert_eq(Model.act(state, economy, "deliver", "yeoulmok"), "gold_limit")
	assert_eq(state, before)
	assert_eq(economy, wallet)
	economy.gold = 0
	assert_eq(Model.act(state, economy, "workshop", "yeoulmok"), "gold")
	assert_eq(state, before)


func test_invalid_schema_numbers_and_unearned_ownership() -> void:
	for bad in [-1, 0.5, INF, NAN, "1", true]:
		var state = Model.initial(owned())
		state.day_ms = bad
		assert_ne(Model.validate(state, owned()), "", str(bad))
	var state = Model.initial(owned())
	assert_ne(Model.validate(state, {}), "")
	state.revision = 2
	assert_ne(Model.validate(state, owned()), "")
	var travel = Travel.initial(owned(), "novera_gate")
	travel.unlocked.append("novera")
	assert_ne(Travel.validate(travel), "")


func test_order_expiry_and_prosperity_cap() -> void:
	var state = Model.initial(owned())
	var economy = {"gold": 0, "bag": [{"item_id": "MAT-DOG-FANG", "quantity": 100}]}
	for i in range(14):
		assert_eq(Model.act(state, economy, "deliver", "yeoulmok"), "")
		Model.advance(state, Model.DAY_MS * 7)
	assert_eq(state.holdings.yeoulmok.order_prosperity, 25)
	assert_eq(economy.gold, 1260 * 14)
	assert_eq(economy.bag[0].quantity, 58)
	assert_false(state.order.completed)
	assert_eq(Model.validate(state, owned()), "")


func test_return_cooldown_and_discount_thresholds() -> void:
	var travel = Travel.initial(owned(), "gransia")
	var territory = Model.initial(owned())
	assert_eq(Travel.quote(travel, territory, "novera_commons", "gransia", 500).cost, 3443)
	for pair in [
		[0, 1575], [499, 1575], [500, 1418], [5499, 1418], [5500, 1103], [7499, 1103], [7500, 0]
	]:
		var offer = Travel.quote(travel, territory, "gransia", "novera", pair[0])
		assert_eq(offer.cost, pair[1])
	var offer = Travel.quote(travel, territory, "novera_rift", "", 0, true)
	assert_eq(offer.error, "")
	var economy = {"gold": 0}
	assert_eq(Travel.commit(travel, economy, offer), "")
	assert_eq(travel.return_ms, 900000)
	assert_eq(Travel.quote(travel, territory, "novera_rift", "", 0, true).error, "cooldown")
	Travel.advance(travel, 899999)
	assert_eq(travel.return_ms, 1)
	Travel.advance(travel, 1)
	assert_eq(travel.return_ms, 0)
