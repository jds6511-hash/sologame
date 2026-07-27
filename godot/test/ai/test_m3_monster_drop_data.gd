## C-8 검증 — M3 신규 3종 + 아종 4종의 드랍 테이블(DropTableData)이 m3-monster-spec.md
## 5장·7장 드랍 표와 일치하는지 확인한다. 골드·처치 경험치는 monster_level·tier에서
## 파생되므로(DropSystem.calc_gold / LevelCurveData.mob_exp) 그 파생값도 함께 검산한다.
extends GutTest

const SPIDER_DROP := preload("res://data/drops/forest_spider_drop_table.tres")
const SHADOW_SPIDER_DROP := preload("res://data/drops/shadow_forest_spider_drop_table.tres")
const OUTLAW_DROP := preload("res://data/drops/outlaw_drop_table.tres")
const HIGHWAYMAN_DROP := preload("res://data/drops/highwayman_drop_table.tres")
const POACHER_DROP := preload("res://data/drops/poacher_drop_table.tres")
const IMP_DROP := preload("res://data/drops/imp_drop_table.tres")
const IMP_LORD_DROP := preload("res://data/drops/imp_lord_drop_table.tres")

const LEVEL_CURVE := preload("res://data/progression/level_curve.tres")
const RATE_CONFIG := preload("res://data/items/drop_rate_config.tres")
# --- 5장·7장 드랍 테이블 (골드·EXP는 monster_level·tier에서 파생) ---


func test_drop_table_levels_and_tiers_match_spec() -> void:
	assert_eq(SPIDER_DROP.monster_level, 10)
	assert_eq(SHADOW_SPIDER_DROP.monster_level, 10, "야간 아종도 Lv10 (배율은 런타임)")
	assert_eq(OUTLAW_DROP.monster_level, 14)
	assert_eq(IMP_DROP.monster_level, 16)
	assert_eq(HIGHWAYMAN_DROP.monster_level, 20)
	assert_eq(POACHER_DROP.monster_level, 36)
	assert_eq(IMP_LORD_DROP.monster_level, 16)
	assert_eq(IMP_LORD_DROP.tier, DropTableData.MonsterTier.ELITE, "포효 임프장은 정예 드랍 컬럼")
	for table in [SPIDER_DROP, SHADOW_SPIDER_DROP, OUTLAW_DROP, IMP_DROP, HIGHWAYMAN_DROP]:
		assert_eq(table.tier, DropTableData.MonsterTier.NORMAL, "기본 3종·잡몹 아종은 일반 등급")


func test_drop_material_ids_match_spec() -> void:
	assert_eq(SPIDER_DROP.material_item_id, "MAT-SPIDER-SILK")
	assert_eq(SHADOW_SPIDER_DROP.material_item_id, "MAT-SPIDER-SILK", "spec 7-1: 원본 재료 재사용(신규 없음)")
	assert_eq(OUTLAW_DROP.material_item_id, "MAT-OUTLAW-MARK")
	assert_eq(IMP_DROP.material_item_id, "MAT-IMP-HORN")
	assert_eq(HIGHWAYMAN_DROP.material_item_id, "MAT-HIGHWAYMAN-BADGE", "spec 7-2 신규 재료")
	assert_eq(POACHER_DROP.material_item_id, "MAT-POACHER-PELT", "spec 7-3 신규 재료")
	assert_eq(IMP_LORD_DROP.material_item_id, "MAT-IMP-HORN", "spec 7-4: 원본 재료 재사용")


func test_potion_tier_follows_monster_level() -> void:
	assert_eq(SPIDER_DROP.potion_item_id, "POT-HP-1")
	assert_eq(OUTLAW_DROP.potion_item_id, "POT-HP-1")
	assert_eq(IMP_DROP.potion_item_id, "POT-HP-1")
	assert_eq(HIGHWAYMAN_DROP.potion_item_id, "POT-HP-1", "Lv20 < 30 → 여전히 1티어")
	assert_eq(POACHER_DROP.potion_item_id, "POT-HP-2", "Lv36 ≥ 30 → 2티어")


func test_core_break_exception_is_slime_only() -> void:
	for table in [SPIDER_DROP, OUTLAW_DROP, IMP_DROP, IMP_LORD_DROP]:
		assert_false(table.core_break_guarantees_material, "핵 파괴 기믹은 균열 점액 전용")


func test_gold_amounts_match_spec_drop_tables() -> void:
	assert_eq(
		DropSystem.calc_gold(SPIDER_DROP.monster_level, SPIDER_DROP.tier, RATE_CONFIG),
		63,
		"숲거미 g(10)=63골드"
	)
	assert_eq(
		DropSystem.calc_gold(OUTLAW_DROP.monster_level, OUTLAW_DROP.tier, RATE_CONFIG),
		105,
		"무법자 g(14)=105골드"
	)
	assert_eq(
		DropSystem.calc_gold(IMP_DROP.monster_level, IMP_DROP.tier, RATE_CONFIG),
		128,
		"임프 g(16)=128골드"
	)
	assert_eq(
		DropSystem.calc_gold(HIGHWAYMAN_DROP.monster_level, HIGHWAYMAN_DROP.tier, RATE_CONFIG),
		179,
		"노상강도 g(20)=179골드"
	)
	assert_eq(
		DropSystem.calc_gold(POACHER_DROP.monster_level, POACHER_DROP.tier, RATE_CONFIG),
		432,
		"밀렵꾼 g(36)=432골드"
	)
	assert_eq(
		DropSystem.calc_gold(IMP_LORD_DROP.monster_level, IMP_LORD_DROP.tier, RATE_CONFIG),
		768,
		"포효 임프장 = g(16)×6 정예 배율"
	)


func test_kill_exp_matches_spec() -> void:
	assert_eq(LEVEL_CURVE.mob_exp(SPIDER_DROP.monster_level), 158, "숲거미 EXP(10)=158")
	assert_eq(LEVEL_CURVE.mob_exp(OUTLAW_DROP.monster_level), 262, "무법자 EXP(14)=262")
	assert_eq(LEVEL_CURVE.mob_exp(IMP_DROP.monster_level), 320, "임프 EXP(16)=320")
	assert_eq(LEVEL_CURVE.mob_exp(HIGHWAYMAN_DROP.monster_level), 447, "노상강도 EXP(20)=447")
	assert_eq(LEVEL_CURVE.mob_exp(POACHER_DROP.monster_level), 1080, "밀렵꾼 EXP(36)=1080")
	assert_eq(
		roundi(LEVEL_CURVE.mob_exp(IMP_LORD_DROP.monster_level) * LEVEL_CURVE.elite_multiplier),
		1920,
		"포효 임프장 EXP = 320×6"
	)
