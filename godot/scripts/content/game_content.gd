extends RefCounted
## 자동 생성: tools/generate_chapter_content.py · 원본 godot/data/content/*.json
const CURRENT_REVISION := 4
const BGM_CONTEXTS := {
	"eastern_frontier_start": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"novera_gate": "res://scenes/world/novera_gate.tscn",
	"novera_commons": "res://scenes/world/novera_gate.tscn",
	"novera_outskirts": "novera_outskirts",
	"novera_rift": "res://scenes/world/novera_gate.tscn",
	"yeoulmok_defense": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"han_gilmok": "res://scenes/world/novera_gate.tscn",
	"gransia": "res://scenes/world/novera_gate.tscn",
	"brantel": "res://scenes/world/novera_gate.tscn",
	"saleno": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"saleno_coast": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"reed_marsh": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"arsel": "res://scenes/world/novera_gate.tscn",
	"arsel_library": "res://scenes/world/novera_gate.tscn",
}
const SCENES := {
	"eastern_frontier_start": "res://scenes/world/product_world.tscn",
	"novera_gate": "res://scenes/world/product_world.tscn",
	"novera_commons": "res://scenes/world/product_world.tscn",
	"novera_outskirts": "res://scenes/world/product_world.tscn",
	"novera_rift": "res://scenes/world/product_world.tscn",
	"yeoulmok_defense": "res://scenes/world/product_world.tscn",
	"han_gilmok": "res://scenes/world/product_world.tscn",
	"gransia": "res://scenes/world/product_world.tscn",
	"brantel": "res://scenes/world/product_world.tscn",
	"saleno": "res://scenes/world/product_world.tscn",
	"saleno_coast": "res://scenes/world/product_world.tscn",
	"reed_marsh": "res://scenes/world/product_world.tscn",
	"arsel": "res://scenes/world/product_world.tscn",
	"arsel_library": "res://scenes/world/product_world.tscn",
}
const NAMES := {
	"eastern_frontier_start": "여울목",
	"novera_gate": "노베라 입구",
	"novera_commons": "노베라 조합 거리",
	"novera_outskirts": "노베라 외곽",
	"novera_rift": "노베라 균열 던전",
	"yeoulmok_defense": "여울목 방어 현장",
	"han_gilmok": "한길목 가도",
	"gransia": "그란시아 평야",
	"brantel": "브란텔 문장원",
	"saleno": "살레노 항구",
	"saleno_coast": "살레노 해안",
	"reed_marsh": "갈밭 습지",
	"arsel": "아르셀 호반",
	"arsel_library": "아르셀 대도서관",
}
const BOUNDS := {
	"eastern_frontier_start": Rect2(0, 0, 768, 576),
	"novera_gate": Rect2(0, 0, 768, 576),
	"novera_commons": Rect2(0, 0, 1024, 768),
	"novera_outskirts": Rect2(0, 0, 1280, 768),
	"novera_rift": Rect2(0, 0, 1024, 640),
	"yeoulmok_defense": Rect2(0, 0, 1024, 640),
	"han_gilmok": Rect2(0, 0, 1536, 960),
	"gransia": Rect2(0, 0, 1536, 960),
	"brantel": Rect2(0, 0, 1536, 960),
	"saleno": Rect2(0, 0, 1536, 960),
	"saleno_coast": Rect2(0, 0, 1536, 960),
	"reed_marsh": Rect2(0, 0, 1536, 960),
	"arsel": Rect2(0, 0, 1536, 960),
	"arsel_library": Rect2(0, 0, 1536, 960),
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
	"novera_commons_to_han_gilmok":
	[
		"novera_commons",
		"han_gilmok",
		Vector2(912, 480),
		Vector2(192, 480),
		"han_gilmok_to_novera_commons",
	],
	"han_gilmok_to_novera_commons":
	[
		"han_gilmok",
		"novera_commons",
		Vector2(112, 480),
		Vector2(848, 480),
		"novera_commons_to_han_gilmok",
	],
	"han_gilmok_to_gransia":
	[
		"han_gilmok",
		"gransia",
		Vector2(1408, 480),
		Vector2(192, 480),
		"gransia_to_han_gilmok",
	],
	"gransia_to_han_gilmok":
	[
		"gransia",
		"han_gilmok",
		Vector2(112, 480),
		Vector2(1344, 480),
		"han_gilmok_to_gransia",
	],
	"gransia_to_brantel":
	["gransia", "brantel", Vector2(1408, 480), Vector2(192, 480), "brantel_to_gransia"],
	"brantel_to_gransia":
	["brantel", "gransia", Vector2(112, 480), Vector2(1344, 480), "gransia_to_brantel"],
	"brantel_to_saleno":
	["brantel", "saleno", Vector2(1408, 480), Vector2(176, 480), "saleno_to_brantel"],
	"saleno_to_brantel":
	["saleno", "brantel", Vector2(96, 480), Vector2(1344, 480), "brantel_to_saleno"],
	"saleno_to_saleno_coast":
	[
		"saleno",
		"saleno_coast",
		Vector2(1408, 480),
		Vector2(176, 480),
		"saleno_coast_to_saleno",
	],
	"saleno_coast_to_saleno":
	[
		"saleno_coast",
		"saleno",
		Vector2(96, 480),
		Vector2(1344, 480),
		"saleno_to_saleno_coast",
	],
	"saleno_coast_to_reed_marsh":
	[
		"saleno_coast",
		"reed_marsh",
		Vector2(1408, 480),
		Vector2(176, 480),
		"reed_marsh_to_saleno_coast",
	],
	"reed_marsh_to_saleno_coast":
	[
		"reed_marsh",
		"saleno_coast",
		Vector2(96, 480),
		Vector2(1344, 480),
		"saleno_coast_to_reed_marsh",
	],
	"reed_marsh_to_arsel":
	["reed_marsh", "arsel", Vector2(1408, 480), Vector2(176, 480), "arsel_to_reed_marsh"],
	"arsel_to_reed_marsh":
	["arsel", "reed_marsh", Vector2(96, 480), Vector2(1344, 480), "reed_marsh_to_arsel"],
	"arsel_to_arsel_library":
	[
		"arsel",
		"arsel_library",
		Vector2(1408, 480),
		Vector2(176, 480),
		"arsel_library_to_arsel",
	],
	"arsel_library_to_arsel":
	[
		"arsel_library",
		"arsel",
		Vector2(96, 480),
		Vector2(1344, 480),
		"arsel_to_arsel_library",
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
	"MQ-04-01": "res://data/quests/chapter_four/mq_04_01.tres",
	"MQ-04-02": "res://data/quests/chapter_four/mq_04_02.tres",
	"MQ-04-03": "res://data/quests/chapter_four/mq_04_03.tres",
	"MQ-04-04": "res://data/quests/chapter_four/mq_04_04.tres",
	"SQ-CH04-001": "res://data/quests/chapter_four/sq_ch04_001.tres",
	"SQ-CH04-002": "res://data/quests/chapter_four/sq_ch04_002.tres",
	"SQ-CH04-003": "res://data/quests/chapter_four/sq_ch04_003.tres",
	"SQ-CH04-004": "res://data/quests/chapter_four/sq_ch04_004.tres",
	"SQ-CH04-005": "res://data/quests/chapter_four/sq_ch04_005.tres",
	"MQ-05-01": "res://data/quests/chapter_five/mq_05_01.tres",
	"MQ-05-02": "res://data/quests/chapter_five/mq_05_02.tres",
	"MQ-05-03": "res://data/quests/chapter_five/mq_05_03.tres",
	"MQ-05-04": "res://data/quests/chapter_five/mq_05_04.tres",
	"MQ-05-05": "res://data/quests/chapter_five/mq_05_05.tres",
	"SQ-CH05-001": "res://data/quests/chapter_five/sq_ch05_001.tres",
	"SQ-CH05-002": "res://data/quests/chapter_five/sq_ch05_002.tres",
	"SQ-CH05-003": "res://data/quests/chapter_five/sq_ch05_003.tres",
	"SQ-CH05-004": "res://data/quests/chapter_five/sq_ch05_004.tres",
	"SQ-CH05-005": "res://data/quests/chapter_five/sq_ch05_005.tres",
	"SQ-CH05-006": "res://data/quests/chapter_five/sq_ch05_006.tres",
	"SQ-CH05-007": "res://data/quests/chapter_five/sq_ch05_007.tres",
}
const NPCS := {
	"yeoulmok_receptionist": ["eastern_frontier_start", Vector2(152, 440), "접수원"],
	"novera_receptionist": ["novera_commons", Vector2(480, 320), "노베라 조합 접수원"],
	"novera_trainer": ["novera_commons", Vector2(544, 320), "전직 안내인"],
	"novera_gareth": ["novera_commons", Vector2(656, 320), "가레스"],
	"defense_coordinator": ["yeoulmok_defense", Vector2(288, 512), "현장 책임자"],
	"novera_examiner": ["novera_commons", Vector2(736, 416), "문장원 심사 담당"],
	"han_patrol": ["han_gilmok", Vector2(304, 432), "가도 담당관"],
	"gransia_steward": ["gransia", Vector2(336, 432), "장원 관리인"],
	"brantel_herald": ["brantel", Vector2(432, 432), "문장원 담당관"],
	"mariel": ["brantel", Vector2(704, 384), "마리엔"],
	"arvein": ["brantel", Vector2(864, 384), "오르베인"],
	"saleno_factor": ["saleno", Vector2(400, 432), "살레노 운송 담당"],
	"saleno_fisher": ["saleno", Vector2(736, 736), "부두 어민 대표"],
	"coast_patrol": ["saleno_coast", Vector2(288, 480), "해안 순찰대장"],
	"marsh_guide": ["reed_marsh", Vector2(304, 480), "갈밭 길잡이"],
	"arsel_scholar": ["arsel", Vector2(576, 480), "아르셀 기록 연구원"],
	"arsel_librarian": ["arsel_library", Vector2(304, 480), "대도서관 사서"],
}
const MERCHANTS := {
	"novera_gate": [Vector2(216, 440)],
	"novera_commons": [Vector2(416, 416)],
	"han_gilmok": [Vector2(240, 528)],
	"gransia": [Vector2(240, 528)],
	"brantel": [Vector2(240, 528)],
	"saleno": [Vector2(480, 528)],
	"arsel": [Vector2(448, 528)],
}
const REGION_REQUIREMENTS := {
	"novera_gate": "MQ-01-05",
	"novera_commons": "MQ-01-05",
	"novera_outskirts": "MQ-01-05",
	"novera_rift": "MQ-02-04",
	"yeoulmok_defense": "MQ-03-01",
	"han_gilmok": "MQ-03-05",
	"gransia": "MQ-04-01",
	"brantel": "MQ-04-02",
	"saleno": "MQ-04-04",
	"saleno_coast": "MQ-05-01",
	"reed_marsh": "MQ-05-02",
	"arsel": "MQ-05-02",
	"arsel_library": "MQ-05-03",
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
	"han_arrival": [Vector2(224, 480), "han_arrival_site", "REACH", "한길목 가도 도착", "han_gilmok"],
	"gransia_boundary":
	[Vector2(704, 320), "gransia_boundary_site", "INTERACT", "장원 경계 조사", "gransia"],
	"gransia_record":
	[Vector2(1120, 368), "gransia_record_site", "INTERACT", "평야 조사 기록", "gransia"],
	"brantel_records":
	[Vector2(608, 288), "brantel_records_site", "INTERACT", "문장원 기록 대조", "brantel"],
	"arvein_dispatch":
	[Vector2(928, 432), "arvein_dispatch_site", "INTERACT", "왕가 원정 출정식", "brantel"],
	"frontier_commission":
	[
		Vector2(512, 544),
		"frontier_commission_site",
		"INTERACT",
		"변경 조사관 임명장 확인",
		"brantel",
	],
	"han_nest": [Vector2(1088, 352), "han_nest_site", "INTERACT", "멧돼지 서식 흔적", "han_gilmok"],
	"gransia_crop": [Vector2(432, 320), "gransia_crop_site", "INTERACT", "작물 피해 조사", "gransia"],
	"gransia_feather":
	[Vector2(1168, 672), "gransia_feather_site", "INTERACT", "장원 습격 흔적", "gransia"],
	"han_supply": [Vector2(560, 624), "han_supply_site", "INTERACT", "가도 보급 상자", "han_gilmok"],
	"gransia_supply": [Vector2(944, 544), "gransia_supply_site", "INTERACT", "장원 보급 장부", "gransia"],
	"brantel_petition":
	[Vector2(1024, 624), "brantel_petition_site", "INTERACT", "주민 민원 접수", "brantel"],
	"saleno_arrival": [Vector2(240, 480), "saleno_arrival_site", "REACH", "살레노 항구 도착", "saleno"],
	"saleno_manifest":
	[Vector2(880, 240), "saleno_manifest_site", "INTERACT", "창고 운송장 확인", "saleno"],
	"coast_cargo": [Vector2(1120, 400), "coast_cargo_site", "INTERACT", "유실 화물 조사", "saleno_coast"],
	"coast_seal": [Vector2(704, 656), "coast_seal_site", "INTERACT", "화물 봉인 대조", "saleno_coast"],
	"marsh_cache": [Vector2(1120, 416), "marsh_cache_site", "INTERACT", "촉매 밀거래 흔적", "reed_marsh"],
	"marsh_route": [Vector2(752, 576), "marsh_route_site", "INTERACT", "은폐 운송로 조사", "reed_marsh"],
	"arsel_ledger":
	[Vector2(576, 400), "arsel_ledger_site", "INTERACT", "소장 기록 조사", "arsel_library"],
	"arsel_gap": [Vector2(944, 448), "arsel_gap_site", "INTERACT", "기록 누락 대조", "arsel_library"],
	"arsel_comparison":
	[Vector2(960, 480), "arsel_comparison_site", "INTERACT", "항구와 도서관 기록 대조", "arsel"],
	"saleno_mooring":
	[Vector2(1152, 240), "saleno_mooring_site", "INTERACT", "북쪽 계류줄 확인", "saleno"],
	"saleno_pier": [Vector2(1216, 736), "saleno_pier_site", "INTERACT", "남쪽 부두 확인", "saleno"],
	"saleno_count": [Vector2(592, 304), "saleno_count_site", "INTERACT", "창고 재고 확인", "saleno"],
	"saleno_receipt": [Vector2(832, 480), "saleno_receipt_site", "INTERACT", "하역 영수증 대조", "saleno"],
	"coast_net": [Vector2(896, 608), "coast_net_site", "INTERACT", "유실 그물 회수", "saleno_coast"],
	"coast_tide": [Vector2(544, 400), "coast_tide_site", "INTERACT", "밀물 표식 확인", "saleno_coast"],
	"coast_beacon":
	[Vector2(1248, 640), "coast_beacon_site", "INTERACT", "해안 등표 점검", "saleno_coast"],
	"marsh_walkway":
	[Vector2(768, 752), "marsh_walkway_site", "INTERACT", "둑길 안전 확인", "reed_marsh"],
	"marsh_marker":
	[Vector2(1232, 672), "marsh_marker_site", "INTERACT", "습지 이정표 복구", "reed_marsh"],
	"arsel_notes": [Vector2(528, 320), "arsel_notes_site", "INTERACT", "호반 주민 기록", "arsel"],
	"arsel_index":
	[Vector2(1216, 480), "arsel_index_site", "INTERACT", "참고 목록 정리", "arsel_library"],
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
	"han_boars":
	[
		"han_gilmok",
		[Vector2(544, 272), Vector2(768, 272), Vector2(1024, 272)],
		"outlaw",
		"wild_boar",
	],
	"gransia_scarecrows":
	[
		"gransia",
		[Vector2(512, 224), Vector2(768, 224), Vector2(1024, 224)],
		"wolf",
		"cursed_scarecrow",
	],
	"gransia_harpies":
	[
		"gransia",
		[Vector2(544, 736), Vector2(800, 736), Vector2(1088, 736)],
		"forest_spider",
		"cliff_harpy",
	],
	"han_highwaymen":
	["han_gilmok", [Vector2(640, 784), Vector2(896, 784)], "highwayman", "highwayman"],
	"saleno_crabs":
	[
		"saleno_coast",
		[Vector2(544, 272), Vector2(768, 304), Vector2(1088, 288)],
		"wolf",
		"tidal_crab",
	],
	"marsh_lizards":
	[
		"reed_marsh",
		[Vector2(720, 288), Vector2(960, 320), Vector2(1216, 288)],
		"outlaw",
		"marsh_lizard",
	],
	"marsh_mist":
	[
		"reed_marsh",
		[Vector2(384, 736), Vector2(640, 752), Vector2(1280, 736)],
		"rift_slime",
		"water_mist",
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
	"arvein_dispatch": "오르베인이 원정대 앞에 선다. 왕가의 깃발 아래 병사들이 대열을 정비한다. 마리엔은 변경의 주민을 살피고 돌아오라 당부한다.",
	"arsel_gap": "목록에 적힌 일부 기록을 열람할 수 없다. 사서는 남아 있는 문헌의 목록을 내어준다. 누락 이유는 확인되지 않았다.",
}
const LAYOUTS := {
	"yeoulmok_defense":
	{
		"spawn": Vector2(192, 544),
		"floor": Vector2i(0, 0),
		"patches": [],
	},
	"han_gilmok":
	{
		"spawn": Vector2(160, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 27, 84, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(42, 6, 8, 48),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"gransia":
	{
		"spawn": Vector2(160, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 27, 84, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(42, 6, 8, 48),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"brantel":
	{
		"spawn": Vector2(160, 480),
		"floor": Vector2i(2, 2),
		"patches":
		[
			{
				"rect": Rect2(6, 27, 84, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(42, 6, 8, 48),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"saleno":
	{
		"spawn": Vector2(160, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(5, 27, 85, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(64, 1, 31, 58),
				"tile": Vector2i(1, 1),
			},
			{
				"rect": Rect2(50, 12, 40, 5),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(50, 27, 40, 5),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(50, 44, 40, 5),
				"tile": Vector2i(2, 0),
			},
		],
	},
	"saleno_coast":
	{
		"spawn": Vector2(160, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(5, 27, 85, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(1, 1, 94, 10),
				"tile": Vector2i(1, 1),
			},
			{
				"rect": Rect2(8, 11, 82, 8),
				"tile": Vector2i(2, 0),
			},
		],
	},
	"reed_marsh":
	{
		"spawn": Vector2(160, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(5, 27, 85, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(24, 8, 14, 16),
				"tile": Vector2i(1, 1),
			},
			{
				"rect": Rect2(57, 36, 16, 17),
				"tile": Vector2i(1, 1),
			},
			{
				"rect": Rect2(44, 8, 6, 45),
				"tile": Vector2i(2, 0),
			},
		],
	},
	"arsel":
	{
		"spawn": Vector2(160, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(5, 27, 85, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(1, 1, 25, 24),
				"tile": Vector2i(1, 1),
			},
			{
				"rect": Rect2(29, 8, 6, 46),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"arsel_library":
	{
		"spawn": Vector2(160, 480),
		"floor": Vector2i(2, 2),
		"patches":
		[
			{
				"rect": Rect2(5, 27, 85, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(24, 7, 3, 12),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(24, 38, 3, 12),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(46, 7, 3, 12),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(46, 38, 3, 12),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(68, 7, 3, 12),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(68, 38, 3, 12),
				"tile": Vector2i(1, 2),
			},
		],
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
	"MQ-04-01":
	{
		"reputation": 800,
	},
	"MQ-05-01":
	{
		"reputation": 1400,
	},
}
const MONSTER_VARIANTS := {
	"wild_boar":
	{
		"title": "사나운 멧돼지",
		"scene": "outlaw",
		"stats": "res://data/monsters/chapter_four/wild_boar.tres",
		"level": 16,
	},
	"cursed_scarecrow":
	{
		"title": "괴뢰 허수아비",
		"scene": "wolf",
		"stats": "res://data/monsters/chapter_four/cursed_scarecrow.tres",
		"level": 18,
	},
	"cliff_harpy":
	{
		"title": "들매 하피",
		"scene": "forest_spider",
		"stats": "res://data/monsters/chapter_four/cliff_harpy.tres",
		"level": 21,
	},
	"tidal_crab":
	{
		"title": "갯게 마수",
		"scene": "wolf",
		"stats": "res://data/monsters/chapter_five/tidal_crab.tres",
		"level": 24,
	},
	"marsh_lizard":
	{
		"title": "습지 도마뱀전사",
		"scene": "outlaw",
		"stats": "res://data/monsters/chapter_five/marsh_lizard.tres",
		"level": 27,
	},
	"water_mist":
	{
		"title": "물안개 정령",
		"scene": "rift_slime",
		"stats": "res://data/monsters/chapter_five/water_mist.tres",
		"level": 29,
	},
}
const WARP_ARRIVALS := {
	"novera_commons": Vector2(128, 384),
	"eastern_frontier_start": Vector2(152, 504),
	"gransia": Vector2(192, 480),
	"brantel": Vector2(192, 480),
	"saleno": Vector2(176, 480),
	"arsel": Vector2(176, 480),
}
const QUEST_REVISIONS := {
	"MQ-01-01": 1,
	"MQ-01-02": 1,
	"MQ-01-03": 1,
	"MQ-01-04": 1,
	"MQ-01-05": 1,
	"MQ-02-01": 1,
	"MQ-02-02": 1,
	"MQ-02-03": 1,
	"MQ-02-04": 1,
	"MQ-02-05": 1,
	"MQ-02-06": 1,
	"SQ-NOV-001": 1,
	"SQ-NOV-002": 1,
	"MQ-03-01": 2,
	"MQ-03-02": 2,
	"MQ-03-03": 2,
	"MQ-03-04": 2,
	"MQ-03-05": 2,
	"SQ-YEO-001": 2,
	"SQ-YEO-002": 2,
	"SQ-YEO-003": 2,
	"MQ-04-01": 3,
	"MQ-04-02": 3,
	"MQ-04-03": 3,
	"MQ-04-04": 3,
	"SQ-CH04-001": 3,
	"SQ-CH04-002": 3,
	"SQ-CH04-003": 3,
	"SQ-CH04-004": 3,
	"SQ-CH04-005": 3,
	"MQ-05-01": 4,
	"MQ-05-02": 4,
	"MQ-05-03": 4,
	"MQ-05-04": 4,
	"MQ-05-05": 4,
	"SQ-CH05-001": 4,
	"SQ-CH05-002": 4,
	"SQ-CH05-003": 4,
	"SQ-CH05-004": 4,
	"SQ-CH05-005": 4,
	"SQ-CH05-006": 4,
	"SQ-CH05-007": 4,
}
const REGION_REVISIONS := {
	"eastern_frontier_start": 1,
	"novera_gate": 1,
	"novera_commons": 1,
	"novera_outskirts": 1,
	"novera_rift": 1,
	"yeoulmok_defense": 2,
	"han_gilmok": 3,
	"gransia": 3,
	"brantel": 3,
	"saleno": 4,
	"saleno_coast": 4,
	"reed_marsh": 4,
	"arsel": 4,
	"arsel_library": 4,
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
