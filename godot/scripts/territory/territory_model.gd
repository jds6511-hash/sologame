## 영지 회계와 현장 명령. 시간은 실제 시뮬레이션 밀리초만 받는다.
# gdlint: disable=max-returns
extends RefCounted
const DAY_MS := 1800000
const LIMIT := 2147483647
const TIME_LIMIT := 9007199254740991
const COSTS := {"market": 12600, "workshop": 18900, "develop": 25200}
const VILLAGE_COSTS := {"market": 141400, "workshop": 212100, "develop": 282800}


static func completed(quests: Dictionary, id: String) -> bool:
	var entry: Variant = quests.get(id, {})
	return entry is Dictionary and entry.get("state", "") == "completed"


static func initial(quests: Dictionary) -> Dictionary:
	var data := {
		"revision": 1,
		"representative": "",
		"holdings": {},
		"treasury": 0,
		"day_ms": 0,
		"frozen_rate": 0,
		"elapsed_ms": 0,
		"order": {}
	}
	sync_ownership(data, quests)
	return data


static func sync_ownership(data: Dictionary, quests: Dictionary) -> void:
	if completed(quests, "MQ-03-05") and data.representative == "":
		data.representative = "yeoulmok"
		data.holdings.yeoulmok = {"facilities": [], "development": 0, "order_prosperity": 0}
		data.frozen_rate = daily_rate(data)
		data.order = make_order(1, int(data.elapsed_ms) + DAY_MS * 7)
	if (
		completed(quests, "MQ-03-05")
		and completed(quests, "MQ-08-04")
		and data.representative == "yeoulmok"
	):
		data.holdings.jaetgol = {"facilities": [], "development": 0, "order_prosperity": 0}
		data.representative = "jaetgol"
		data.revision = 2
		# 진행 중인 부분일은 기존 고정 요율을 보존한다.
		if data.day_ms == 0:
			data.frozen_rate = daily_rate(data)


static func prosperity(data: Dictionary) -> int:
	if data.representative == "":
		return 0
	var holding: Dictionary = data.holdings[data.representative]
	return mini(
		100,
		(
			int(holding.order_prosperity)
			+ (20 if "market" in holding.facilities else 0)
			+ (15 if "workshop" in holding.facilities else 0)
		)
	)


static func preview_barony(data: Dictionary, quests: Dictionary) -> Dictionary:
	var error := validate(data, quests)
	if error != "":
		return {"ok": false, "code": error}
	if quests.get("MQ-08-04", {}).get("state") != "ready":
		return {"ok": false, "code": "quest_not_ready"}
	var next_quests := quests.duplicate(true)
	next_quests["MQ-08-04"].state = "completed"
	var next := data.duplicate(true)
	sync_ownership(next, next_quests)
	error = validate(next, next_quests)
	return {"ok": error == "", "code": error, "territory": next}


static func daily_rate(data: Dictionary) -> int:
	if data.representative == "":
		return 0
	if data.representative == "jaetgol":
		return int(floor(707.0 * (6.0 + prosperity(data) / 25.0)))
	return int(floor(63.0 * (3.0 + prosperity(data) / 50.0)))


static func make_order(
	serial: int, deadline: int, representative: String = "yeoulmok"
) -> Dictionary:
	return {
		"serial": serial,
		"item_id": "MAT-DOG-FANG",
		"quantity": 3,
		"reward": 14140 if representative == "jaetgol" else 1260,
		"deadline_ms": deadline,
		"completed": false
	}


static func advance(data: Dictionary, elapsed_ms: int) -> void:
	if elapsed_ms <= 0 or data.representative == "":
		return
	var accepted := mini(elapsed_ms, TIME_LIMIT - int(data.elapsed_ms))
	data.elapsed_ms += accepted
	var total := int(data.day_ms) + accepted
	var days := int(total / DAY_MS)
	data.day_ms = total % DAY_MS
	if days > 0:
		var cap := daily_rate(data) * 7
		data.treasury += maxi(0, mini(int(data.frozen_rate), cap - int(data.treasury)))
		data.frozen_rate = daily_rate(data)
		if days > 1:
			data.treasury += maxi(
				0, mini((days - 1) * int(data.frozen_rate), cap - int(data.treasury))
			)
	if data.elapsed_ms >= data.order.deadline_ms:
		var period := DAY_MS * 7
		if "market" in data.holdings[data.representative].facilities:
			period = int(period / 2)
		var count := 1 + int((int(data.elapsed_ms) - int(data.order.deadline_ms)) / period)
		data.order = make_order(
			int(data.order.serial) + count,
			int(data.order.deadline_ms) + count * period,
			data.representative
		)


