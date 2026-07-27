## C-8 검증 — M3 신규 3종 + 아종 4종의 스탯 데이터(.tres)가
## m3-monster-spec.md 수치(2장 스탯 산출표 · 3장 신규 블록 규격 · 7장 아종)와
## 정확히 일치하는지 확인한다. 수치가 기획서와 어긋나면 여기서 곧바로 잡힌다.
extends GutTest

const SPIDER := preload("res://data/monsters/forest_spider_stats.tres")
const SHADOW_SPIDER := preload("res://data/monsters/shadow_forest_spider_stats.tres")
const OUTLAW := preload("res://data/monsters/outlaw_stats.tres")
const HIGHWAYMAN := preload("res://data/monsters/highwayman_stats.tres")
const POACHER := preload("res://data/monsters/poacher_stats.tres")
const IMP := preload("res://data/monsters/imp_stats.tres")
const IMP_LORD := preload("res://data/monsters/imp_lord_stats.tres")

# --- 2장 스탯 산출표 (HP / 공격력 / 방어력) ---


func test_base_species_stats_match_spec_table() -> void:
	assert_eq(SPIDER.max_hp, 540.0, "숲거미 Lv10 HP")
	assert_eq(SPIDER.attack_power, 45.0, "숲거미 Lv10 공격력")
	assert_eq(SPIDER.defense, 5.0, "숲거미 방어력 0.5×10")
	assert_eq(OUTLAW.max_hp, 740.0, "무법자 Lv14 HP")
	assert_eq(OUTLAW.attack_power, 65.0, "무법자 Lv14 공격력")
	assert_eq(OUTLAW.defense, 7.0, "무법자 방어력 0.5×14")
	assert_eq(IMP.max_hp, 840.0, "임프 Lv16 HP")
	assert_eq(IMP.attack_power, 76.0, "임프 Lv16 공격력")
	assert_eq(IMP.defense, 8.0, "임프 방어력 0.5×16")


func test_base_species_are_normal_grade_not_boss_or_elite() -> void:
	for stats in [SPIDER, OUTLAW, IMP]:
		assert_false(stats.is_boss, "기본 3종은 잡몹 — 야간 배율(×1.2) 대상")
		assert_false(stats.is_elite, "기본 3종은 잡몹 — 경직 규칙 그대로")


func test_perception_leash_and_speeds_match_spec() -> void:
	assert_eq(SPIDER.perception_range_tiles, 6.0)
	assert_eq(SPIDER.leash_range_tiles, 8.0)
	assert_eq(SPIDER.wander_speed_tiles, 1.8)
	assert_eq(SPIDER.combat_move_speed_tiles, 3.6)
	assert_eq(OUTLAW.perception_range_tiles, 6.0)
	assert_eq(OUTLAW.leash_range_tiles, 10.0, "지성형이라 들개(8타일)보다 끈질긴 추격")
	assert_eq(OUTLAW.combat_move_speed_tiles, 4.0)
	assert_eq(IMP.perception_range_tiles, 5.0, "순간이동으로 거리를 좁히므로 인지는 짧게")
	assert_eq(IMP.leash_range_tiles, 8.0)
	assert_eq(IMP.wander_speed_tiles, 1.5)
	assert_eq(IMP.combat_move_speed_tiles, 3.4)


func test_pack_aggro_sharing_matches_spec() -> void:
	assert_false(SPIDER.shares_pack_aggro, "숲거미는 개별 급습(어그로 공유 없음)")
	assert_true(OUTLAW.shares_pack_aggro, "무법자는 소규모 대열(공격 토큰 2)")
	assert_true(IMP.shares_pack_aggro, "임프는 무리 스폰(포효 버프 대상 필요)")


# --- 3장 신규 블록 파라미터 ---


