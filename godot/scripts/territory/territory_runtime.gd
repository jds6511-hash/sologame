extends Node
## 한 월드에서 한 번만 실제 진행 시간을 적립한다. UI와 저장은 같은 meta를 읽는다.
signal changed
const Model = preload("res://scripts/territory/territory_model.gd")
const Travel = preload("res://scripts/territory/territory_travel.gd")
const DESK := Travel.TERRITORY_GATE
var world: Node2D
var player: Node2D
var remainder_ms := 0.0
var workshop: Node2D
var restoration: Node2D


func setup(owner_world: Node2D) -> void:
	world = owner_world
	player = world.get_node("Player")
	var quests: Dictionary = world.get_node("QuestController").journal.export_state()
	if not world.has_meta("territory_state"):
		world.set_meta("territory_state", Model.initial(quests))
	if not world.has_meta("travel_state"):
		world.set_meta("travel_state", Travel.initial(quests, world.map_id))
	_sync()
	Travel.visit(travel_state(), world.map_id)
	world.get_node("QuestController").journal.changed.connect(_sync)
	changed.connect(_refresh_buildings)
	_refresh_buildings.call_deferred()


func state() -> Dictionary:
	return world.get_meta("territory_state")


func travel_state() -> Dictionary:
	return world.get_meta("travel_state")


func _sync() -> void:
	Model.sync_ownership(state(), world.get_node("QuestController").journal.export_state())
	changed.emit()


func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	remainder_ms += delta * 1000.0
	var elapsed := int(remainder_ms)
	remainder_ms -= elapsed
	Model.advance(state(), elapsed)
	Travel.advance(travel_state(), elapsed)


func onsite() -> String:
	if player.position.distance_to(DESK) <= 40.0:
		return Travel.holding_for_map(world.map_id)
	return ""


func act(action: String) -> String:
	var economy: Node = player.get_meta("economy_candidate")
	if economy.busy or player.get_node("PlayerStats").is_dead() or player.is_input_locked:
		return "player_unavailable"
	economy.busy = true
	var next := state().duplicate(true)
	var inventory: Dictionary = economy.state()
	var error: String = Model.act(next, inventory, action, onsite())
	if error.is_empty():
		world.set_meta("territory_state", next)
		economy.apply_state(inventory)
		economy.changed.emit()
	economy.busy = false
	if error.is_empty():
		changed.emit()
	return error


func _refresh_buildings() -> void:
	var holding_id := Travel.holding_for_map(world.map_id)
	if not state().holdings.has(holding_id):
		return
	var holding: Dictionary = state().holdings[holding_id]
	if "workshop" in holding.facilities and not is_instance_valid(workshop):
		workshop = load("res://scripts/economy/economy_merchant.gd").new()
		workshop.name = "TerritoryWorkshop"
		workshop.position = Vector2(368, 488)
		world.add_child(workshop)
		workshop.configure(player, world.get_node("EconomyPanel"))
		workshop.get_node("Name").text = Travel.HOLDING_NAMES[holding_id] + " 공방"
		world.get_node("WorldInteraction").candidates.append(workshop)
	if not is_instance_valid(restoration):
		restoration = load("res://scripts/territory/territory_restoration.gd").new()
		restoration.name = "TerritoryRestoration"
		world.add_child(restoration)
	restoration.level = holding.development
	restoration.queue_redraw()
