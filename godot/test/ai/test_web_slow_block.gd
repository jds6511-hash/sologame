## C-8 검증 — 거미줄 둔화(m3-monster-spec.md 3-2장)가 신규 블록이 아니라 M2 AimFireBlock의
## 무피해 변형으로 성립하는지 확인한다: 조준 예고 0.6초 / 쿨다운 5.0초 / 직접 피해 0 /
## 명중 시 이동속도 −40% 2.0초(그림자 숲거미 아종은 3.0초).
extends GutTest

const SPIDER_STATS := preload("res://data/monsters/forest_spider_stats.tres")
const SHADOW_SPIDER_STATS := preload("res://data/monsters/shadow_forest_spider_stats.tres")


func test_aim_fire_block_configured_with_web_parameters() -> void:
	var web := AimFireBlock.new()
	web.telegraph_sec = SPIDER_STATS.web_telegraph_sec
	web.cooldown_sec = SPIDER_STATS.web_cooldown_sec
	watch_signals(web)
	web.start_aim()
	web.update(0.59)
	assert_signal_not_emitted(web, "fired", "조준 예고 0.6초 — 그 전에는 발사되지 않는다")
	web.update(0.02)
	assert_signal_emitted(web, "fired")
	web.update(4.9)
	assert_eq(web.phase, AimFireBlock.Phase.COOLDOWN, "쿨다운 5.0초 — 상시 둔화 방지")
	web.update(0.2)
	assert_eq(web.phase, AimFireBlock.Phase.IDLE)
	assert_signal_emitted(web, "cooldown_ended")


func test_web_deals_no_direct_damage() -> void:
	assert_eq(SPIDER_STATS.web_damage_mult, 0.0, "spec 3-2 무피해 원칙(위협은 둔화 2차 효과)")


func test_web_slow_parameters_match_spec() -> void:
	assert_eq(SPIDER_STATS.web_slow_pct, 0.4, "이동속도 −40%")
	assert_eq(SPIDER_STATS.web_slow_duration_sec, 2.0, "둔화 지속 2.0초")
	assert_eq(SPIDER_STATS.web_range_tiles, 4.0, "사거리 4타일")
	assert_eq(SPIDER_STATS.web_speed_tiles, 4.0, "투사체 속도 4.0타일/초")


func test_shadow_subspecies_only_changes_slow_duration() -> void:
	assert_eq(SHADOW_SPIDER_STATS.web_slow_duration_sec, 3.0, "spec 7-1 그림자 숲거미: 지속 3.0초")
	assert_eq(SHADOW_SPIDER_STATS.web_slow_pct, SPIDER_STATS.web_slow_pct, "둔화율은 원본과 동일")
	assert_eq(SHADOW_SPIDER_STATS.web_cooldown_sec, SPIDER_STATS.web_cooldown_sec, "쿨다운도 원본과 동일")
	assert_eq(
		SHADOW_SPIDER_STATS.leap_cooldown_sec,
		SPIDER_STATS.leap_cooldown_sec,
		"spec 7-1: 도약 쿨다운 강화는 G3-1 여분 레버로만 남기고 채택하지 않는다"
	)
