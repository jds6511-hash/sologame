## M6 후보 순수 모델. V4 실행/저장에서는 생성하지 않는다.
# gdlint: disable=max-returns
extends RefCounted

const Registry = preload("res://scripts/save/save_content_registry.gd")
const LIMIT := 2147483647
const JOB_FAMILY := {
	"adventurer": "sword", "warrior": "greatsword", "archer": "bow", "gladiator": "greatsword"
}
const PREFIX := {
	"body": "ARM-BODY",
	"legs": "ARM-LEG",
	"head": "ARM-HEAD",
	"feet": "ARM-FOOT",
	"ring_1": "ACC-RING",
	"ring_2": "ACC-RING",
	"necklace": "ACC-NECK"
}
var job_families: Dictionary = JOB_FAMILY.duplicate()
var registry = Registry.new()
var items: Dictionary = registry.items.duplicate()
var catalog: Dictionary


func _init() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy/m6_catalog.json"))
	for entry in catalog.definitions:
		assert(not items.has(entry.item_id), "M6 중복 ID")
		var item := ItemData.new()
		for key in entry:
			item.set(key, entry[key])
		items[item.item_id] = item


func job_gate(job: String) -> int:
	return {"adventurer": 1, "warrior": 10, "archer": 10, "gladiator": 40}.get(job, LIMIT)


func definition_errors() -> Array[String]:
	var errors: Array[String] = []
	for id in items:
		var item: ItemData = items[id]
		if (
			item.item_type == ItemData.ItemType.WEAPON
			and catalog.families.get(id, "") not in job_families.values()
		):
			errors.append("weapon_family:" + id)
	for id in catalog.prices:
		var price: Dictionary = catalog.prices[id]
		if not items.has(id) or not price.has_all(["buy", "sell", "offered", "source"]):
			errors.append("price:" + id)
			continue
		for key in ["buy", "sell"]:
			var value: Variant = price[key]
			if (
				not (value is int or value is float)
				or not is_finite(value)
				or value < 0
				or value > LIMIT
				or value != floor(value)
			):
				errors.append("price:" + id)
				return errors
		if not price.offered is bool or not price.source is String or price.source.is_empty():
			errors.append("price:" + id)
		if price.offered and (price.buy <= 0 or price.sell > price.buy):
			errors.append("price:" + id)
	for tier in [1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]:
		var table: Dictionary = catalog.supply.get(str(tier), {})
		for prefix in [
			"WPN-SW",
			"WPN-GS",
			"WPN-BW",
			"ARM-BODY",
			"ARM-LEG",
			"ARM-HEAD",
			"ARM-FOOT",
			"ACC-RING",
			"ACC-NECK"
		]:
			var id: String = table.get(prefix, "")
			if (
				not items.has(id)
				or items[id].level_limit != tier
				or items[id].grade != ItemData.ItemGrade.C
			):
				errors.append("supply:%s:%d" % [prefix, tier])
	return errors


func starter(level: int, job: String) -> Dictionary:
	if level < job_gate(job) or level > 100:
		return {}
	var tier := 1 if level < 10 else floori(level / 10.0) * 10
	var table: Dictionary = catalog.supply[str(tier)]
	var result := {}
	for slot in PREFIX:
		result[slot] = table[PREFIX[slot]]
	var prefixes := {"sword": "WPN-SW", "greatsword": "WPN-GS", "bow": "WPN-BW"}
	var weapon_prefix: String = prefixes[job_families[job]]
	result.weapon = table[weapon_prefix]
	return result


func equip_error(id: String, slot: String, level: int, job: String) -> String:
	if not job_families.has(job) or level < job_gate(job):
		return "job"
	if not items.has(id) or not registry.slots.has(slot):
		return "item"
	var item: ItemData = items[id]
	if (
		item.equip_slot != registry.slots[slot]
		or item.item_type == ItemData.ItemType.SPECIAL_WEAPON
	):
		return "slot"
	if item.level_limit > level:
		return "level"
	if slot == "weapon" and catalog.families.get(id, "") != job_families[job]:
		return "weapon_family"
	return ""


func stats(level: int, job: String, equipment: Dictionary) -> CombatantStats:
	var result: CombatantStats = registry.max_stats(level, job)
	result.attack_power -= StatGrowthCalculator.gear_weapon_attack(level, registry.FORMULA)
	result.defense -= StatGrowthCalculator.gear_armor_defense(level, registry.FORMULA)
	var hp_percent := 0.0
	for id in equipment.values():
		if id == "":
			continue
		var item: ItemData = items[id]
		match item.main_stat_type:
			ItemData.MainStatType.ATTACK_POWER:
				result.attack_power += item.main_stat_value
			ItemData.MainStatType.DEFENSE:
				result.defense += item.main_stat_value
			ItemData.MainStatType.MAX_HP:
				hp_percent += item.main_stat_value
			ItemData.MainStatType.MAX_MP:
				result.max_mp += item.main_stat_value
	result.max_hp *= 1.0 + hp_percent / 100.0
	return result


func quantity(bag: Array, id: String) -> int:
	for entry in bag:
		if entry.item_id == id:
			return int(entry.quantity)
	return 0


func add(bag: Array, id: String, count: int) -> bool:
	if count <= 0 or quantity(bag, id) > LIMIT - count:
		return false
	for entry in bag:
		if entry.item_id == id:
			entry.quantity += count
			return true
	if bag.size() >= 30:
		return false
	bag.append({"item_id": id, "quantity": count})
	return true


func remove(bag: Array, id: String, count: int) -> bool:
	for entry in bag:
		if entry.item_id == id and entry.quantity >= count and count > 0:
			entry.quantity -= count
			if entry.quantity == 0:
				bag.erase(entry)
			return true
	return false


## 복사본에서 전체 검사 후 확정. 호출자는 통지 중에도 재진입을 잠근다.
func trade(state: Dictionary, id: String, count: int, buy: bool) -> String:
	if count < 1 or count > LIMIT:
		return "quantity"
	if not items.has(id) or not catalog.prices.has(id):
		return "not_tradable"
	var price: Dictionary = catalog.prices[id]
	if buy and not price.offered:
		return "not_tradable"
	var cost := int(price.buy if buy else price.sell) * count
	if cost > LIMIT:
		return "gold_limit"
	var bag: Array = state.bag.duplicate(true)
	if buy:
		if state.gold < cost:
			return "gold"
		if not add(bag, id, count):
			return "bag_full"
	else:
		if state.gold > LIMIT - cost:
			return "gold_limit"
		if not remove(bag, id, count):
			return "quantity"
	state.bag = bag
	state.gold += -cost if buy else cost
	return ""


func equip(state: Dictionary, id: String, slot: String, level: int, job: String) -> String:
	var error := equip_error(id, slot, level, job)
	if not error.is_empty():
		return error
	var bag: Array = state.bag.duplicate(true)
	if not remove(bag, id, 1):
		return "quantity"
	var previous: String = state.equipment[slot]
	if previous != "" and not add(bag, previous, 1):
		return "bag_full"
	state.bag = bag
	state.equipment[slot] = id
	return ""


func recover(state: Dictionary, index: int) -> String:
	if index < 0 or index >= state.overflow.size():
		return "overflow_index"
	var entry: Dictionary = state.overflow[index]
	if not add(state.bag, entry.item_id, int(entry.quantity)):
		return "bag_full"
	state.overflow.remove_at(index)
	return ""
