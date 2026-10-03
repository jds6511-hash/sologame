extends GutTest
const Model = preload("res://scripts/territory/territory_model.gd")
const Travel = preload("res://scripts/territory/territory_travel.gd")


func test_return_selects_owned_holding_and_shares_cooldown() -> void:
	var territory := Model.initial({"MQ-03-05": {"state": "completed"}})
	var travel := Travel.initial({}, "novera_commons")
	assert_eq(
		Travel.quote(travel, territory, "pilgrimage_path", "jaetgol", 5500, true).error, "ownership"
	)
	Model.sync_ownership(
		territory, {"MQ-03-05": {"state": "completed"}, "MQ-08-04": {"state": "completed"}}
	)
	var offer := Travel.quote(travel, territory, "pilgrimage_path", "jaetgol", 5500, true)
	assert_eq(offer.error, "")
	assert_eq(offer.map_id, "jaetgol")
	assert_eq(Travel.commit(travel, {"gold": 0}, offer), "")
	assert_eq(travel.return_ms, 900000)
	assert_eq(Travel.quote(travel, territory, "jaetgol", "yeoulmok", 5500, true).error, "cooldown")
	Travel.advance(travel, 900000)
	assert_eq(
		Travel.quote(travel, territory, "jaetgol", "yeoulmok", 5500, true).map_id,
		"eastern_frontier_start"
	)


func test_jaetgol_departure_requires_local_desk_and_holding() -> void:
	var territory := Model.initial(
		{"MQ-03-05": {"state": "completed"}, "MQ-08-04": {"state": "completed"}}
	)
	var travel := Travel.initial({}, "novera_commons")
	assert_eq(Travel.departure_error("jaetgol", Vector2(320, 488), territory), "")
	assert_eq(Travel.departure_error("jaetgol", Vector2.ZERO, territory), "warp_departure")
	assert_eq(Travel.quote(travel, territory, "jaetgol", "novera", 5500).error, "")
	assert_false(Travel.is_city("jaetgol"))
	assert_false(Travel.is_city("oranse"))
	assert_ne(Travel.quote(travel, territory, "oranse", "novera", 5500).error, "")
	assert_eq(Travel.quote(travel, territory, "jaetgol_approach", "yeoulmok", 5500, true).error, "")
