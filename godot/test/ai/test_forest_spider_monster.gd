## C-8 검증 — 숲거미(ForestSpiderMonster) 상태 전이가 m3-monster-spec.md 4-1장 상태
## 전이도대로 동작하는지 확인한다(배회 → 추적 → 거미줄/도약 → 귀환).
##
## 씬이 없는 단계이므로 M3MonsterTestRig로 필요한 자식 노드만 붙여 헤드리스로 검증한다.
extends GutTest

const STATS_PATH := "res://data/monsters/forest_spider_stats.tres"
const TILE := 16.0

var _spider: ForestSpiderMonster
var _target: Node2D


func before_each() -> void:
	GameClock.reset()
	_target = Node2D.new()
	add_child_autofree(_target)
	_target.global_position = Vector2(10000, 0)  ## 기본은 인지 범위 밖
	_spider = _spawn_spider()
	_spider.target = _target


func after_each() -> void:
	GameClock.reset()


func _spawn_spider(with_stagger: bool = false) -> ForestSpiderMonster:
	var spider := ForestSpiderMonster.new()
	spider.stats = load(STATS_PATH)
	M3MonsterTestRig.attach_attack_hitbox(spider)
	if with_stagger:
		M3MonsterTestRig.attach_stagger(spider, true)  ## 경량 체급(spec 4-1 넉백 체급)
	add_child_autofree(spider)
	spider.global_position = Vector2.ZERO
	spider.home_position = Vector2.ZERO
	return spider


func _place_target_at_tiles(tiles: float) -> void:
	_target.global_position = _spider.global_position + Vector2(tiles * TILE, 0.0)


# --- 배회 → 추적 ---


func test_initial_state_is_wander() -> void:
	assert_eq(_spider.state, ForestSpiderMonster.State.WANDER)


func test_enters_chase_when_target_within_perception_range() -> void:
	_place_target_at_tiles(5.0)  ## 인지 범위 6타일 이내
	_spider._physics_process(0.016)
	assert_eq(_spider.state, ForestSpiderMonster.State.CHASE)


func test_stays_wandering_outside_perception_range() -> void:
	_place_target_at_tiles(7.0)
	_spider._physics_process(0.016)
	assert_eq(_spider.state, ForestSpiderMonster.State.WANDER)


func test_take_damage_aggroes_without_pack_sharing() -> void:
	assert_false(_spider.stats.shares_pack_aggro, "spec 4-1: 어그로 공유 없는 개별 급습 개체")
	_spider.take_damage(10.0, "약", _target)
	assert_eq(_spider.state, ForestSpiderMonster.State.CHASE)


# --- 거미줄 둔화 (사거리 2~4타일) ---


func test_chase_starts_web_aim_within_web_range() -> void:
	_place_target_at_tiles(3.0)
	_spider._enter_chase(_target)
	_spider._physics_process(0.016)
	assert_eq(_spider.state, ForestSpiderMonster.State.WEB_AIM)


func test_web_is_not_used_closer_than_min_range() -> void:
	_place_target_at_tiles(1.5)  ## 최소 사거리 2타일 미만 — 거미줄 대신 도약
	_spider._enter_chase(_target)
	_spider._physics_process(0.016)
	assert_eq(_spider.state, ForestSpiderMonster.State.LEAP)


func test_web_fires_after_telegraph_and_enters_cooldown() -> void:
	watch_signals(_spider)
	_place_target_at_tiles(3.0)
	_spider._enter_chase(_target)
	_spider._physics_process(0.016)
	_spider._physics_process(0.6)
	assert_signal_emitted(_spider, "web_fired")
	assert_ne(_spider.state, ForestSpiderMonster.State.WEB_AIM, "발사 후 조준 상태를 벗어난다")
	assert_eq(_spider._web.phase, AimFireBlock.Phase.COOLDOWN, "쿨다운 5.0초 — 상시 둔화 방지")
	assert_eq(_spider.state, ForestSpiderMonster.State.LEAP, "spec 3-2 설계 의도: 거미줄 → 도약 2단 압박")


func test_web_hit_requests_slow_with_spec_parameters() -> void:
	watch_signals(_spider)
	_spider._on_web_projectile_hit(_target)
	assert_signal_emitted_with_parameters(_spider, "web_slow_applied", [_target, 0.4, 2.0])


# --- 도약 (예고 → 이동 → 착지 판정 → 후딜) ---