static func act(data: Dictionary, economy: Dictionary, action: String, onsite_id: String) -> String:
	if data.representative == "" or not data.holdings.has(onsite_id):
		return "onsite"
	var holding: Dictionary = data.holdings[onsite_id]
	var costs: Dictionary = VILLAGE_COSTS if onsite_id == "jaetgol" else COSTS
	match action:
		"collect", "claim":
			if economy.gold > LIMIT - data.treasury:
				return "gold_limit"
			economy.gold += data.treasury
			data.treasury = 0
		"market", "workshop", "develop":
			if action == "develop" and holding.development >= 5:
				return "development_limit"
			if (
				action != "develop"
				and (action in holding.facilities or holding.facilities.size() >= 2)
			):
				return "facility_limit"
			if economy.gold < costs[action]:
				return "gold"
			economy.gold -= costs[action]
			if action == "develop":
				holding.development += 1
			else:
				holding.facilities.append(action)
		"deliver", "order":
			if data.order.completed or data.elapsed_ms >= data.order.deadline_ms:
				return "order_unavailable"
			if economy.gold > LIMIT - data.order.reward:
				return "gold_limit"
			var found := -1
			for i in range(economy.bag.size()):
				if (
					economy.bag[i].item_id == data.order.item_id
					and economy.bag[i].quantity >= data.order.quantity
				):
					found = i
			if found < 0:
				return "material"
			economy.bag[found].quantity -= data.order.quantity
			if economy.bag[found].quantity == 0:
				economy.bag.remove_at(found)
			economy.gold += data.order.reward
			var beneficiary: Dictionary = data.holdings[data.representative]
			beneficiary.order_prosperity = mini(25, int(beneficiary.order_prosperity) + 2)
			data.order.completed = true
		_:
			return "action"
	return ""


static func integer(value: Variant, maximum: int) -> bool:
	return (
		(typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT)
		and is_finite(float(value))
		and value >= 0
		and value <= maximum
		and value == floor(value)
	)


static func keys(data: Dictionary, expected: Array) -> bool:
	return data.size() == expected.size() and expected.all(func(key): return data.has(key))


static func validate(data: Variant, quests: Dictionary) -> String:
	if (
		not data is Dictionary
		or not keys(
			data,
			[
				"revision",
				"representative",
				"holdings",
				"treasury",
				"day_ms",
				"frozen_rate",
				"elapsed_ms",
				"order"
			]
		)
	):
		return "territory_structure"
	if not integer(data.revision, 2) or data.revision < 1:
		return "territory_revision"
	if not data.holdings is Dictionary or not data.order is Dictionary:
		return "territory_structure"
	for field in ["treasury", "day_ms", "frozen_rate", "elapsed_ms"]:
		if not integer(data[field], TIME_LIMIT if field == "elapsed_ms" else LIMIT):
			return "territory_counter"
	if data.day_ms >= DAY_MS:
		return "territory_day"
	if not completed(quests, "MQ-03-05"):
		if data.revision != 1:
			return "territory_revision"
		if data.representative != "" or not data.holdings.is_empty() or not data.order.is_empty():
			return "territory_ownership"
		for field in ["treasury", "day_ms", "frozen_rate", "elapsed_ms"]:
			if data[field] != 0:
				return "territory_ownership"
		return ""
	var baron := completed(quests, "MQ-08-04")
	var expected := ["yeoulmok", "jaetgol"] if baron else ["yeoulmok"]
	if data.revision != (2 if baron else 1):
		return "territory_revision"
	if (
		data.representative != ("jaetgol" if baron else "yeoulmok")
		or not keys(data.holdings, expected)
	):
		return "territory_ownership"
	for holding in data.holdings.values():
		var holding_error := validate_holding(holding)
		if holding_error != "":
			return holding_error
	if int(data.elapsed_ms) % DAY_MS != int(data.day_ms):
		return "territory_day"
	if data.treasury > daily_rate(data) * 7:
		return "territory_treasury"
	if data.frozen_rate < 189 or data.frozen_rate > daily_rate(data):
		return "territory_rate"
	return validate_order(data, baron)


static func validate_holding(holding: Variant) -> String:
	if (
		not holding is Dictionary
		or not keys(holding, ["facilities", "development", "order_prosperity"])
	):
		return "territory_holding"
	if not holding.facilities is Array or holding.facilities.size() > 2:
		return "territory_facilities"
	var seen := []
	for facility in holding.facilities:
		if facility not in ["market", "workshop"] or facility in seen:
			return "territory_facilities"
		seen.append(facility)
	if not integer(holding.development, 5) or not integer(holding.order_prosperity, 25):
		return "territory_prosperity"
	if holding.order_prosperity != 25 and int(holding.order_prosperity) % 2 != 0:
		return "territory_prosperity"
	return ""


static func validate_order(data: Dictionary, baron: bool) -> String:
	var order: Dictionary = data.order
	if not keys(order, ["serial", "item_id", "quantity", "reward", "deadline_ms", "completed"]):
		return "territory_order"
	if (
		not integer(order.serial, TIME_LIMIT)
		or order.serial < 1
		or not integer(order.deadline_ms, TIME_LIMIT)
	):
		return "territory_order"
	if (
		order.item_id != "MAT-DOG-FANG"
		or order.quantity != 3
		or (order.reward != 1260 and (not baron or order.reward != 14140))
		or not order.completed is bool
	):
		return "territory_order"
	if order.deadline_ms <= data.elapsed_ms or order.deadline_ms - data.elapsed_ms > DAY_MS * 7:
		return "territory_deadline"
	if order.serial > 1 + int(int(data.elapsed_ms) / (DAY_MS * 7 / 2)):
		return "territory_order"
	return ""
