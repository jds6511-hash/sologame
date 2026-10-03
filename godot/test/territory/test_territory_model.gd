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
	assert_eq(Travel.quote(travel, territory, "yeoulmok_defense", "", 0, true).error, "")
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


func test_chapter_five_visits_and_field_return_use_registered_cities() -> void:
	var travel = Travel.initial(owned(), "novera_commons")
	assert_false("saleno" in travel.unlocked)
	Travel.visit(travel, "saleno_coast")
	assert_false("saleno" in travel.unlocked)
	Travel.visit(travel, "saleno")
	Travel.visit(travel, "arsel")
	Travel.visit(travel, "arsel")
	assert_eq(travel.unlocked.count("arsel"), 1)
	assert_eq(Travel.validate(travel), "")
	var territory = Model.initial(owned())
	for region in ["saleno_coast", "reed_marsh", "arsel_library"]:
		assert_eq(Travel.quote(travel, territory, region, "", 1950, true).error, "")
	assert_eq(Travel.quote(travel, territory, "saleno", "arsel", 1950).cost, 7403)
	assert_eq(Travel.quote(travel, territory, "novera_commons", "saleno", 1950).cost, 14310)


func test_chapter_six_uses_misran_city_and_keeps_sylvien_non_destination() -> void:
	var travel = Travel.initial(owned(), "arsel")
	Travel.visit(travel, "sylvien")
	assert_false("sylvien" in travel.unlocked)
	assert_false("misran" in travel.unlocked)
	Travel.visit(travel, "misran")
	assert_eq(Travel.validate(travel), "")
	var territory = Model.initial(owned())
	for region in ["forest_edge", "mosswood", "sylvien"]:
		assert_eq(Travel.quote(travel, territory, region, "", 3100, true).error, "")
	assert_eq(Travel.quote(travel, territory, "arsel", "misran", 3100).cost, 8933)
	assert_eq(Travel.quote(travel, territory, "misran", "sylvien", 3100).error, "locked")


func test_paid_warp_rejects_fields_and_has_middle_price_band() -> void:
	var travel = Travel.initial(owned(), "brantel")
	var territory = Model.initial(owned())
	for region in ["novera_rift", "yeoulmok_defense", "novera_outskirts", "han_gilmok", "saleno_coast", "reed_marsh", "forest_edge", "mosswood", "sylvien"]:
		assert_eq(Travel.quote(travel, territory, region, "brantel", 500).error, "warp_departure")
		assert_eq(Travel.quote(travel, territory, region, "", 500, true).error, "")
	assert_eq(Travel.quote(travel, territory, "novera_commons", "brantel", 500).cost, 7416)


func test_paid_departure_requires_gate_radius_and_owned_territory() -> void:
	var territory = Model.initial(owned())
	var content = load("res://scripts/content/game_content.gd")
	for city in Travel.CITIES:
		var region: String = Travel.CITIES[city].map_id
		var point: Vector2 = content.WARP_ARRIVALS[region]
		assert_eq(Travel.departure_error(region, point + Vector2(40, 0), territory), "")
		assert_eq(Travel.departure_error(region, point + Vector2(40.1, 0), territory), "warp_departure")
	assert_eq(Travel.departure_error("eastern_frontier_start", Travel.TERRITORY_GATE, territory), "")
	assert_eq(Travel.departure_error("eastern_frontier_start", Travel.TERRITORY_GATE, Model.initial({})), "ownership")
	assert_eq(Travel.departure_error("eastern_frontier_start", Vector2(152, 504), territory), "warp_departure")