func test_leap_parameters_match_spec_3_1() -> void:
	assert_eq(SPIDER.leap_telegraph_sec, 0.5)
	assert_eq(SPIDER.leap_travel_sec, 0.35)
	assert_eq(SPIDER.leap_max_range_tiles, 4.0)
	assert_eq(SPIDER.leap_min_range_tiles, 1.0)
	assert_eq(SPIDER.leap_land_radius_tiles, 1.0)
	assert_eq(SPIDER.leap_active_sec, 0.15)
	assert_eq(SPIDER.leap_recovery_sec, 0.4)
	assert_eq(SPIDER.leap_damage_mult, 1.0)
	assert_eq(SPIDER.leap_cooldown_sec, 3.5)


func test_charge_parameters_match_spec_3_3() -> void:
	assert_eq(OUTLAW.charge_telegraph_sec, 0.6)
	assert_eq(OUTLAW.charge_speed_tiles, 8.0)
	assert_eq(OUTLAW.charge_distance_tiles, 6.0)
	assert_eq(OUTLAW.charge_min_distance_tiles, 2.0)
	assert_eq(OUTLAW.charge_recovery_sec, 0.5)
	assert_eq(OUTLAW.charge_wall_stun_sec, 0.8)
	assert_eq(OUTLAW.charge_damage_mult, 1.2)
	assert_eq(OUTLAW.charge_cooldown_sec, 4.0)


func test_guard_parameters_match_spec_3_4() -> void:
	assert_eq(OUTLAW.guard_enter_sec, 0.2)
	assert_eq(OUTLAW.guard_duration_sec, 1.5)
	assert_eq(OUTLAW.guard_frontal_arc_deg, 120.0, "정면 ±60°")
	assert_eq(OUTLAW.guard_damage_reduction_pct, 0.6)
	assert_eq(OUTLAW.guard_break_stun_sec, 1.0)
	assert_eq(OUTLAW.guard_recovery_sec, 0.4)
	assert_eq(OUTLAW.guard_cooldown_sec, 6.0)


func test_blink_parameters_match_spec_3_5() -> void:
	assert_eq(IMP.blink_telegraph_sec, 0.3)
	assert_eq(IMP.blink_max_range_tiles, 5.0)
	assert_eq(IMP.blink_trigger_distance_tiles, 3.0)
	assert_eq(IMP.blink_target_offset_tiles, 2.5)
	assert_eq(IMP.blink_recovery_sec, 0.3)
	assert_eq(IMP.blink_cooldown_sec, 4.5)


func test_roar_parameters_match_spec_3_6() -> void:
	assert_eq(IMP.roar_telegraph_sec, 0.5)
	assert_eq(IMP.roar_radius_tiles, 4.0)
	assert_eq(IMP.roar_atk_buff_pct, 0.15)
	assert_eq(IMP.roar_speed_buff_pct, 0.15)
	assert_eq(IMP.roar_buff_duration_sec, 6.0)
	assert_eq(IMP.roar_cooldown_sec, 12.0)
	assert_lt(IMP.roar_buff_duration_sec, IMP.roar_cooldown_sec, "가동률 50% — 상시 유지 불가")


func test_imp_melee_swing_reuses_m2_values() -> void:
	assert_eq(IMP.melee_range_tiles, 1.5)
	assert_eq(IMP.melee_telegraph_sec, 0.5)
	assert_eq(IMP.melee_active_sec, 0.12)
	assert_eq(IMP.melee_recovery_sec, 0.3)


# --- 7장 아종 4종 (기본종 대비 데이터 차이만) ---


func test_shadow_forest_spider_differs_only_in_web_duration() -> void:
	assert_eq(SHADOW_SPIDER.max_hp, SPIDER.max_hp, "야간 ×1.2는 런타임 배율 — 기본 데이터는 동일")
	assert_eq(SHADOW_SPIDER.attack_power, SPIDER.attack_power)
	assert_eq(SHADOW_SPIDER.web_slow_duration_sec, 3.0, "spec 7-1 거미줄 지속 2.0 → 3.0초")
	assert_eq(SHADOW_SPIDER.leap_telegraph_sec, SPIDER.leap_telegraph_sec)
	assert_eq(SHADOW_SPIDER.perception_range_tiles, SPIDER.perception_range_tiles)


