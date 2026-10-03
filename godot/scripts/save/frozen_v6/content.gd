extends RefCounted
## 자동 생성: tools/generate_chapter_content.py · 원본 godot/data/content/*.json
const CURRENT_REVISION := 2
const BGM_CONTEXTS := {
	"eastern_frontier_start": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"novera_gate": "res://scenes/world/novera_gate.tscn",
	"novera_commons": "res://scenes/world/novera_gate.tscn",
	"novera_outskirts": "novera_outskirts",
	"novera_rift": "res://scenes/world/novera_gate.tscn",
	"yeoulmok_defense": "res://scenes/world/eastern_frontier_starting_area.tscn",
}
const SCENES := {
	"eastern_frontier_start": "res://scenes/world/product_world.tscn",
	"novera_gate": "res://scenes/world/product_world.tscn",
	"novera_commons": "res://scenes/world/product_world.tscn",
	"novera_outskirts": "res://scenes/world/product_world.tscn",
	"novera_rift": "res://scenes/world/product_world.tscn",
	"yeoulmok_defense": "res://scenes/world/product_world.tscn",
}
const NAMES := {
	"eastern_frontier_start": "여울목",
	"novera_gate": "노베라 입구",
	"novera_commons": "노베라 조합 거리",
	"novera_outskirts": "노베라 외곽",
	"novera_rift": "노베라 균열 던전",
	"yeoulmok_defense": "여울목 방어 현장",
}
const BOUNDS := {
	"eastern_frontier_start": Rect2(0, 0, 768, 576),
	"novera_gate": Rect2(0, 0, 768, 576),
	"novera_commons": Rect2(0, 0, 1024, 768),
	"novera_outskirts": Rect2(0, 0, 1280, 768),
	"novera_rift": Rect2(0, 0, 1024, 640),
	"yeoulmok_defense": Rect2(0, 0, 1024, 640),
}
const EDGES := {
	"yeoulmok_gatewarden":
	[
		"eastern_frontier_start",
		"novera_gate",
		Vector2(280, 456),
		Vector2(144, 440),
		"novera_gatewarden",
	],
	"novera_gatewarden":
	[
		"novera_gate",
		"eastern_frontier_start",
		Vector2(112, 440),
		Vector2(248, 456),
		"yeoulmok_gatewarden",
	],
	"novera_city_gate":
	[
		"novera_gate",
		"novera_commons",
		Vector2(688, 440),
		Vector2(128, 384),
		"commons_west_gate",
	],
	"commons_west_gate":
	[
		"novera_commons",
		"novera_gate",
		Vector2(96, 384),
		Vector2(640, 440),
		"novera_city_gate",
	],
	"commons_east_gate":
	[
		"novera_commons",
		"novera_outskirts",
		Vector2(928, 384),
		Vector2(144, 384),
		"outskirts_west_gate",
	],
	"outskirts_west_gate":
	[
		"novera_outskirts",
		"novera_commons",
		Vector2(96, 384),
		Vector2(880, 384),
		"commons_east_gate",
	],
	"outskirts_rift_gate":
	[
		"novera_outskirts",
		"novera_rift",
		Vector2(1168, 272),
		Vector2(144, 320),
		"rift_exit_gate",
	],
	"rift_exit_gate":
	[
		"novera_rift",
		"novera_outskirts",
		Vector2(96, 320),
		Vector2(1120, 320),
		"outskirts_rift_gate",
	],
	"yeoulmok_defense_gate":
	[
		"eastern_frontier_start",
		"yeoulmok_defense",
		Vector2(200, 392),
		Vector2(192, 544),
		"defense_exit_gate",
	],
	"defense_exit_gate":
	[
		"yeoulmok_defense",
		"eastern_frontier_start",
		Vector2(128, 544),
		Vector2(200, 456),
		"yeoulmok_defense_gate",
	],
}
const QUESTS := {
	"MQ-01-01": "res://data/quests/mq_01_01.tres",
	"MQ-01-02": "res://data/quests/mq_01_02.tres",
	"MQ-01-03": "res://data/quests/mq_01_03.tres",
	"MQ-01-04": "res://data/quests/mq_01_04.tres",
	"MQ-01-05": "res://data/quests/mq_01_05.tres",
	"MQ-02-01": "res://data/quests/m7/mq_02_01.tres",
	"MQ-02-02": "res://data/quests/m7/mq_02_02.tres",
	"MQ-02-03": "res://data/quests/m7/mq_02_03.tres",
	"MQ-02-04": "res://data/quests/m7/mq_02_04.tres",
	"MQ-02-05": "res://data/quests/m7_closure/mq_02_05.tres",
	"MQ-02-06": "res://data/quests/m7_closure/mq_02_06.tres",
	"SQ-NOV-001": "res://data/quests/m7_closure/sq_nov_001.tres",
	"SQ-NOV-002": "res://data/quests/m7_closure/sq_nov_002.tres",
	"MQ-03-01": "res://data/quests/chapter_three/mq_03_01.tres",
	"MQ-03-02": "res://data/quests/chapter_three/mq_03_02.tres",
	"MQ-03-03": "res://data/quests/chapter_three/mq_03_03.tres",
	"MQ-03-04": "res://data/quests/chapter_three/mq_03_04.tres",
	"MQ-03-05": "res://data/quests/chapter_three/mq_03_05.tres",
	"SQ-YEO-001": "res://data/quests/chapter_three/sq_yeo_001.tres",
	"SQ-YEO-002": "res://data/quests/chapter_three/sq_yeo_002.tres",
	"SQ-YEO-003": "res://data/quests/chapter_three/sq_yeo_003.tres",
}
const NPCS := {
	"yeoulmok_receptionist": ["eastern_frontier_start", Vector2(152, 440), "접수원"],
	"novera_receptionist": ["novera_commons", Vector2(480, 320), "노베라 조합 접수원"],
	"novera_trainer": ["novera_commons", Vector2(544, 320), "전직 안내인"],
	"novera_gareth": ["novera_commons", Vector2(656, 320), "가레스"],
	"defense_coordinator": ["yeoulmok_defense", Vector2(288, 512), "현장 책임자"],
	"novera_examiner": ["novera_commons", Vector2(736, 416), "문장원 심사 담당"],
}
const MERCHANTS := {
	"novera_gate": [Vector2(216, 440)],
	"novera_commons": [Vector2(416, 416)],
}
const REGION_REQUIREMENTS := {
	"novera_gate": "MQ-01-05",
	"novera_commons": "MQ-01-05",
	"novera_outskirts": "MQ-01-05",
	"novera_rift": "MQ-02-04",
	"yeoulmok_defense": "MQ-03-01",
}
const SITES := {
	"yeoulmok_old_rift_entrance":
	[
		Vector2(152, 200),
		"yeoulmok_old_rift_site",
		"REACH",
		"북쪽 오솔길 조사 지점",
		"eastern_frontier_start",
	],
	"yeoulmok_rift_mark":
	[
		Vector2(168, 200),
		"yeoulmok_old_rift_site",
		"INTERACT",
		"균열 표식",
		"eastern_frontier_start",
	],
	"novera_water_marker":
	[Vector2(352, 272), "novera_water_site", "REACH", "물가 통행 표식", "novera_outskirts"],
	"novera_rift_marker":
	[Vector2(1120, 272), "novera_rift_site", "INTERACT", "균열 흔적 조사", "novera_outskirts"],
	"novera_patrol_marker":
	[Vector2(272, 128), "novera_patrol_site", "REACH", "외곽 정찰 표식", "novera_outskirts"],
	"novera_return_record_a":
	[
		Vector2(400, 272),
		"novera_return_record_a_site",
		"INTERACT",
		"서쪽 귀환 기록",
		"novera_outskirts",
	],
	"novera_return_record_b":
	[
		Vector2(1072, 384),
		"novera_return_record_b_site",
		"INTERACT",
		"동쪽 귀환 기록",
		"novera_outskirts",
	],
	"novera_rift_chamber":
	[Vector2(432, 320), "novera_rift_chamber_site", "REACH", "조사실 도달 표식", "novera_rift"],
	"novera_rift_relic":
	[Vector2(928, 272), "novera_rift_relic_site", "INTERACT", "유물 조사", "novera_rift"],
	"novera_rift_record_a":
	[
		Vector2(224, 240),
		"novera_rift_record_a_site",
		"INTERACT",
		"입구실 측량 기록",
		"novera_rift",
	],
	"novera_rift_record_b":
	[
		Vector2(656, 272),
		"novera_rift_record_b_site",
		"INTERACT",
		"조사실 측량 기록",
		"novera_rift",
	],
	"yeoulmok_defense_arrival":
	[
		Vector2(240, 448),
		"yeoulmok_defense_arrival_site",
		"REACH",
		"안전 집결지 도착",
		"yeoulmok_defense",
	],
	"yeoulmok_evacuation_1":
	[
		Vector2(288, 368),
		"yeoulmok_evacuation_1_site",
		"INTERACT",
		"대피 안내 1",
		"yeoulmok_defense",
	],
	"yeoulmok_evacuation_2":
	[
		Vector2(512, 368),
		"yeoulmok_evacuation_2_site",
		"INTERACT",
		"대피 안내 2",
		"yeoulmok_defense",
	],
	"yeoulmok_evacuation_3":
	[
		Vector2(736, 368),
		"yeoulmok_evacuation_3_site",
		"INTERACT",
		"대피 안내 3",
		"yeoulmok_defense",
	],
	"yeoulmok_defense_confirm":
	[
		Vector2(512, 288),
		"yeoulmok_defense_confirm_site",
		"INTERACT",
		"방어선 확인",
		"yeoulmok_defense",
	],
	"yeoulmok_shadow_trace":
	[
		Vector2(608, 256),
		"yeoulmok_shadow_trace_site",
		"INTERACT",
		"남겨진 흔적 조사",
		"yeoulmok_defense",
	],
	"yeoulmok_resident_testimony":
	[
		Vector2(800, 416),
		"yeoulmok_resident_testimony_site",
		"INTERACT",
		"주민 증언 확인",
		"novera_commons",
	],
	"yeoulmok_rescue_1":
	[
		Vector2(576, 416),
		"yeoulmok_rescue_1_site",
		"INTERACT",
		"주민 구조 1",
		"yeoulmok_defense",
	],
	"yeoulmok_rescue_2":
	[
		Vector2(800, 416),
		"yeoulmok_rescue_2_site",
		"INTERACT",
		"주민 구조 2",
		"yeoulmok_defense",
	],
	"yeoulmok_supply_1":
	[
		Vector2(352, 320),
		"yeoulmok_supply_1_site",
		"INTERACT",
		"보급 기록 1",
		"yeoulmok_defense",
	],
	"yeoulmok_supply_2":
	[
		Vector2(672, 320),
		"yeoulmok_supply_2_site",
		"INTERACT",
		"보급 기록 2",
		"yeoulmok_defense",
	],
	"yeoulmok_record_1":
	[
		Vector2(256, 240),
		"yeoulmok_record_1_site",
		"INTERACT",
		"부락 기록 1",
		"yeoulmok_defense",
	],
	"yeoulmok_record_2":
	[
		Vector2(800, 240),
		"yeoulmok_record_2_site",
		"INTERACT",
		"부락 기록 2",
		"yeoulmok_defense",
	],
}
const MARKER_HABITATS := {
	"yeoulmok_rabbit_habitat": ["eastern_frontier_start", "Markers/MonsterSpawns_뿔토끼"],
	"yeoulmok_dog_habitat": ["eastern_frontier_start", "Markers/MonsterSpawns_들개마수"],
}
const HABITATS := {
	"novera_dog_habitat":
	[
		"novera_outskirts",
		[Vector2(384, 560), Vector2(608, 560), Vector2(832, 560)],
		"wolf",
		"feral_dog",
	],
	"novera_water_habitat":
	[
		"novera_outskirts",
		[Vector2(448, 352), Vector2(672, 352), Vector2(896, 352)],
		"rift_slime",
		"rift_slime",
	],
	"novera_rift_habitat":
	[
		"novera_outskirts",
		[Vector2(544, 128), Vector2(736, 128), Vector2(928, 128), Vector2(1120, 128)],
		"rift_slime",
		"rift_slime",
	],
	"novera_dungeon_habitat":
	[
		"novera_rift",
		[Vector2(544, 400), Vector2(704, 400), Vector2(848, 400)],
		"rift_slime",
		"rift_slime",
	],
}
const MARKER_CONTENT_IDS := {
	"yeoulmok_rabbit_habitat": "horned_rabbit",
	"yeoulmok_dog_habitat": "feral_dog",
}
const DEFENSE_WAVES := {
	"yeoulmok_defense_wave_1":
	{
		"quest_id": "MQ-03-03",
		"index": 0,
		"region": "yeoulmok_defense",
		"points": [Vector2(352, 192), Vector2(512, 192), Vector2(672, 192)],
		"scene": "wolf",
		"content_id": "feral_dog",
		"stats": "res://data/monsters/chapter_three/defense_wolf.tres",
	},
	"yeoulmok_defense_wave_2":
	{
		"quest_id": "MQ-03-03",
		"index": 1,
		"region": "yeoulmok_defense",
		"points": [Vector2(352, 192), Vector2(512, 192), Vector2(672, 192)],
		"scene": "wolf",
		"content_id": "feral_dog",
		"stats": "res://data/monsters/chapter_three/defense_wolf.tres",
	},
	"yeoulmok_defense_elite":
	{
		"quest_id": "MQ-03-04",
		"index": 0,
		"region": "yeoulmok_defense",
		"points": [Vector2(512, 160)],
		"scene": "rift_slime",
		"content_id": "rift_slime",
		"stats": "res://data/monsters/chapter_three/defense_elite.tres",
	},
}
const RALLIES := {
	"defense_rally":
	{
		"region": "yeoulmok_defense",
		"position": Vector2(416, 480),
		"title": "방어 재개",
	},
}
const SITE_NOTICES := {
	"yeoulmok_shadow_trace": "무너진 방책 너머에서 그림자가 마수들에게 말을 건넨다. 눈을 돌린 순간 모습은 사라졌다. 누구인지는 알 수 없다.",
}
const LAYOUTS := {
	"yeoulmok_defense":
	{
		"spawn": Vector2(192, 544),
		"floor": Vector2i(0, 0),
		"patches": [],
	},
}
const QUEST_REQUIREMENTS := {
	"MQ-03-01":
	{
		"reputation": 500,
	},
	"MQ-03-05":
	{
		"reputation": 500,
	},
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
