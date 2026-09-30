extends GutTest

const Model = preload("res://scripts/economy/economy_candidate.gd")


func test_supply_all_valid_jobs_and_levels() -> void:
	var model = Model.new()
	assert_eq(model.definition_errors(), [])
	for job in ["adventurer", "warrior", "archer", "gladiator"]:
		for level in range(1, 101):
			if level < model.job_gate(job):
				continue
			var equipment: Dictionary = model.starter(level, job)
			assert_eq(equipment.size(), 8)
			for slot in equipment:
				assert_eq(model.equip_error(equipment[slot], slot, level, job), "")
			assert_true(model.stats(level, job, equipment).attack_power > 0)


func test_trade_atomicity_and_sell_prices() -> void:
	var model = Model.new()
	var state := {
		"gold": 300, "bag": [], "equipment": model.starter(1, "adventurer"), "overflow": []
	}
	assert_eq(model.trade(state, "POT-HP-1", 1, true), "")
	assert_eq(state.gold, 0)
	var before := state.duplicate(true)
	assert_eq(model.trade(state, "POT-HP-1", 1, true), "gold")
	assert_eq(state, before)
	assert_eq(model.trade(state, "POT-HP-1", 1, false), "")
	assert_eq(state.gold, 30)
	state.bag.append({"item_id": "MAT-RABBIT-FOOT", "quantity": 2})
	assert_eq(model.trade(state, "MAT-RABBIT-FOOT", 2, false), "")
	assert_eq(state.gold, 38)
	assert_eq(model.trade(state, "POT-HP-1", -1, true), "quantity")
	assert_eq(model.trade(state, "unknown", 1, true), "not_tradable")


func test_full_bag_equipment_swap_rolls_back() -> void:
	var model = Model.new()
	var state := {
		"gold": 0,
		"bag": [{"item_id": "WPN-SW-10-C", "quantity": 2}],
		"equipment": model.starter(1, "adventurer"),
		"overflow": []
	}
	for id in model.items:
		if id not in ["WPN-SW-01-C", "WPN-SW-10-C"] and state.bag.size() < 30:
			state.bag.append({"item_id": id, "quantity": 1})
	var before := state.duplicate(true)
	assert_eq(model.equip(state, "WPN-SW-10-C", "weapon", 10, "adventurer"), "bag_full")
	assert_eq(state, before)
	state.bag[0].quantity = 1
	assert_eq(model.equip(state, "WPN-SW-10-C", "weapon", 10, "adventurer"), "")
	assert_eq(state.equipment.weapon, "WPN-SW-10-C")
	assert_eq(model.quantity(state.bag, "WPN-SW-01-C"), 1)


func test_full_bag_swap_and_recovery_are_lossless() -> void:
	var model = Model.new()
	var state := {"gold": 0, "bag": [], "equipment": model.starter(10, "warrior"), "overflow": []}
	for id in model.items:
		if state.bag.size() == 30:
			break
		state.bag.append({"item_id": id, "quantity": 2})
	state.overflow.append({"item_id": "POT-HP-1", "quantity": 1})
	var before := state.duplicate(true)
	if not model.quantity(state.bag, "POT-HP-1"):
		assert_eq(model.recover(state, 0), "bag_full")
		assert_eq(state, before)
	assert_eq(
		model.equip_error(model.starter(10, "archer").weapon, "weapon", 10, "warrior"),
		"weapon_family"
	)


func test_trade_limits_preserve_everything() -> void:
	var model = Model.new()
	var state := {
		"gold": model.LIMIT,
		"bag": [{"item_id": "POT-HP-1", "quantity": 1}],
		"equipment": model.starter(1, "adventurer"),
		"overflow": []
	}
	var before := state.duplicate(true)
	assert_eq(model.trade(state, "POT-HP-1", 1, false), "gold_limit")
	assert_eq(model.trade(state, "POT-HP-1", model.LIMIT, true), "gold_limit")
	assert_eq(state, before)
	state.bag.clear()
	for id in model.items:
		if id != "WPN-SW-01-C" and state.bag.size() < 30:
			state.bag.append({"item_id": id, "quantity": 2})
	before = state.duplicate(true)
	assert_eq(model.trade(state, "WPN-SW-01-C", 1, true), "bag_full")
	assert_eq(state, before)
	assert_eq(model.equip(state, "WPN-SW-01-C", "weapon", 1, "adventurer"), "quantity")
	assert_eq(state, before)