func test_highwayman_is_level_20_with_faster_charge() -> void:
	assert_eq(HIGHWAYMAN.max_hp, 1030.0, "spec 7-2 Lv20 잡몹 앵커 HP")
	assert_eq(HIGHWAYMAN.attack_power, 100.0)
	assert_eq(HIGHWAYMAN.defense, 10.0, "0.5×20")
	assert_eq(HIGHWAYMAN.charge_cooldown_sec, 3.5, "돌진 쿨다운 4.0 → 3.5초")
	assert_eq(HIGHWAYMAN.guard_cooldown_sec, OUTLAW.guard_cooldown_sec, "가드는 원본과 동일")
	assert_false(HIGHWAYMAN.uses_ranged_attack, "돌진 유지")


func test_poacher_is_level_36_ranged_variant() -> void:
	assert_eq(POACHER.max_hp, 1720.0, "spec 7-3 Lv36 산출값")
	assert_eq(POACHER.attack_power, 224.0)
	assert_eq(POACHER.defense, 18.0, "0.5×36")
	assert_true(POACHER.uses_ranged_attack, "돌진 → 조준 사격 석궁 교체")
	assert_eq(POACHER.projectile_telegraph_sec, 0.7, "석궁 조준 예고 0.7초")
	assert_eq(POACHER.projectile_range_tiles, 6.0, "석궁 사거리 6타일")
	assert_eq(POACHER.projectile_speed_tiles, 6.0, "투사체 속도 6.0타일/초")
	assert_eq(POACHER.projectile_cooldown_sec, 3.5, "석궁 쿨다운 3.5초")
	assert_eq(POACHER.perception_range_tiles, 7.0, "원거리라 인지 범위 7타일")
	assert_eq(POACHER.guard_cooldown_sec, OUTLAW.guard_cooldown_sec, "가드는 유지")


func test_imp_lord_is_elite_with_boosted_roar() -> void:
	assert_true(IMP_LORD.is_elite, "정예 — 평시 슈퍼아머(combat.md 5-2)")
	assert_false(IMP_LORD.is_boss, "정예도 야간 배율 대상(보스만 제외)")
	assert_eq(IMP_LORD.max_hp, 840.0 * 6.0, "정예 HP ×6")
	assert_eq(IMP_LORD.attack_power, 114.0, "정예 공격력 ×1.5 (76×1.5)")
	assert_eq(IMP_LORD.defense, IMP.defense, "방어력에는 정예 배율 없음")
	assert_eq(IMP_LORD.roar_radius_tiles, 6.0, "spec 7-4 반경 4 → 6타일")
	assert_eq(IMP_LORD.roar_atk_buff_pct, 0.2, "공격력 버프 +20%")
	assert_eq(IMP_LORD.roar_speed_buff_pct, 0.2, "이속 버프 +20%")
	assert_eq(IMP_LORD.roar_cooldown_sec, IMP.roar_cooldown_sec, "쿨다운 12초는 원본 유지(가동률 50%)")
	assert_eq(IMP_LORD.blink_cooldown_sec, 6.0, "순간이동 쿨다운 4.5 → 6.0초")


func test_display_names_are_korean_spec_names() -> void:
	assert_eq(SPIDER.display_name, "숲거미")
	assert_eq(SHADOW_SPIDER.display_name, "그림자 숲거미")
	assert_eq(OUTLAW.display_name, "무법자")
	assert_eq(HIGHWAYMAN.display_name, "노상강도")
	assert_eq(POACHER.display_name, "밀렵꾼")
	assert_eq(IMP.display_name, "임프")
	assert_eq(IMP_LORD.display_name, "포효 임프장")
