## V5 후보 검증/변환. 기본 V4 codec/store는 참조하지 않으며 배포하지 않는다.
# gdlint: disable=max-returns
extends RefCounted

const Schema = preload("res://scripts/save/save_schema.gd")
const Migrations = preload("res://scripts/save/character_save_migrations.gd")
const Model = preload("res://scripts/economy/economy_candidate.gd")
var model = Model.new()
var legacy = Schema.new()
var expanded = Schema.new()


func _init() -> void:
	expanded.registry.items = model.items


func validate(data: Dictionary, account: Dictionary) -> String:
	if not model.definition_errors().is_empty():
		return "economy_content_error"
	if data.get("character_save_version") != 5:
		return legacy.character_error(data, account)
	if not expanded.fields(data.get("inventory"), ["gold", "bag", "equipment", "overflow"]):
		return "inventory_fields"
	var copy := data.duplicate(true)
	copy.character_save_version = 4
	copy.inventory.erase("overflow")
	# 기존 전체 구조/직업/지출/퀘스트 검증을 먼저 수행한다. HP/MP의 후보 최대치는 아래에서 검사한다.
	if not copy.get("player") is Dictionary:
		return "player_fields"
	var hp: Variant = copy.player.get("hp")
	var mp: Variant = copy.player.get("mp")
	if (
		not expanded.number(hp, 0.000001, expanded.MAX_INT)
		or not expanded.number(mp, 0, expanded.MAX_INT)
	):
		return "vitals"
	copy.player.hp = 1.0
	copy.player.mp = 0.0
	var error: String = expanded.character_error(copy, account)
	if not error.is_empty():
		return error
	for slot in data.inventory.equipment:
		var id: String = data.inventory.equipment[slot]
		if id != "":
			error = model.equip_error(id, slot, int(data.player.level), data.player.job_id)
			if not error.is_empty():
				return "equipment_" + error
	var overflow: Variant = data.inventory.overflow
	if not overflow is Array or overflow.size() > 8:
		return "overflow"
	var total := 0
	for entry in overflow:
		if not expanded.fields(entry, ["item_id", "quantity"]):
			return "overflow"
		if not model.items.has(entry.item_id) or not expanded.integer(entry.quantity, 1, 8):
			return "overflow"
		total += int(entry.quantity)
	if total > 8:
		return "overflow"
	var maximum: CombatantStats = model.stats(
		int(data.player.level), data.player.job_id, data.inventory.equipment
	)
	if hp > maximum.max_hp or mp > maximum.max_mp:
		return "vitals"
	return ""


func upgrade(data: Dictionary, account: Dictionary) -> Dictionary:
	var error := validate(data, account)
	if not error.is_empty():
		return {"ok": false, "code": error, "data": {}}
	if data.character_save_version == 5:
		return {"ok": true, "code": "ok", "data": data.duplicate(true)}
	var result: Dictionary = Migrations.upgrade(data)
	if not result.ok:
		return result
	var target: Dictionary = result.data
	target.character_save_version = 5
	target.inventory.overflow = []
	var defaults: Dictionary = model.starter(int(target.player.level), target.player.job_id)
	for slot in target.inventory.equipment:
		var id: String = target.inventory.equipment[slot]
		if (
			id != ""
			and model.equip_error(id, slot, int(target.player.level), target.player.job_id) != ""
		):
			if not model.add(target.inventory.bag, id, 1):
				target.inventory.overflow.append({"item_id": id, "quantity": 1})
			target.inventory.equipment[slot] = ""
		if target.inventory.equipment[slot] == "":
			target.inventory.equipment[slot] = defaults[slot]
	var maximum: CombatantStats = model.stats(
		int(target.player.level), target.player.job_id, target.inventory.equipment
	)
	target.player.hp = minf(target.player.hp, maximum.max_hp)
	target.player.mp = minf(target.player.mp, maximum.max_mp)
	error = validate(target, account)
	return result if error == "" else {"ok": false, "code": error, "data": {}}
