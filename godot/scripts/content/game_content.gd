extends RefCounted
# gdlint: disable=max-file-lines
## 자동 생성: tools/generate_chapter_content.py · 원본 godot/data/content/*.json
const CURRENT_REVISION := 6
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
	"misran": "res://scenes/world/novera_gate.tscn",
	"forest_edge": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"mosswood": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"sylvien": "res://scenes/world/eastern_frontier_starting_area.tscn",
	"durgan": "res://scenes/world/novera_gate.tscn",
	"iron_mine": "res://scenes/world/novera_gate.tscn",
	"karndurum": "res://scenes/world/novera_gate.tscn",
	"frost_pass": "res://scenes/world/novera_gate.tscn",
	"durgan_training": "res://scenes/world/novera_gate.tscn",
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
	"misran": "res://scenes/world/product_world.tscn",
	"forest_edge": "res://scenes/world/product_world.tscn",
	"mosswood": "res://scenes/world/product_world.tscn",
	"sylvien": "res://scenes/world/product_world.tscn",
	"durgan": "res://scenes/world/product_world.tscn",
	"iron_mine": "res://scenes/world/product_world.tscn",
	"karndurum": "res://scenes/world/product_world.tscn",
	"frost_pass": "res://scenes/world/product_world.tscn",
	"durgan_training": "res://scenes/world/product_world.tscn",
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
	"misran": "미스란 교역구",
	"forest_edge": "숲가 마을길",
	"mosswood": "이끼내 수림길",
	"sylvien": "실비엔 조사구역",
	"durgan": "두르간 공방가",
	"iron_mine": "쇳골 갱도",
	"karndurum": "카른두름 교섭구역",
	"frost_pass": "서리재·하프나 보급로",
	"durgan_training": "두르간 훈련장",
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
	"misran": Rect2(0, 0, 1600, 1024),
	"forest_edge": Rect2(0, 0, 1792, 1152),
	"mosswood": Rect2(0, 0, 2112, 1344),
	"sylvien": Rect2(0, 0, 1920, 1280),
	"durgan": Rect2(0, 0, 1920, 1280),
	"iron_mine": Rect2(0, 0, 1920, 1280),
	"karndurum": Rect2(0, 0, 1920, 1280),
	"frost_pass": Rect2(0, 0, 1920, 1280),
	"durgan_training": Rect2(0, 0, 640, 480),
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
	"brantel_to_misran":
	["brantel", "misran", Vector2(1424, 736), Vector2(176, 512), "misran_to_brantel"],
	"misran_to_brantel":
	["misran", "brantel", Vector2(96, 512), Vector2(1344, 736), "brantel_to_misran"],
	"misran_to_forest_edge":
	[
		"misran",
		"forest_edge",
		Vector2(1488, 512),
		Vector2(176, 576),
		"forest_edge_to_misran",
	],
	"forest_edge_to_misran":
	[
		"forest_edge",
		"misran",
		Vector2(96, 576),
		Vector2(1408, 512),
		"misran_to_forest_edge",
	],
	"forest_edge_to_mosswood":
	[
		"forest_edge",
		"mosswood",
		Vector2(1680, 576),
		Vector2(176, 672),
		"mosswood_to_forest_edge",
	],
	"mosswood_to_forest_edge":
	[
		"mosswood",
		"forest_edge",
		Vector2(96, 672),
		Vector2(1600, 576),
		"forest_edge_to_mosswood",
	],
	"mosswood_to_sylvien":
	["mosswood", "sylvien", Vector2(2000, 672), Vector2(176, 640), "sylvien_to_mosswood"],
	"sylvien_to_mosswood":
	["sylvien", "mosswood", Vector2(96, 640), Vector2(1920, 672), "mosswood_to_sylvien"],
	"misran_to_durgan":
	["misran", "durgan", Vector2(1488, 512), Vector2(176, 640), "durgan_to_misran"],
	"durgan_to_misran":
	["durgan", "misran", Vector2(96, 640), Vector2(1408, 512), "misran_to_durgan"],
	"durgan_to_iron_mine":
	["durgan", "iron_mine", Vector2(1808, 640), Vector2(176, 640), "iron_mine_to_durgan"],
	"iron_mine_to_durgan":
	["iron_mine", "durgan", Vector2(96, 640), Vector2(1728, 640), "durgan_to_iron_mine"],
	"iron_mine_to_karndurum":
	[
		"iron_mine",
		"karndurum",
		Vector2(1808, 640),
		Vector2(176, 640),
		"karndurum_to_iron_mine",
	],
	"karndurum_to_iron_mine":
	[
		"karndurum",
		"iron_mine",
		Vector2(96, 640),
		Vector2(1728, 640),
		"iron_mine_to_karndurum",
	],
	"karndurum_to_frost_pass":
	[
		"karndurum",
		"frost_pass",
		Vector2(1808, 640),
		Vector2(176, 640),
		"frost_pass_to_karndurum",
	],
	"frost_pass_to_karndurum":
	[
		"frost_pass",
		"karndurum",
		Vector2(96, 640),
		Vector2(1728, 640),
		"karndurum_to_frost_pass",
	],
	"durgan_to_training":
	[
		"durgan",
		"durgan_training",
		Vector2(640, 352),
		Vector2(144, 384),
		"training_to_durgan",
	],
	"training_to_durgan":
	[
		"durgan_training",
		"durgan",
		Vector2(64, 384),
		Vector2(640, 432),
		"durgan_to_training",
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
	"MQ-06-01": "res://data/quests/chapter_six/mq_06_01.tres",
	"MQ-06-02": "res://data/quests/chapter_six/mq_06_02.tres",
	"MQ-06-03": "res://data/quests/chapter_six/mq_06_03.tres",
	"MQ-06-04": "res://data/quests/chapter_six/mq_06_04.tres",
	"MQ-06-05": "res://data/quests/chapter_six/mq_06_05.tres",
	"SQ-06-001": "res://data/quests/chapter_six/sq_06_001.tres",
	"SQ-06-002": "res://data/quests/chapter_six/sq_06_002.tres",
	"SQ-06-003": "res://data/quests/chapter_six/sq_06_003.tres",
	"SQ-06-004": "res://data/quests/chapter_six/sq_06_004.tres",
	"SQ-06-005": "res://data/quests/chapter_six/sq_06_005.tres",
	"SQ-06-006": "res://data/quests/chapter_six/sq_06_006.tres",
	"SQ-06-007": "res://data/quests/chapter_six/sq_06_007.tres",
	"SQ-06-008": "res://data/quests/chapter_six/sq_06_008.tres",
	"SQ-06-009": "res://data/quests/chapter_six/sq_06_009.tres",
	"SQ-06-010": "res://data/quests/chapter_six/sq_06_010.tres",
	"MQ-07-01": "res://data/quests/chapter_seven/mq_07_01.tres",
	"MQ-07-02": "res://data/quests/chapter_seven/mq_07_02.tres",
	"MQ-07-03": "res://data/quests/chapter_seven/mq_07_03.tres",
	"MQ-07-04": "res://data/quests/chapter_seven/mq_07_04.tres",
	"MQ-07-05": "res://data/quests/chapter_seven/mq_07_05.tres",
	"MQ-07-06": "res://data/quests/chapter_seven/mq_07_06.tres",
	"SQ-07-001": "res://data/quests/chapter_seven/sq_07_001.tres",
	"SQ-07-002": "res://data/quests/chapter_seven/sq_07_002.tres",
	"SQ-07-003": "res://data/quests/chapter_seven/sq_07_003.tres",
	"SQ-07-004": "res://data/quests/chapter_seven/sq_07_004.tres",
	"SQ-07-005": "res://data/quests/chapter_seven/sq_07_005.tres",
	"SQ-07-006": "res://data/quests/chapter_seven/sq_07_006.tres",
	"SQ-07-007": "res://data/quests/chapter_seven/sq_07_007.tres",
	"SQ-07-008": "res://data/quests/chapter_seven/sq_07_008.tres",
	"SQ-07-009": "res://data/quests/chapter_seven/sq_07_009.tres",
	"SQ-07-010": "res://data/quests/chapter_seven/sq_07_010.tres",
	"SQ-07-011": "res://data/quests/chapter_seven/sq_07_011.tres",
	"SQ-07-012": "res://data/quests/chapter_seven/sq_07_012.tres",
	"SQ-07-013": "res://data/quests/chapter_seven/sq_07_013.tres",
	"TR-WAR-02": "res://data/quests/job_trials/tr_war_02.tres",
	"TR-ARC-02": "res://data/quests/job_trials/tr_arc_02.tres",
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
	"misran_envoy": ["misran", Vector2(480, 464), "미스란 교역 사절"],
	"misran_healer": ["misran", Vector2(800, 592), "미스란 약초사"],
	"forest_keeper": ["forest_edge", Vector2(448, 528), "숲가 경계지기"],
	"forest_woodworker": ["forest_edge", Vector2(896, 640), "숲가 목공"],
	"mosswood_scout": ["mosswood", Vector2(448, 624), "이끼내 길잡이"],
	"illien": ["sylvien", Vector2(704, 592), "일리엔"],
	"sylvien_observer": ["sylvien", Vector2(1216, 704), "실비엔 조사원"],
	"durgan_foreman": ["durgan", Vector2(448, 592), "두르간 공방 감독"],
	"durgan_clerk": ["durgan", Vector2(1248, 704), "두르간 물자 서기"],
	"mine_surveyor": ["iron_mine", Vector2(448, 592), "쇳골 측량사"],
	"mine_worker": ["iron_mine", Vector2(1248, 704), "쇳골 광부"],
	"karndurum_envoy": ["karndurum", Vector2(448, 592), "카른두름 교섭관"],
	"rune_artisan": ["karndurum", Vector2(1248, 704), "룬 기술자"],
	"frost_quartermaster": ["frost_pass", Vector2(448, 592), "서리재 보급관"],
	"hafna_courier": ["frost_pass", Vector2(1248, 704), "하프나 연락원"],
	"durgan_trainer": ["durgan_training", Vector2(160, 320), "두르간 훈련 담당"],
}
const MERCHANTS := {
	"novera_gate": [Vector2(216, 440)],
	"novera_commons": [Vector2(416, 416)],
	"han_gilmok": [Vector2(240, 528)],
	"gransia": [Vector2(240, 528)],
	"brantel": [Vector2(240, 528)],
	"saleno": [Vector2(480, 528)],
	"arsel": [Vector2(448, 528)],
	"misran": [Vector2(608, 592)],
	"durgan": [Vector2(672, 704)],
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
	"misran": "MQ-05-05",
	"forest_edge": "MQ-06-01",
	"mosswood": "MQ-06-02",
	"sylvien": "MQ-06-03",
	"durgan": "MQ-06-05",
	"iron_mine": "MQ-07-01",
	"karndurum": "MQ-07-02",
	"frost_pass": "MQ-07-03",
	"durgan_training": "MQ-07-01",
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
	"misran_arrival": [Vector2(256, 512), "misran_arrival_site", "REACH", "미스란 교역구 도착", "misran"],
	"misran_request":
	[Vector2(1056, 352), "misran_request_site", "INTERACT", "협력 요청서 확인", "misran"],
	"misran_herbs": [Vector2(672, 688), "misran_herbs_site", "INTERACT", "약초 교역 목록", "misran"],
	"misran_supplies":
	[Vector2(1184, 688), "misran_supplies_site", "INTERACT", "조사 보급품 대조", "misran"],
	"forest_boundary":
	[Vector2(1136, 352), "forest_boundary_site", "INTERACT", "벌목 경계 표지", "forest_edge"],
	"forest_crossing":
	[Vector2(1456, 800), "forest_crossing_site", "INTERACT", "통행로 상태 조사", "forest_edge"],
	"forest_water": [Vector2(640, 800), "forest_water_site", "INTERACT", "숲가 수원 기록", "forest_edge"],
	"forest_tools": [Vector2(480, 352), "forest_tools_site", "INTERACT", "분실 연장 확인", "forest_edge"],
	"mosswood_resonance":
	[Vector2(1376, 352), "mosswood_resonance_site", "INTERACT", "감응 흔적 채록", "mosswood"],
	"mosswood_marker":
	[Vector2(1728, 992), "mosswood_marker_site", "INTERACT", "이끼내 길표식 복원", "mosswood"],
	"mosswood_sample":
	[Vector2(672, 992), "mosswood_sample_site", "INTERACT", "오염 표본 봉인", "mosswood"],
	"mosswood_water":
	[Vector2(1184, 992), "mosswood_water_site", "INTERACT", "수림 물길 대조", "mosswood"],
	"sylvien_resonance":
	[Vector2(960, 544), "sylvien_resonance_site", "INTERACT", "일리엔과 감응 조사", "sylvien"],
	"sylvien_seal": [Vector2(1472, 352), "sylvien_seal_site", "INTERACT", "군인 흔적 채록", "sylvien"],
	"sylvien_record":
	[Vector2(1056, 928), "sylvien_record_site", "INTERACT", "공동 관측 기록", "sylvien"],
	"sylvien_boundary":
	[Vector2(1504, 928), "sylvien_boundary_site", "INTERACT", "조사 경계 점검", "sylvien"],
	"sylvien_report":
	[Vector2(960, 736), "sylvien_report_site", "INTERACT", "공동 조사 보고서", "sylvien"],
	"durgan_arrival": [Vector2(256, 640), "durgan_arrival_site", "REACH", "두르간 조사단 도착", "durgan"],
	"durgan_brief": [Vector2(832, 352), "durgan_brief_site", "INTERACT", "광산 조사 요청 대조", "durgan"],
	"durgan_manifest":
	[Vector2(1152, 352), "durgan_manifest_site", "INTERACT", "공방 물자 명세 확인", "durgan"],
	"durgan_tools": [Vector2(1152, 864), "durgan_tools_site", "INTERACT", "광부 연장 묶음 인수", "durgan"],
	"mine_support": [Vector2(800, 352), "mine_support_site", "INTERACT", "무너진 지지대 점검", "iron_mine"],
	"mine_route": [Vector2(1440, 352), "mine_route_site", "REACH", "우회 갱도 출구 탐사", "iron_mine"],
	"mine_ore": [Vector2(1440, 928), "mine_ore_site", "INTERACT", "광맥 표본 대조", "iron_mine"],
	"mine_lamp": [Vector2(800, 928), "mine_lamp_site", "INTERACT", "갱도 표지등 복구", "iron_mine"],
	"karndurum_terms":
	[
		Vector2(832, 352),
		"karndurum_terms_site",
		"INTERACT",
		"광산 공동 이용 조건 대조",
		"karndurum",
	],
	"karndurum_rune":
	[Vector2(1440, 352), "karndurum_rune_site", "INTERACT", "룬 장치의 균열 기록", "karndurum"],
	"karndurum_water":
	[Vector2(832, 928), "karndurum_water_site", "INTERACT", "공방 냉각 수로 점검", "karndurum"],
	"karndurum_seal":
	[Vector2(1440, 928), "karndurum_seal_site", "INTERACT", "기술 공유 문서 봉인", "karndurum"],
	"frost_cache":
	[Vector2(800, 352), "frost_cache_site", "INTERACT", "눈에 묻힌 보급함 확인", "frost_pass"],
	"frost_beacon":
	[Vector2(1440, 352), "frost_beacon_site", "INTERACT", "서리재 신호대 복구", "frost_pass"],
	"frost_arrival":
	[Vector2(1440, 928), "frost_arrival_site", "REACH", "하프나 연락 거점 도착", "frost_pass"],
	"frost_dispatch":
	[Vector2(800, 928), "frost_dispatch_site", "INTERACT", "보급로 재개 전령 기록", "frost_pass"],
	"durgan_treaty":
	[Vector2(1440, 928), "durgan_treaty_site", "INTERACT", "상호 협력 조약 기록", "durgan"],
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
	"forest_vines":
	[
		"forest_edge",
		[Vector2(704, 384), Vector2(928, 368), Vector2(1248, 400)],
		"wolf",
		"thorn_vine",
	],
	"mosswood_mushrooms":
	[
		"mosswood",
		[Vector2(640, 384), Vector2(1152, 368), Vector2(1472, 400)],
		"rift_slime",
		"poison_mushroom",
	],
	"mosswood_panthers":
	[
		"mosswood",
		[Vector2(544, 928), Vector2(1376, 944), Vector2(1664, 912)],
		"outlaw",
		"forest_panther",
	],
	"sylvien_treants":
	[
		"sylvien",
		[Vector2(576, 368), Vector2(1152, 384), Vector2(1472, 416)],
		"wolf",
		"corrupted_treant",
	],
	"mine_bats":
	[
		"iron_mine",
		[Vector2(1024, 464), Vector2(1136, 464), Vector2(1248, 464)],
		"forest_spider",
		"cave_bat",
	],
	"mine_kobolds":
	[
		"iron_mine",
		[Vector2(1024, 800), Vector2(1136, 800), Vector2(1248, 800)],
		"outlaw",
		"kobold_miner",
	],
	"rune_golems":
	[
		"karndurum",
		[Vector2(1024, 464), Vector2(1136, 464), Vector2(1248, 464)],
		"wolf",
		"rock_golem",
	],
	"pass_wolves":
	[
		"frost_pass",
		[Vector2(1024, 800), Vector2(1136, 800), Vector2(1248, 800)],
		"wolf",
		"frost_wolf",
	],
	"pass_spirits":
	[
		"frost_pass",
		[Vector2(1024, 464), Vector2(1136, 464), Vector2(1248, 464)],
		"rift_slime",
		"ice_spirit",
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
	"misran_request": "숲의 감응 조사는 경계 주민과 엘프 조사자의 동의 아래 진행한다.",
	"forest_boundary": "경계 너머의 벌목은 멈추었다. 훼손된 표지는 주민과 조사자가 함께 다시 세운다.",
	"sylvien_resonance": "일리엔이 감응을 읽는 동안 주변의 진동을 기록한다. 조사자는 같은 흔적이 이어지는 방향을 표시한다.",
	"sylvien_seal": "일리엔은 마수 무리 뒤에 군인을 지닌 지성체의 개입이 있음을 확인한다. 확인된 관측만 공동 보고서에 남긴다.",
	"sylvien_report": "일리엔은 앞으로도 감응 조사에 협력하기로 한다. 미스란과 실비엔은 확인된 관측을 함께 보관한다.",
	"mine_support": "지지대가 내려앉아 수레길이 막혔다. 측량사는 동쪽의 오래된 갱도를 우회로로 제시한다.",
	"karndurum_terms": "교섭관은 광석의 일방 반출 대신 공구와 식량의 정기 공급을 요구한다. 공동 조사 기록을 바탕으로 조건을 맞춘다.",
	"frost_beacon": "눈보라에 끊겼던 신호가 하프나 쪽 봉우리에서 응답한다. 보급대가 움직일 길이 다시 이어졌다.",
	"durgan_treaty": "광산 안전 조사와 룬 기술 교류, 서리재 보급 협력을 하나의 조약에 남긴다.",
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
	"misran":
	{
		"spawn": Vector2(176, 512),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(18, 8, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(65, 8, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(18, 48, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(65, 48, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(4, 28, 92, 8),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(47, 5, 6, 54),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(8, 19, 84, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(8, 39, 84, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(36, 23, 28, 18),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"forest_edge":
	{
		"spawn": Vector2(176, 576),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(18, 8, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(77, 8, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(18, 56, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(77, 56, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(4, 32, 104, 8),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(53, 5, 6, 62),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(8, 19, 96, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(8, 47, 96, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(43, 8, 20, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(43, 56, 20, 8),
				"tile": Vector2i(1, 2),
			},
		],
	},
	"mosswood":
	{
		"spawn": Vector2(176, 672),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(18, 8, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(97, 8, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(18, 68, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(97, 68, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(4, 38, 124, 8),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(63, 5, 6, 74),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(8, 19, 116, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(8, 59, 116, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(50, 7, 4, 16),
				"tile": Vector2i(1, 1),
			},
			{
				"rect": Rect2(50, 60, 4, 17),
				"tile": Vector2i(1, 1),
			},
		],
	},
	"sylvien":
	{
		"spawn": Vector2(176, 640),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(18, 8, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(85, 8, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(18, 64, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(85, 64, 16, 8),
				"tile": Vector2i(1, 2),
			},
			{
				"rect": Rect2(4, 36, 112, 8),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(57, 5, 6, 70),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(8, 19, 104, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(8, 55, 104, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(49, 29, 22, 22),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"durgan_training":
	{
		"floor": Vector2i(2, 2),
		"spawn": Vector2(144, 384),
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
	"MQ-04-01":
	{
		"reputation": 800,
	},
	"MQ-05-01":
	{
		"reputation": 1400,
	},
	"MQ-06-01":
	{
		"reputation": 2300,
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
	"thorn_vine":
	{
		"title": "가시덩굴",
		"scene": "wolf",
		"stats": "res://data/monsters/chapter_six/thorn_vine.tres",
		"level": 31,
	},
	"poison_mushroom":
	{
		"title": "독버섯 마수",
		"scene": "rift_slime",
		"stats": "res://data/monsters/chapter_six/poison_mushroom.tres",
		"level": 33,
	},
	"forest_panther":
	{
		"title": "수림 표범",
		"scene": "outlaw",
		"stats": "res://data/monsters/chapter_six/forest_panther.tres",
		"level": 35,
	},
	"corrupted_treant":
	{
		"title": "오염 트렌트",
		"scene": "wolf",
		"stats": "res://data/monsters/chapter_six/corrupted_treant.tres",
		"level": 38,
	},
	"cave_bat":
	{
		"title": "동굴 박쥐",
		"scene": "forest_spider",
		"stats": "res://data/monsters/chapter_seven/cave_bat.tres",
		"level": 40,
	},
	"kobold_miner":
	{
		"title": "코볼트 광부",
		"scene": "outlaw",
		"stats": "res://data/monsters/chapter_seven/kobold_miner.tres",
		"level": 42,
	},
	"rock_golem":
	{
		"title": "바위 골렘",
		"scene": "wolf",
		"stats": "res://data/monsters/chapter_seven/rock_golem.tres",
		"level": 44,
	},
	"frost_wolf":
	{
		"title": "서리 늑대",
		"scene": "wolf",
		"stats": "res://data/monsters/chapter_seven/frost_wolf.tres",
		"level": 46,
	},
	"ice_spirit":
	{
		"title": "얼음 정령",
		"scene": "rift_slime",
		"stats": "res://data/monsters/chapter_seven/ice_spirit.tres",
		"level": 48,
	},
}
const WARP_ARRIVALS := {
	"novera_commons": Vector2(128, 384),
	"eastern_frontier_start": Vector2(152, 504),
	"gransia": Vector2(192, 480),
	"brantel": Vector2(192, 480),
	"saleno": Vector2(176, 480),
	"arsel": Vector2(176, 480),
	"misran": Vector2(176, 512),
	"durgan": Vector2(176, 640),
}
const EXP_PROFILES := {
	"4":
	{
		"expected_kills": 45,
		"objective_kills": 15,
		"encounter_kills": 30,
		"budget": 85008,
		"base_exp": 1889,
		"overlevel_factors": [1.0, 0.5, 0.25],
		"respawn_seconds": 90,
	},
	"5":
	{
		"expected_kills": 60,
		"objective_kills": 15,
		"encounter_kills": 45,
		"budget": 175998,
		"base_exp": 2933,
		"overlevel_factors": [1.0, 0.5, 0.25],
		"respawn_seconds": 90,
	},
	"6":
	{
		"expected_kills": 80,
		"objective_kills": 24,
		"encounter_kills": 56,
		"budget": 404719,
		"base_exp": 5059,
		"overlevel_factors": [1.0, 0.5, 0.25],
		"respawn_seconds": 90,
	},
	"7":
	{
		"expected_kills": 100,
		"objective_kills": 12,
		"encounter_kills": 88,
		"budget": 941354,
		"base_exp": 9414,
		"overlevel_factors": [1.0, 0.5, 0.25],
		"respawn_seconds": 90,
	},
}
const MONSTER_EXP_PROFILES := {
	"wild_boar": "4",
	"cursed_scarecrow": "4",
	"cliff_harpy": "4",
	"tidal_crab": "5",
	"marsh_lizard": "5",
	"water_mist": "5",
	"thorn_vine": "6",
	"poison_mushroom": "6",
	"forest_panther": "6",
	"corrupted_treant": "6",
	"cave_bat": "7",
	"kobold_miner": "7",
	"rock_golem": "7",
	"frost_wolf": "7",
	"ice_spirit": "7",
}
const TRIAL_TARGETS := {
	"trial_war_heavy":
	{
		"quest_id": "TR-WAR-02",
		"index": 0,
		"target": "trial_target",
		"region": "durgan_training",
	},
	"trial_war_guard":
	{
		"quest_id": "TR-WAR-02",
		"index": 1,
		"target": "trial_target",
		"region": "durgan_training",
	},
	"trial_arc_near":
	{
		"quest_id": "TR-ARC-02",
		"index": 0,
		"target": "trial_target",
		"region": "durgan_training",
	},
	"trial_arc_far":
	{
		"quest_id": "TR-ARC-02",
		"index": 1,
		"target": "trial_target",
		"region": "durgan_training",
	},
	"trial_arc_moving":
	{
		"quest_id": "TR-ARC-02",
		"index": 2,
		"target": "trial_target",
		"region": "durgan_training",
	},
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
	"MQ-06-01": 5,
	"MQ-06-02": 5,
	"MQ-06-03": 5,
	"MQ-06-04": 5,
	"MQ-06-05": 5,
	"SQ-06-001": 5,
	"SQ-06-002": 5,
	"SQ-06-003": 5,
	"SQ-06-004": 5,
	"SQ-06-005": 5,
	"SQ-06-006": 5,
	"SQ-06-007": 5,
	"SQ-06-008": 5,
	"SQ-06-009": 5,
	"SQ-06-010": 5,
	"MQ-07-01": 6,
	"MQ-07-02": 6,
	"MQ-07-03": 6,
	"MQ-07-04": 6,
	"MQ-07-05": 6,
	"MQ-07-06": 6,
	"SQ-07-001": 6,
	"SQ-07-002": 6,
	"SQ-07-003": 6,
	"SQ-07-004": 6,
	"SQ-07-005": 6,
	"SQ-07-006": 6,
	"SQ-07-007": 6,
	"SQ-07-008": 6,
	"SQ-07-009": 6,
	"SQ-07-010": 6,
	"SQ-07-011": 6,
	"SQ-07-012": 6,
	"SQ-07-013": 6,
	"TR-WAR-02": 6,
	"TR-ARC-02": 6,
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
	"misran": 5,
	"forest_edge": 5,
	"mosswood": 5,
	"sylvien": 5,
	"durgan": 6,
	"iron_mine": 6,
	"karndurum": 6,
	"frost_pass": 6,
	"durgan_training": 6,
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
