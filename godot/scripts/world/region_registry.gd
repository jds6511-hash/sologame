extends RefCounted

const START := "eastern_frontier_start"
const NEXT := "novera_gate"
const SCENES := {
	START: "res://scenes/world/eastern_frontier_starting_area.tscn",
	NEXT: "res://scenes/world/novera_gate.tscn"
}
const ARRIVALS := {START: Vector2(248, 456), NEXT: Vector2(144, 440)}
const GATES := {START: Vector2(280, 456), NEXT: Vector2(112, 440)}


static func contains(map_id: String, position: Vector2) -> bool:
	return SCENES.has(map_id) and Rect2(0, 0, 768, 576).has_point(position)
