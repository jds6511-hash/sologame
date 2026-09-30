extends RefCounted
## 후보 V7 전용. V6 목록은 동결한다.
const SCENES := {
	"eastern_frontier_start": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"novera_gate": "res://scenes/world/novera_gate.tscn",
	"novera_commons": "candidate",
	"novera_outskirts": "candidate",
	"novera_rift": "candidate",
}
const NAMES := {
	"eastern_frontier_start": "여울목",
	"novera_gate": "노베라 입구",
	"novera_commons": "노베라 조합 거리",
	"novera_outskirts": "노베라 외곽",
	"novera_rift": "노베라 균열 던전"
}
const BOUNDS := {
	"eastern_frontier_start": Rect2(0, 0, 768, 576),
	"novera_gate": Rect2(0, 0, 768, 576),
	"novera_commons": Rect2(0, 0, 1024, 768),
	"novera_outskirts": Rect2(0, 0, 1280, 768),
	"novera_rift": Rect2(0, 0, 1024, 640),
}
# 출발 지역, 도착 지역, 출발 관문, 도착 위치, 도착 관문 ID.
const EDGES := {
	"yeoulmok_gatewarden":
	[
		"eastern_frontier_start",
		"novera_gate",
		Vector2(280, 456),
		Vector2(144, 440),
		"novera_gatewarden"
	],
	"novera_gatewarden":
	[
		"novera_gate",
		"eastern_frontier_start",
		Vector2(112, 440),
		Vector2(248, 456),
		"yeoulmok_gatewarden"
	],
	"novera_city_gate":
	["novera_gate", "novera_commons", Vector2(688, 440), Vector2(128, 384), "commons_west_gate"],
	"commons_west_gate":
	["novera_commons", "novera_gate", Vector2(96, 384), Vector2(640, 440), "novera_city_gate"],
	"commons_east_gate":
	[
		"novera_commons",
		"novera_outskirts",
		Vector2(928, 384),
		Vector2(144, 384),
		"outskirts_west_gate"
	],
	"outskirts_west_gate":
	[
		"novera_outskirts",
		"novera_commons",
		Vector2(96, 384),
		Vector2(880, 384),
		"commons_east_gate"
	],
	"outskirts_rift_gate": ["novera_outskirts", "novera_rift", Vector2(1168, 272), Vector2(144, 320), "rift_exit_gate"],
	"rift_exit_gate": ["novera_rift", "novera_outskirts", Vector2(96, 320), Vector2(1120, 320), "outskirts_rift_gate"],
}


static func contains(id: String, point: Vector2) -> bool:
	return BOUNDS.has(id) and BOUNDS[id].has_point(point)


static func edge(source: String, destination: String) -> Array:
	for value in EDGES.values():
		if value[0] == source and value[1] == destination:
			return value
	return []


static func next_gate(source: String, destination: String) -> String:
	var pending := [[source, ""]]
	var seen := {source: true}
	while not pending.is_empty():
		var current: Array = pending.pop_front()
		for id in EDGES:
			var value: Array = EDGES[id]
			if value[0] != current[0] or seen.has(value[1]):
				continue
			var first: String = id if current[1] == "" else current[1]
			if value[1] == destination:
				return first
			seen[value[1]] = true
			pending.append([value[1], first])
	return ""
