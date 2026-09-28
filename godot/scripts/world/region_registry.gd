extends RefCounted

const START := "eastern_frontier_start"
const NEXT := "novera_gate"
const SCENES := {
	START: "res://scenes/world/eastern_frontier_starting_area.tscn",
	NEXT: "res://scenes/world/novera_gate.tscn"
}
const ARRIVALS := {START: Vector2(248, 456), NEXT: Vector2(144, 440)}
const GATES := {START: Vector2(280, 456), NEXT: Vector2(112, 440)}
## 지역별 실제 월드 경계. 현재 두 맵의 크기가 같아도 공통 규격으로 취급하지 않는다.
const BOUNDS := {START: Rect2(0, 0, 768, 576), NEXT: Rect2(0, 0, 768, 576)}


static func contains(map_id: String, position: Vector2) -> bool:
	return SCENES.has(map_id) and BOUNDS.has(map_id) and BOUNDS[map_id].has_point(position)
