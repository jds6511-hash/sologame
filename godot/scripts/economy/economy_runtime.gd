## 후보 플레이어의 단일 변경 진입점. 상태 확정과 통지까지 재진입을 차단한다.
extends Node

signal changed

const Model = preload("res://scripts/economy/economy_candidate.gd")
var model = Model.new()
var player: Node2D
var busy := false
var overflow: Array = []


func state() -> Dictionary:
	var inventory = player.get_node("Inventory")
	var bag := []
	var equipment := {}
	for entry in inventory.bag:
		bag.append({"item_id": entry.item.item_id, "quantity": entry.quantity})
	for slot in model.registry.slots:
		var item = inventory.get_equipped(model.registry.slots[slot], 1 if slot == "ring_2" else 0)
		equipment[slot] = "" if item == null else item.item_id
	return {
		"gold": inventory.gold,
		"bag": bag,
		"equipment": equipment,
		"overflow": overflow.duplicate(true)
	}


func job_id() -> String:
	return String(player.get_node("PlayerJobTransition").current_job_id)


func level() -> int:
	return player.get_node("PlayerProgression").current_level


func install(actor: Node2D, fresh: bool) -> void:
	player = actor
	player.set_meta("economy_candidate", self)
	if fresh:
		var initial := state()
		initial.equipment = model.starter(level(), job_id())
		apply_state(initial)
	recompute()
	player.get_node("PlayerJobTransition").job_changed.connect(_job_changed)


func apply_state(data: Dictionary) -> void:
	var inventory = player.get_node("Inventory")
	inventory.gold = int(data.gold)
	inventory.bag.clear()
	for entry in data.bag:
		inventory.bag.append({"item": model.items[entry.item_id], "quantity": int(entry.quantity)})
	inventory.equipped_items.clear()
	inventory.equipped_rings = [null, null]
	for slot in data.equipment:
		var id: String = data.equipment[slot]
		if id == "":
			continue
		if slot in ["ring_1", "ring_2"]:
			inventory.equipped_rings[1 if slot == "ring_2" else 0] = model.items[id]
		else:
			inventory.equipped_items[model.registry.slots[slot]] = model.items[id]
	overflow = data.overflow.duplicate(true)


func recompute() -> void:
	var stats = player.get_node("PlayerStats")
	var result: CombatantStats = model.stats(level(), job_id(), state().equipment)
	for key in ["attack_power", "defense", "max_hp", "max_mp", "agility"]:
		stats.stats.set(key, result.get(key))
	stats.current_hp = minf(stats.current_hp, result.max_hp)
	stats.current_mp = minf(stats.current_mp, result.max_mp)
	stats.hp_changed.emit(stats.current_hp, result.max_hp)
	stats.mp_changed.emit(stats.current_mp, result.max_mp)


func act(kind: String, id: String = "", slot: String = "", count: int = 1) -> String:
	if busy:
		return "busy"
	if not model.definition_errors().is_empty():
		return "economy_content_error"
	if (
		kind in ["buy", "sell"]
		and (preload("res://scripts/economy/economy_merchants.gd").nearest(player) == null)
	):
		return "merchant_distance"
	if player.get_node("PlayerStats").is_dead() or player.is_input_locked:
		return "player_unavailable"
	# 거래/착용은 저장이 아니다. 메뉴에서 멈춘 재사용 대기를 요구하지 않는다.
	busy = true
	var next := state()
	var error := "action"
	match kind:
		"buy", "sell":
			error = model.trade(next, id, count, kind == "buy")
		"equip":
			error = model.equip(next, id, slot, level(), job_id())
		"recover":
			error = model.recover(next, count)
		"unequip":
			if next.equipment.has(slot) and next.equipment[slot] != "":
				error = "bag_full"
				if model.add(next.bag, next.equipment[slot], 1):
					next.equipment[slot] = ""
					error = ""
	if error == "":
		apply_state(next)
		recompute()
		player.get_node("Inventory").gold_changed.emit(next.gold)
		changed.emit()
	busy = false
	return error


func _job_changed(_job: StringName) -> void:
	var next := state()
	var previous: String = next.equipment.weapon
	var weapon: ItemData = player.get_node("PlayerJobTransition").granted_weapon()
	# can_transition에서 공간을 확인하며 복원에서는 이 연결 전 job_changed가 발신된다.
	if weapon != null:
		if previous != "":
			var preserved: bool = model.add(next.bag, previous, 1)
			assert(preserved)
			if not preserved:
				return
		next.equipment.weapon = weapon.item_id
		apply_state(next)
	recompute()
	changed.emit()
