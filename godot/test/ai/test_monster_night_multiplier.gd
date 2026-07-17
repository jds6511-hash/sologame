## G2-4 검증 — MonsterBase의 야간 스탯 배율(combat.md 2-3장 ×1.2, 보스 제외)이
## 공유 리소스(MonsterStatsData)를 오염시키지 않고 인스턴스별로만 적용·복구되는지 확인한다.
extends GutTest

var _stats: MonsterStatsData


func before_each() -> void:
	GameClock.reset()
	_stats = MonsterStatsData.new()
	_stats.max_hp = 100.0
	_stats.attack_power = 20.0


func after_each() -> void:
	GameClock.reset()


func _spawn_monster() -> MonsterBase:
	var monster := MonsterBase.new()
	monster.stats = _stats
	add_child_autofree(monster)
	return monster


# --- 스폰 시점 즉시 적용 (밤 중 스폰된 개체도 즉시 배율 반영) ---


func test_spawned_during_day_has_unmultiplied_stats() -> void:
	var monster := _spawn_monster()
	assert_eq(monster.hp, 100.0)
	assert_eq(monster.effective_attack_power(), 20.0)


func test_spawned_during_night_has_multiplied_stats_immediately() -> void:
	GameClock.advance_time(1200.0)  ## 밤 진입
	var monster := _spawn_monster()
	assert_eq(monster.hp, 120.0, "밤 중 스폰된 개체도 즉시 x1.2가 적용돼야 한다")
	assert_eq(monster.effective_attack_power(), 24.0)


func test_boss_flag_excludes_night_multiplier_even_when_spawned_at_night() -> void:
	_stats.is_boss = true
	GameClock.advance_time(1200.0)
	var monster := _spawn_monster()
	assert_eq(monster.hp, 100.0, "보스는 야간 배율 제외(combat.md 2-3 확정)")
	assert_eq(monster.effective_attack_power(), 20.0)


# --- 전환 시 적용/복구 (공유 리소스 오염 없이 인스턴스 hp만 재계산) ---


func test_night_started_multiplies_max_hp_preserving_hp_ratio() -> void:
	var monster := _spawn_monster()
	monster.hp = 50.0  ## 낮 최대 100 중 50%
	GameClock.advance_time(1200.0)  ## night_started 발신 → MonsterBase가 구독 중
	assert_eq(monster.hp, 60.0, "밤 전환 시 최대 HP가 120으로 늘어도 체력 비율(50%)은 유지")
	assert_eq(monster.effective_max_hp(), 120.0)
	assert_eq(_stats.max_hp, 100.0, "공유 리소스 원본은 절대 변형되지 않아야 한다")


func test_day_started_restores_original_max_hp_preserving_hp_ratio() -> void:
	GameClock.advance_time(1200.0)  ## 밤 상태에서 스폰
	var monster := _spawn_monster()
	monster.hp = 60.0  ## 밤 최대 120 중 50%
	GameClock.advance_time(600.0)  ## day_started 발신
	assert_true(GameClock.is_day)
	assert_eq(monster.hp, 50.0, "낮 복귀 시 최대 HP가 100으로 원복돼도 체력 비율(50%)은 유지")
	assert_eq(monster.effective_max_hp(), 100.0)
	assert_eq(_stats.max_hp, 100.0, "공유 리소스 원본은 절대 변형되지 않아야 한다")


func test_boss_ignores_night_started_transition() -> void:
	_stats.is_boss = true
	var monster := _spawn_monster()
	monster.hp = 100.0
	GameClock.advance_time(1200.0)  ## night_started 발신되지만 보스는 구독하지 않음
	assert_eq(monster.hp, 100.0)
	assert_eq(monster.effective_max_hp(), 100.0)


func test_dead_monster_does_not_react_to_night_transition() -> void:
	var monster := _spawn_monster()
	monster.take_damage(9999.0)
	assert_true(monster.is_dead())
	GameClock.advance_time(1200.0)  ## 사망 후 전환 — 오류 없이 무시돼야 함
	assert_eq(monster.hp, 0.0)