func test_leap_landing_point_is_clamped_to_max_range() -> void:
	_place_target_at_tiles(10.0)
	var land := _spider._resolve_land_point()
	assert_almost_eq(land.x, 4.0 * TILE, 0.01, "도약 최대 거리 4타일로 제한")


func test_leap_landing_point_is_clamped_to_min_range() -> void:
	_place_target_at_tiles(0.4)
	var land := _spider._resolve_land_point()
	assert_almost_eq(land.x, 1.0 * TILE, 0.01, "근거리에서는 '짧은 도약 물기' 최소 1타일")


func test_leap_cycle_opens_and_closes_landing_hitbox() -> void:
	watch_signals(_spider)
	_place_target_at_tiles(1.5)
	_spider._enter_chase(_target)
	_spider._physics_process(0.016)
	assert_eq(_spider.state, ForestSpiderMonster.State.LEAP)
	var hitbox: Area2D = _spider.get_node("AttackHitbox")
	assert_false(hitbox.monitoring, "예고 중에는 판정 없음")
	_spider._physics_process(0.5)  ## 예고 종료 → 공중 이동
	assert_false(hitbox.monitoring, "공중 이동 중에도 판정 없음")
	_spider._physics_process(0.35)  ## 이동 종료 → 착지 판정
	assert_true(hitbox.monitoring, "착지 순간에만 판정 활성")
	assert_signal_emitted(_spider, "leap_landed")
	_spider._physics_process(0.15)  ## 판정 종료
	assert_false(hitbox.monitoring, "판정 지속 0.15초 후 즉시 종료")
	_spider._physics_process(0.4)  ## 후딜 종료 → 추적 복귀
	assert_eq(_spider.state, ForestSpiderMonster.State.CHASE)


func test_leap_applies_damage_multiplier_only_during_landing() -> void:
	_place_target_at_tiles(1.5)
	_spider._enter_chase(_target)
	_spider._physics_process(0.016)
	_spider._physics_process(0.5)
	_spider._physics_process(0.35)
	assert_eq(_spider.current_attack_multiplier, 1.0, "spec 3-1 도약 데미지 계수 ×1.0")
	assert_eq(_spider.effective_attack_power(), 45.0, "Lv10 숲거미 공격력 45 × 계수 1.0")
	_spider._physics_process(0.15)
	assert_eq(_spider.current_attack_multiplier, 1.0)


func test_leap_hitbox_radius_uses_land_radius() -> void:
	var shape: CollisionShape2D = _spider.get_node("AttackHitbox/CollisionShape2D")
	var circle := shape.shape as CircleShape2D
	assert_not_null(circle, "도약 착지 판정용 원형 히트박스가 설정돼야 함")
	assert_almost_eq(circle.radius, 1.0 * TILE, 0.01, "착지 판정 반경 1.0타일")


func test_leap_is_cancelled_by_stagger() -> void:
	var spider := _spawn_spider(true)
	spider.target = _target
	_target.global_position = spider.global_position + Vector2(1.5 * TILE, 0.0)
	spider._enter_chase(_target)
	spider._physics_process(0.016)
	assert_eq(spider.state, ForestSpiderMonster.State.LEAP)
	spider.take_damage(10.0, "약", _target)  ## 예고 중 피격 → 경직
	spider._physics_process(0.016)
	assert_eq(spider.state, ForestSpiderMonster.State.CHASE, "spec 4-1: 예고 캔슬 = 딜찬스")
	var hitbox: Area2D = spider.get_node("AttackHitbox")
	assert_false(hitbox.monitoring, "캔슬된 도약은 착지 판정을 만들지 않는다")


# --- 귀환 (leash 8타일) ---


func test_chase_transitions_to_return_when_leash_exceeded() -> void:
	_spider._enter_chase(_target)
	_spider.global_position = Vector2(9.0 * TILE, 0.0)
	_target.global_position = _spider.global_position + Vector2(10000, 0)
	_spider._physics_process(0.016)
	assert_eq(_spider.state, ForestSpiderMonster.State.RETURN)


func test_return_restores_hp_and_goes_to_wander_on_arrival() -> void:
	_spider.hp = 1.0
	_spider.state = ForestSpiderMonster.State.RETURN
	_spider.global_position = Vector2(1.0, 0.0)  ## 도착 허용 오차 이내
	_spider._physics_process(0.016)
	assert_eq(_spider.state, ForestSpiderMonster.State.WANDER)
	assert_eq(_spider.hp, _spider.effective_max_hp(), "귀환 시 HP 완전 회복")
