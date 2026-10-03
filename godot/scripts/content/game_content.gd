extends RefCounted
# gdlint: disable=max-file-lines
## 자동 생성: tools/generate_chapter_content.py · 원본 godot/data/content/*.json
const CURRENT_REVISION := 8
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
	"pilgrimage_path": "res://scenes/world/novera_gate.tscn",
	"oranse": "res://scenes/world/novera_gate.tscn",
	"jaetgol_approach": "res://scenes/world/novera_gate.tscn",
	"jaetgol": "res://scenes/world/novera_gate.tscn",
	"suretgul": "res://scenes/world/novera_gate.tscn",
	"valkren": "res://scenes/world/novera_gate.tscn",
	"old_front": "res://scenes/world/novera_gate.tscn",
	"valkren_rift": "res://scenes/world/novera_gate.tscn",
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
	"pilgrimage_path": "res://scenes/world/product_world.tscn",
	"oranse": "res://scenes/world/product_world.tscn",
	"jaetgol_approach": "res://scenes/world/product_world.tscn",
	"jaetgol": "res://scenes/world/product_world.tscn",
	"suretgul": "res://scenes/world/product_world.tscn",
	"valkren": "res://scenes/world/product_world.tscn",
	"old_front": "res://scenes/world/product_world.tscn",
	"valkren_rift": "res://scenes/world/product_world.tscn",
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
	"pilgrimage_path": "성터 순례길",
	"oranse": "오란세 성역",
	"jaetgol_approach": "잿골 접근로",
	"jaetgol": "잿골 마을",
	"suretgul": "수렛골",
	"valkren": "발크렌",
	"old_front": "옛 전선",
	"valkren_rift": "균열 전장",
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
	"pilgrimage_path": Rect2(0, 0, 1792, 960),
	"oranse": Rect2(0, 0, 1280, 1024),
	"jaetgol_approach": Rect2(0, 0, 1664, 896),
	"jaetgol": Rect2(0, 0, 1408, 1152),
	"suretgul": Rect2(0, 0, 1536, 896),
	"valkren": Rect2(0, 0, 1536, 1024),
	"old_front": Rect2(0, 0, 1792, 1024),
	"valkren_rift": Rect2(0, 0, 1152, 896),
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
	"saleno_to_pilgrimage_path":
	[
		"saleno",
		"pilgrimage_path",
		Vector2(1424, 736),
		Vector2(176, 480),
		"pilgrimage_path_to_saleno",
	],
	"pilgrimage_path_to_saleno":
	[
		"pilgrimage_path",
		"saleno",
		Vector2(96, 480),
		Vector2(1344, 736),
		"saleno_to_pilgrimage_path",
	],
	"pilgrimage_path_to_oranse":
	[
		"pilgrimage_path",
		"oranse",
		Vector2(1680, 480),
		Vector2(176, 480),
		"oranse_to_pilgrimage_path",
	],
	"oranse_to_pilgrimage_path":
	[
		"oranse",
		"pilgrimage_path",
		Vector2(96, 480),
		Vector2(1600, 480),
		"pilgrimage_path_to_oranse",
	],
	"novera_outskirts_to_jaetgol_approach":
	[
		"novera_outskirts",
		"jaetgol_approach",
		Vector2(1168, 672),
		Vector2(176, 480),
		"jaetgol_approach_to_novera_outskirts",
	],
	"jaetgol_approach_to_novera_outskirts":
	[
		"jaetgol_approach",
		"novera_outskirts",
		Vector2(96, 480),
		Vector2(1088, 672),
		"novera_outskirts_to_jaetgol_approach",
	],
	"jaetgol_approach_to_jaetgol":
	[
		"jaetgol_approach",
		"jaetgol",
		Vector2(1552, 480),
		Vector2(176, 480),
		"jaetgol_to_jaetgol_approach",
	],
	"jaetgol_to_jaetgol_approach":
	[
		"jaetgol",
		"jaetgol_approach",
		Vector2(96, 480),
		Vector2(1472, 480),
		"jaetgol_approach_to_jaetgol",
	],
	"jaetgol_to_suretgul":
	["jaetgol", "suretgul", Vector2(1328, 768), Vector2(160, 704), "suretgul_to_jaetgol"],
	"suretgul_to_jaetgol":
	["suretgul", "jaetgol", Vector2(96, 704), Vector2(1264, 768), "jaetgol_to_suretgul"],
	"suretgul_to_valkren":
	["suretgul", "valkren", Vector2(1440, 448), Vector2(160, 640), "valkren_to_suretgul"],
	"valkren_to_suretgul":
	["valkren", "suretgul", Vector2(96, 640), Vector2(1376, 448), "suretgul_to_valkren"],
	"valkren_to_old_front":
	["valkren", "old_front", Vector2(768, 96), Vector2(896, 864), "old_front_to_valkren"],
	"old_front_to_valkren":
	[
		"old_front",
		"valkren",
		Vector2(896, 928),
		Vector2(768, 160),
		"valkren_to_old_front",
	],
	"old_front_to_valkren_rift":
	[
		"old_front",
		"valkren_rift",
		Vector2(1696, 448),
		Vector2(160, 448),
		"valkren_rift_to_old_front",
	],
	"valkren_rift_to_old_front":
	[
		"valkren_rift",
		"old_front",
		Vector2(96, 448),
		Vector2(1632, 448),
		"old_front_to_valkren_rift",
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
	"MQ-08-01": "res://data/quests/chapter_eight/mq_08_01.tres",
	"MQ-08-02": "res://data/quests/chapter_eight/mq_08_02.tres",
	"MQ-08-03": "res://data/quests/chapter_eight/mq_08_03.tres",
	"MQ-08-04": "res://data/quests/chapter_eight/mq_08_04.tres",
	"MQ-08-05": "res://data/quests/chapter_eight/mq_08_05.tres",
	"SQ-08-001": "res://data/quests/chapter_eight/sq_08_001.tres",
	"SQ-08-002": "res://data/quests/chapter_eight/sq_08_002.tres",
	"SQ-08-003": "res://data/quests/chapter_eight/sq_08_003.tres",
	"SQ-08-004": "res://data/quests/chapter_eight/sq_08_004.tres",
	"SQ-08-005": "res://data/quests/chapter_eight/sq_08_005.tres",
	"SQ-08-006": "res://data/quests/chapter_eight/sq_08_006.tres",
	"SQ-08-007": "res://data/quests/chapter_eight/sq_08_007.tres",
	"SQ-08-008": "res://data/quests/chapter_eight/sq_08_008.tres",
	"SQ-08-009": "res://data/quests/chapter_eight/sq_08_009.tres",
	"SQ-08-010": "res://data/quests/chapter_eight/sq_08_010.tres",
	"SQ-08-011": "res://data/quests/chapter_eight/sq_08_011.tres",
	"SQ-08-012": "res://data/quests/chapter_eight/sq_08_012.tres",
	"MQ-09-01": "res://data/quests/chapter_nine/mq_09_01.tres",
	"MQ-09-02": "res://data/quests/chapter_nine/mq_09_02.tres",
	"MQ-09-03": "res://data/quests/chapter_nine/mq_09_03.tres",
	"MQ-09-04": "res://data/quests/chapter_nine/mq_09_04.tres",
	"MQ-09-05": "res://data/quests/chapter_nine/mq_09_05.tres",
	"SQ-09-001": "res://data/quests/chapter_nine/sq_09_001.tres",
	"SQ-09-002": "res://data/quests/chapter_nine/sq_09_002.tres",
	"SQ-09-003": "res://data/quests/chapter_nine/sq_09_003.tres",
	"SQ-09-004": "res://data/quests/chapter_nine/sq_09_004.tres",
	"SQ-09-005": "res://data/quests/chapter_nine/sq_09_005.tres",
	"SQ-09-006": "res://data/quests/chapter_nine/sq_09_006.tres",
	"SQ-09-007": "res://data/quests/chapter_nine/sq_09_007.tres",
	"SQ-09-008": "res://data/quests/chapter_nine/sq_09_008.tres",
	"SQ-09-009": "res://data/quests/chapter_nine/sq_09_009.tres",
	"SQ-09-010": "res://data/quests/chapter_nine/sq_09_010.tres",
	"SQ-09-011": "res://data/quests/chapter_nine/sq_09_011.tres",
	"SQ-09-012": "res://data/quests/chapter_nine/sq_09_012.tres",
	"SQ-09-013": "res://data/quests/chapter_nine/sq_09_013.tres",
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
	"pilgrimage_steward": ["pilgrimage_path", Vector2(384, 432), "순례길 안내관"],
	"oranse_healer": ["oranse", Vector2(448, 432), "오란세 치유사"],
	"oranse_pilgrim": ["oranse", Vector2(832, 624), "성역 순례자"],
	"jaetgol_steward": ["jaetgol", Vector2(576, 432), "잿골 인계 담당관"],
	"valkren_commander": ["valkren", Vector2(768, 640), "발크렌 지휘관"],
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
	"pilgrimage_path": "MQ-08-01",
	"oranse": "MQ-08-01",
	"jaetgol_approach": "MQ-08-04",
	"jaetgol": "MQ-08-04",
	"suretgul": "MQ-08-05",
	"valkren": "MQ-08-05",
	"old_front": "MQ-09-01",
	"valkren_rift": "MQ-09-03",
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
	"barony_ledger":
	[Vector2(1088, 576), "barony_ledger_site", "INTERACT", "작위 심사 공헌 기록", "brantel"],
	"barony_petitions":
	[Vector2(1152, 752), "barony_petitions_site", "INTERACT", "민원 원본 대조", "brantel"],
	"barony_witness_request":
	[
		Vector2(624, 720),
		"barony_witness_request_site",
		"INTERACT",
		"증언 요청서 수령",
		"brantel",
	],
	"pilgrimage_passage":
	[
		Vector2(640, 400),
		"pilgrimage_passage_site",
		"INTERACT",
		"순례 통행 기록",
		"pilgrimage_path",
	],
	"pilgrimage_provisions":
	[
		Vector2(704, 720),
		"pilgrimage_provisions_site",
		"INTERACT",
		"순례 보급 물자 대조",
		"pilgrimage_path",
	],
	"pilgrimage_marker":
	[
		Vector2(1376, 672),
		"pilgrimage_marker_site",
		"INTERACT",
		"훼손된 순례 표식 복구",
		"pilgrimage_path",
	],
	"pilgrimage_safe_route":
	[
		Vector2(1456, 352),
		"pilgrimage_safe_route_site",
		"REACH",
		"낙석 우회 통로 확인",
		"pilgrimage_path",
	],
	"oranse_testimony":
	[Vector2(768, 320), "oranse_testimony_site", "INTERACT", "치유 기록과 증언 대조", "oranse"],
	"oranse_names":
	[Vector2(1056, 448), "oranse_names_site", "INTERACT", "순례 명부의 동명이인 확인", "oranse"],
	"barony_testimony_seal":
	[
		Vector2(1056, 336),
		"barony_testimony_seal_site",
		"INTERACT",
		"증언 서류 교차 확인",
		"brantel",
	],
	"barony_ceremony":
	[Vector2(640, 256), "barony_ceremony_site", "INTERACT", "남작 의식 서약 확인", "brantel"],
	"jaetgol_road":
	[
		Vector2(1280, 320),
		"jaetgol_road_site",
		"REACH",
		"잿골 통행로 확보 확인",
		"jaetgol_approach",
	],
	"jaetgol_handover":
	[Vector2(864, 320), "jaetgol_handover_site", "INTERACT", "새 영지 관리 인계서", "jaetgol"],
	"jaetgol_residents":
	[Vector2(1056, 576), "jaetgol_residents_site", "INTERACT", "주민 물자 요청 대조", "jaetgol"],
	"jaetgol_market_plan":
	[Vector2(864, 800), "jaetgol_market_plan_site", "INTERACT", "시장 예정지 점검", "jaetgol"],
	"jaetgol_workshop_plan":
	[Vector2(448, 864), "jaetgol_workshop_plan_site", "INTERACT", "공방 예정지 점검", "jaetgol"],
	"jaetgol_repair":
	[Vector2(1152, 928), "jaetgol_repair_site", "INTERACT", "복구 전후 생활길 확인", "jaetgol"],
	"pilgrimage_gargoyle_trace":
	[
		Vector2(1056, 272),
		"pilgrimage_gargoyle_trace_site",
		"INTERACT",
		"성벽 아래 오래된 강하 흔적 조사",
		"pilgrimage_path",
	],
	"suretgul_transport":
	[Vector2(512, 576), "suretgul_transport_site", "INTERACT", "수렛골 운송 기록", "suretgul"],
	"valkren_command":
	[Vector2(768, 736), "valkren_command_site", "REACH", "발크렌 지휘소 도착", "valkren"],
	"durim_barricade":
	[Vector2(768, 736), "durim_barricade_site", "INTERACT", "두림의 방벽 장치", "old_front"],
	"ilien_resonance":
	[Vector2(768, 640), "ilien_resonance_site", "INTERACT", "일리엔 감응 표식", "old_front"],
	"valkren_rift_arrival":
	[Vector2(192, 448), "valkren_rift_arrival_site", "REACH", "균열 전장 도착", "valkren_rift"],
	"zahel_testimony": [Vector2(944, 736), "zahel_testimony_site", "INTERACT", "자헬 증언", "valkren"],
	"valkren_evidence":
	[Vector2(832, 576), "valkren_evidence_site", "INTERACT", "현장 물증", "valkren_rift"],
	"ch9_axle_west": [Vector2(384, 320), "ch9_axle_west_site", "INTERACT", "운송 흔적 서쪽", "suretgul"],
	"ch9_axle_east": [Vector2(640, 320), "ch9_axle_east_site", "INTERACT", "운송 흔적 동쪽", "suretgul"],
	"ch9_shelter": [Vector2(384, 672), "ch9_shelter_site", "REACH", "대피소 확인", "suretgul"],
	"ch9_residents": [Vector2(448, 672), "ch9_residents_site", "INTERACT", "주민 명부", "suretgul"],
	"ch9_beacon_west": [Vector2(256, 192), "ch9_beacon_west_site", "INTERACT", "서쪽 봉화", "suretgul"],
	"ch9_beacon_east":
	[Vector2(1312, 192), "ch9_beacon_east_site", "INTERACT", "동쪽 봉화", "suretgul"],
	"ch9_bolt_west": [Vector2(256, 704), "ch9_bolt_west_site", "INTERACT", "서문 고정쇠", "valkren"],
	"ch9_bolt_north": [Vector2(864, 224), "ch9_bolt_north_site", "INTERACT", "북문 고정쇠", "valkren"],
	"ch9_infirmary": [Vector2(1200, 736), "ch9_infirmary_site", "REACH", "의무소 확인", "valkren"],
	"ch9_medicine": [Vector2(1264, 736), "ch9_medicine_site", "INTERACT", "의무소 보급 확인", "valkren"],
	"ch9_record_west":
	[Vector2(320, 544), "ch9_record_west_site", "INTERACT", "서쪽 전선 기록", "old_front"],
	"ch9_record_east":
	[Vector2(1312, 832), "ch9_record_east_site", "INTERACT", "동쪽 전선 기록", "old_front"],
	"ch9_return_west": [Vector2(256, 736), "ch9_return_west_site", "REACH", "서쪽 귀환로", "suretgul"],
	"ch9_return_east": [Vector2(1344, 512), "ch9_return_east_site", "REACH", "동쪽 귀환로", "suretgul"],
	"ch9_fragment_west":
	[Vector2(512, 704), "ch9_fragment_west_site", "INTERACT", "서쪽 물증", "valkren_rift"],
	"ch9_fragment_east":
	[Vector2(832, 704), "ch9_fragment_east_site", "INTERACT", "동쪽 물증", "valkren_rift"],
	"ch9_zahel_badge":
	[Vector2(1008, 736), "ch9_zahel_badge_site", "INTERACT", "자헬의 패 확인", "valkren"],
	"ch9_guild_record":
	[Vector2(944, 832), "ch9_guild_record_site", "INTERACT", "조합 기록", "valkren"],
	"ch9_civilian_ledger":
	[Vector2(576, 800), "ch9_civilian_ledger_site", "INTERACT", "민간 기록 대조", "valkren"],
	"ch9_army_ledger":
	[Vector2(704, 800), "ch9_army_ledger_site", "INTERACT", "군 기록 대조", "valkren"],
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
	"jaetgol_hounds":
	[
		"jaetgol_approach",
		[Vector2(704, 704), Vector2(928, 720), Vector2(1152, 672)],
		"outlaw",
		"rift_hound",
	],
	"jaetgol_gargoyles":
	[
		"jaetgol_approach",
		[Vector2(800, 192), Vector2(1056, 192), Vector2(1280, 192)],
		"forest_spider",
		"stone_gargoyle",
	],
	"suretgul_ogres":
	[
		"suretgul",
		[Vector2(800, 256), Vector2(1088, 256), Vector2(1248, 672)],
		"wolf",
		"ogre",
	],
	"old_front_scouts":
	[
		"old_front",
		[Vector2(480, 288), Vector2(640, 288), Vector2(480, 672)],
		"poacher",
		"demon_scout",
	],
	"old_front_wraiths":
	[
		"old_front",
		[Vector2(1280, 256), Vector2(1440, 256), Vector2(1408, 704)],
		"ruin_wraith",
		"ruin_wraith",
	],
}
const MARKER_CONTENT_IDS := {
	"yeoulmok_rabbit_habitat": "horned_rabbit",
	"yeoulmok_dog_habitat": "feral_dog",
}
const FIELD_REPORTS := {
	"SQ-CH05-001": true,
	"SQ-CH05-002": true,
	"SQ-CH05-003": true,
	"SQ-CH05-004": true,
	"SQ-CH05-005": true,
	"SQ-CH05-006": true,
	"SQ-CH05-007": true,
	"SQ-CH04-001": true,
	"SQ-CH04-002": true,
	"SQ-CH04-003": true,
	"SQ-CH04-004": true,
	"SQ-CH04-005": true,
	"SQ-07-001": true,
	"SQ-07-002": true,
	"SQ-07-003": true,
	"SQ-07-004": true,
	"SQ-07-005": true,
	"SQ-07-006": true,
	"SQ-07-007": true,
	"SQ-07-008": true,
	"SQ-07-009": true,
	"SQ-07-010": true,
	"SQ-07-011": true,
	"SQ-07-012": true,
	"SQ-07-013": true,
	"SQ-06-001": true,
	"SQ-06-002": true,
	"SQ-06-003": true,
	"SQ-06-004": true,
	"SQ-06-005": true,
	"SQ-06-006": true,
	"SQ-06-007": true,
	"SQ-06-008": true,
	"SQ-06-009": true,
	"SQ-06-010": true,
	"MQ-09-01": true,
	"MQ-09-02": true,
	"MQ-09-03": true,
	"MQ-09-04": true,
	"SQ-09-001": true,
	"SQ-09-002": true,
	"SQ-09-003": true,
	"SQ-09-004": true,
	"SQ-09-005": true,
	"SQ-09-006": true,
	"SQ-09-007": true,
	"SQ-09-008": true,
	"SQ-09-009": true,
	"SQ-09-010": true,
	"SQ-09-011": true,
	"SQ-09-012": true,
	"SQ-09-013": true,
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
	"barony_ledger": "공헌은 소모되지 않는다. 심사 자격과 남작 작위는 다르며, 최종 의식 보고 전까지 잿골은 하사되지 않는다.",
	"barony_petitions": "이름이 같은 두 민원을 접수 날짜와 거주지로 구분했다.",
	"barony_witness_request": "살레노에서 성터 순례길을 거쳐 오란세로 간다. 성역은 도보로 들어가며 전투와 세금이 없다.",
	"pilgrimage_passage": "통행인은 무장 유무가 아닌 순례 기록으로 확인한다.",
	"pilgrimage_provisions": "식량 꾸러미 수와 이동 인원을 대조했다. 남은 물자는 귀환 행렬 몫이다.",
	"pilgrimage_marker": "먼 길 안내 표식이 다시 오란세를 가리킨다.",
	"pilgrimage_safe_route": "낡은 성벽 아래 강하 흔적을 피해 열린 통로를 확인했다.",
	"oranse_testimony": "치유사의 진료 시각과 순례자의 통행 시각이 맞는다. 서로 다른 출처의 증언을 함께 기록했다.",
	"oranse_names": "같은 이름이지만 출발지와 동행자가 다르다. 섣불리 한 사람의 행적으로 합치지 않는다.",
	"barony_testimony_seal": "성역에서 정리한 증언을 문장원 기록과 맞췄다. 공헌 보상은 왕국의 보고에서 지급한다.",
	"barony_ceremony": "이 확인만으로 의식은 끝나지 않는다. 문장원 담당관에게 최종 보고하면 남작 작위와 잿골 하사가 함께 확정된다.",
	"jaetgol_road": "균열 사냥개의 돌진 흔적 너머로 주민의 수레길이 이어진다.",
	"jaetgol_handover": "관리 창구에서는 두 영지를 조회하고 무료 귀환 목적지를 고른다. 수령·건설·개발·주문 납품은 선택이며 인계의 필수 거래가 아니다.",
	"jaetgol_residents": "주민 명부와 창고 재고를 대조했다. 영지 시설에 돈을 쓰지 않아도 요청 조사를 마칠 수 있다.",
	"jaetgol_market_plan": "시장 예정지의 배수와 수레 진입 공간을 확인했다. 건설은 관리 창구에서 따로 선택한다.",
	"jaetgol_workshop_plan": "공방 예정지와 주민 우물을 구분했다. 점검은 유료 공방 건설을 요구하지 않는다.",
	"jaetgol_repair": "무너진 길의 잔해와 복구 표식을 비교했다. 주민의 일상 동선이 이어진다.",
	"pilgrimage_gargoyle_trace": "순례길에는 전투가 없다. 비어 있는 석상 받침과 오래된 강하 자국을 조사해 안전한 통행 구간을 기록한다.",
	"durim_barricade": "두림이 장치 뒤 안전 통로를 가리킨다. 안내 그림은 피해를 차단하는 물리 방벽이 아니다.",
	"ilien_resonance": "일리엔의 감응이 군후 돌진의 예고를 0.25초 앞서 전한다.",
	"zahel_testimony": "동료들의 보증으로 자헬에게 패가 발급됐다. 자헬은 자신이 본 침공 경로를 기록한다.",
	"valkren_evidence": "침공은 자연 발생이 아니었다. 남은 물증을 봉인한다. 가레스는 대열에서 이탈했다.",
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
	"pilgrimage_path":
	{
		"spawn": Vector2(176, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 27, 100, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(18, 8, 6, 44),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"oranse":
	{
		"spawn": Vector2(176, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 27, 68, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(36, 8, 6, 48),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"jaetgol_approach":
	{
		"spawn": Vector2(176, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 27, 92, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(18, 8, 6, 40),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"jaetgol":
	{
		"spawn": Vector2(176, 480),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 27, 76, 6),
				"tile": Vector2i(2, 0),
			},
			{
				"rect": Rect2(18, 8, 6, 56),
				"tile": Vector2i(2, 2),
			},
		],
	},
	"suretgul":
	{
		"spawn": Vector2(160, 704),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 26, 84, 6),
				"tile": Vector2i(2, 0),
			},
		],
	},
	"valkren":
	{
		"spawn": Vector2(160, 640),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 26, 84, 6),
				"tile": Vector2i(2, 0),
			},
		],
	},
	"old_front":
	{
		"spawn": Vector2(896, 864),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 26, 100, 6),
				"tile": Vector2i(2, 0),
			},
		],
	},
	"valkren_rift":
	{
		"spawn": Vector2(160, 448),
		"floor": Vector2i(0, 0),
		"patches":
		[
			{
				"rect": Rect2(6, 26, 60, 6),
				"tile": Vector2i(2, 0),
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
	"MQ-06-01":
	{
		"reputation": 2300,
	},
	"MQ-08-01":
	{
		"reputation": 5500,
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
	"stone_gargoyle":
	{
		"title": "석상 가고일",
		"scene": "forest_spider",
		"stats": "res://data/monsters/chapter_eight/stone_gargoyle.tres",
		"level": 52,
	},
	"rift_hound":
	{
		"title": "균열 사냥개",
		"scene": "outlaw",
		"stats": "res://data/monsters/chapter_eight/rift_hound.tres",
		"level": 56,
	},
	"demon_scout":
	{
		"title": "악마 척후",
		"scene": "poacher",
		"stats": "res://data/monsters/chapter_nine/demon_scout.tres",
		"level": 62,
	},
	"ogre":
	{
		"title": "오우거",
		"scene": "wolf",
		"stats": "res://data/monsters/chapter_nine/ogre.tres",
		"level": 65,
	},
	"ruin_wraith":
	{
		"title": "폐허 망령",
		"scene": "ruin_wraith",
		"stats": "res://data/monsters/chapter_nine/ruin_wraith.tres",
		"level": 66,
	},
	"warlord":
	{
		"title": "군후",
		"scene": "warlord",
		"stats": "res://data/monsters/warlord_stats.tres",
		"level": 68,
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
	"jaetgol": Vector2(320, 536),
	"valkren": Vector2(320, 640),
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
	"8":
	{
		"expected_kills": 120,
		"objective_kills": 8,
		"encounter_kills": 112,
		"budget": 1454758,
		"base_exp": 12123,
		"overlevel_factors": [1, 0.5, 0.25],
		"respawn_seconds": 90,
	},
	"9":
	{
		"expected_kills": 150,
		"objective_kills": 10,
		"encounter_kills": 140,
		"weighted_kills": 189,
		"budget": 2764294,
		"base_exp": 14626,
		"overlevel_factors": [1, 0.5, 0.25],
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
	"stone_gargoyle": "8",
	"rift_hound": "8",
	"demon_scout": "9",
	"ogre": "9",
	"ruin_wraith": "9",
	"warlord": "9",
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
const ENCOUNTERS := {
	"valkren_evac_west":
	{
		"kind": "evacuation",
		"region": "valkren",
		"quest_id": "MQ-09-02",
		"index": 0,
		"target": "valkren_evac_west",
		"position": Vector2(448, 448),
		"points": [Vector2(320, 320), Vector2(576, 320)],
		"title": "서쪽 대피 구역 확보",
		"scene": "poacher",
		"stats": "res://data/monsters/chapter_nine/demon_scout.tres",
		"content_id": "demon_scout",
		"max_active": 4,
		"duration": 8.0,
		"radius": 48.0,
		"outside_reset": 0.5,
		"hit_pause": 0.5,
	},
	"valkren_evac_east":
	{
		"kind": "evacuation",
		"region": "valkren",
		"quest_id": "MQ-09-02",
		"index": 1,
		"target": "valkren_evac_east",
		"position": Vector2(1088, 448),
		"points": [Vector2(960, 320), Vector2(1216, 320)],
		"title": "동쪽 대피 구역 확보",
		"scene": "poacher",
		"stats": "res://data/monsters/chapter_nine/demon_scout.tres",
		"content_id": "demon_scout",
		"max_active": 4,
		"duration": 8.0,
		"radius": 48.0,
		"outside_reset": 0.5,
		"hit_pause": 0.5,
	},
	"old_front_organized_scouts":
	{
		"kind": "wave",
		"region": "old_front",
		"quest_id": "MQ-09-03",
		"index": 2,
		"target": "demon_scout",
		"position": Vector2(768, 512),
		"points": [Vector2(960, 400), Vector2(1088, 512), Vector2(960, 624)],
		"title": "조직된 척후 저지",
		"scene": "poacher",
		"stats": "res://data/monsters/chapter_nine/demon_scout.tres",
		"content_id": "demon_scout",
		"max_active": 4,
	},
	"valkren_warlord":
	{
		"kind": "boss",
		"region": "valkren_rift",
		"quest_id": "MQ-09-04",
		"index": 1,
		"target": "warlord",
		"position": Vector2(256, 448),
		"points": [Vector2(640, 448)],
		"title": "군후 소집",
		"scene": "warlord",
		"stats": "res://data/monsters/warlord_stats.tres",
		"content_id": "warlord",
		"max_active": 4,
	},
}
const BOSS_PATTERNS := {
	"warlord":
	{
		"slash":
		{
			"radius": 64.0,
			"arc_degrees": 100.0,
			"telegraph": 0.9,
			"active": 0.12,
			"recovery": 0.9,
			"damage_multiplier": 1.0,
		},
		"dash":
		{
			"length": 160.0,
			"width": 24.0,
			"telegraph": 0.9,
			"support_bonus": 0.25,
			"speed": 160.0,
			"recovery": 1.1,
			"damage_multiplier": 1.2,
		},
		"shockwave":
		{
			"radius": 96.0,
			"telegraph": 1.2,
			"active": 0.12,
			"recovery": 1.2,
			"damage_multiplier": 1.25,
		},
		"transition_recovery": 0.8,
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
	"MQ-08-01": 7,
	"MQ-08-02": 7,
	"MQ-08-03": 7,
	"MQ-08-04": 7,
	"MQ-08-05": 7,
	"SQ-08-001": 7,
	"SQ-08-002": 7,
	"SQ-08-003": 7,
	"SQ-08-004": 7,
	"SQ-08-005": 7,
	"SQ-08-006": 7,
	"SQ-08-007": 7,
	"SQ-08-008": 7,
	"SQ-08-009": 7,
	"SQ-08-010": 7,
	"SQ-08-011": 7,
	"SQ-08-012": 7,
	"MQ-09-01": 8,
	"MQ-09-02": 8,
	"MQ-09-03": 8,
	"MQ-09-04": 8,
	"MQ-09-05": 8,
	"SQ-09-001": 8,
	"SQ-09-002": 8,
	"SQ-09-003": 8,
	"SQ-09-004": 8,
	"SQ-09-005": 8,
	"SQ-09-006": 8,
	"SQ-09-007": 8,
	"SQ-09-008": 8,
	"SQ-09-009": 8,
	"SQ-09-010": 8,
	"SQ-09-011": 8,
	"SQ-09-012": 8,
	"SQ-09-013": 8,
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
	"pilgrimage_path": 7,
	"oranse": 7,
	"jaetgol_approach": 7,
	"jaetgol": 7,
	"suretgul": 8,
	"valkren": 8,
	"old_front": 8,
	"valkren_rift": 8,
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
