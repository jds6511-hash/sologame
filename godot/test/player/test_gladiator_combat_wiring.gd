## M3 C-1 검증 ③ — 실제 player.tscn에 검투사 로드아웃이 적용된 상태의 전투 배선
## (m3-warrior-tier2-skills.md 2-3·4-4장).
##
## 우클릭 격노 파생(분노 ≥ 50 → 차지 강타 대신 처형 일격), 격노 데미지 배율, 처형 보너스
## 판정, 피격으로 인한 충전, 그리고 **피격 예산 불변**(격노는 받는 피해를 줄이지 않는다)을
## 확인한다. 게이지 규칙 자체는 test_gladiator_rage_gauge.gd, .tres 규격은
## test_gladiator_skills.gd가 담당한다.
extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const WHIRLWIND: WarriorSkillData = preload(
	"res://data/player/skills/gladiator/skill_slot4_whirlwind.tres"
)
const CHARGED_SMASH: WarriorSkillData = preload(
	"res://data/player/skills/skill_secondary_charged_smash.tres"
)
## 처형 일격은 발동 시 damage_coefficient를 덮어쓰므로 const preload로 잡지 않는다
## (상수로 참조된 리소스는 read-only가 되어 그 쓰기가 무시된다).
const EXECUTION_PATH := "res://data/player/skills/gladiator/skill_secondary_execution.tres"

const TOL := 0.0001

var _execution: GladiatorSkillData = load(EXECUTION_PATH)


## MonsterBase의 처형 보너스 판정 계약(hp + effective_max_hp() + stats.is_boss)만 모사한 더미.
class DummyExecuteTarget:
	extends Node2D
	var hp: float = 100.0
	var stats: MonsterStatsData = null

	func effective_max_hp() -> float:
		return stats.max_hp if stats != null else 100.0

	func take_damage(_amount: float, _grade: String = "약", _attacker: Node2D = null) -> void:
		pass


# --- 분노 게이지 활성 조건 ---


func test_gladiator_loadout_activates_rage_gauge() -> void:
	var player := _spawn_gladiator()
	assert_true(player.rage.is_active(), "검투사 로드아웃 = 분노 게이지 활성")
	assert_eq(player.rage.finisher, _execution, "격노 파생 = 처형 일격")
	assert_eq(player.skill_charge, CHARGED_SMASH, "우클릭 기본은 차지 강타 유지")


func test_adventurer_start_has_no_rage_gauge() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	assert_false(player.rage.is_active(), "모험가/전사/궁수는 분노 게이지 미사용")
	assert_almost_eq(player.get_attack_power_multiplier(), 1.0, TOL, "데미지 배율 1.0")


# --- 우클릭 격노 파생 (처형 일격 발동) ---


func test_finisher_use_consumes_rage_and_writes_coefficient() -> void:
	var player := _spawn_gladiator()
	for _i in 25:
		player.rage.add_from_hit_taken()  ## 만땅
	assert_almost_eq(player.rage.current_rage, 100.0, TOL)
	assert_true(player._use_rage_finisher(), "만땅에서 처형 일격 발동")
	assert_almost_eq(_execution.damage_coefficient, 5.0, TOL, "만땅 소모 = 계수 5.0")
	assert_eq(player.rage.current_rage, 0.0, "전량 소모")
	assert_eq(player.skill_state, PlayerController.AttackState.STARTUP, "선딜부터 시전")
	assert_eq(player.active_skill, _execution)


func test_finisher_at_minimum_uses_floor_coefficient() -> void:
	var player := _spawn_gladiator()
	player.rage.current_rage = 50.0
	assert_true(player._use_rage_finisher(), "하한(50)에서 발동")
	assert_almost_eq(_execution.damage_coefficient, 3.5, TOL, "50 소모 = 계수 3.5")


func test_finisher_rejected_below_threshold() -> void:
	var player := _spawn_gladiator()
	player.rage.add_from_hit_taken()  ## 12 — 하한 50 미달
	assert_false(player._use_rage_finisher(), "하한 미달 시 발동 거부")
	assert_eq(player.skill_state, PlayerController.AttackState.NONE, "시전되지 않는다")
	assert_almost_eq(player.rage.current_rage, 12.0, TOL, "거부 시 게이지 불변")


func test_finisher_costs_no_mp() -> void:
	var player := _spawn_gladiator()
	var stats: PlayerStatsComponent = player.get_node("PlayerStats")
	var mp_before := stats.current_mp
	player.rage.current_rage = 100.0
	assert_true(player._use_rage_finisher())
	assert_almost_eq(stats.current_mp, mp_before, TOL, "처형 일격은 MP를 쓰지 않는다")


func test_finisher_grants_superarmor_during_cast() -> void:
	var player := _spawn_gladiator()
	player.rage.current_rage = 100.0
	assert_true(player._use_rage_finisher())
	player._update_superarmor_state(0.0)
	assert_true(player.is_superarmor(), "선딜~판정 구간 슈퍼아머")


# --- 격노 데미지 배율 · 피격 예산 ---


func test_taking_damage_charges_rage() -> void:
	var player := _spawn_gladiator()
	player.take_damage(10.0)
	assert_almost_eq(player.rage.current_rage, 12.0, TOL, "피격 시 +12 충전")


func test_enrage_multiplies_damage_but_not_defense() -> void:
	## 2-3장 — 격노는 공격 강화뿐이며 받는 피해를 줄이지 않는다.
	var player := _spawn_gladiator()
	var stats: PlayerStatsComponent = player.get_node("PlayerStats")
	var defense_before := player.get_combat_defense()
	var max_hp_before := stats.stats.max_hp
	player.rage.current_rage = 84.0
	player.rage._refresh_enrage()
	assert_true(player.rage.is_enraged())
	assert_almost_eq(player.get_attack_power_multiplier(), 1.12, TOL, "공격 배율 +12%")
	assert_almost_eq(player.get_combat_defense(), defense_before, TOL, "방어력 불변")
	assert_almost_eq(stats.stats.max_hp, max_hp_before, TOL, "최대 HP 불변")


func test_hit_budget_unchanged_by_enrage() -> void:
	## 잡몹 10대/보스 4대 예산은 몬스터 공격력·플레이어 HP/방어로만 결정된다 — 격노 중에도
	## 같은 피해를 받으므로 허용 피격 수가 변하지 않는다(5-1 피격 예산 불변).
	var player := _spawn_gladiator()
	var stats: PlayerStatsComponent = player.get_node("PlayerStats")
	var damage_per_hit := 13.0
	stats.take_damage(damage_per_hit)
	var normal_loss: float = stats.stats.max_hp - stats.current_hp
	stats.heal(stats.stats.max_hp)
	player.rage.current_rage = 84.0
	player.rage._refresh_enrage()
	assert_true(player.rage.is_enraged())
	stats.take_damage(damage_per_hit)
	var enraged_loss: float = stats.stats.max_hp - stats.current_hp
	assert_almost_eq(enraged_loss, normal_loss, TOL, "격노 중 피격 손실 동일 = 피격 예산 불변")


# --- 처형 보너스 (리졸버 판정) ---


func test_execute_bonus_applies_below_hp_threshold() -> void:
	var resolver := _spawn_resolver()
	var target := _make_target(0.20, false)  ## HP 20% — 처형 사거리
	assert_almost_eq(resolver._execute_multiplier(_execution, target), 1.5, TOL, "잡몹 처형 ×1.5")


func test_execute_bonus_absent_above_hp_threshold() -> void:
	var resolver := _spawn_resolver()
	var target := _make_target(0.30, false)
	assert_almost_eq(resolver._execute_multiplier(_execution, target), 1.0, TOL, "HP 30%는 보너스 없음")


func test_execute_bonus_damped_for_boss() -> void:
	var resolver := _spawn_resolver()
	var target := _make_target(0.10, true)
	assert_almost_eq(
		resolver._execute_multiplier(_execution, target), 1.15, TOL, "보스 감쇠 ×1.15(즉살 방지)"
	)


func test_execute_bonus_only_for_finisher() -> void:
	var resolver := _spawn_resolver()
	var target := _make_target(0.10, false)
	assert_almost_eq(resolver._execute_multiplier(WHIRLWIND, target), 1.0, TOL, "다른 스킬에는 처형 보너스 없음")


func test_execute_bonus_absent_when_target_hp_unreadable() -> void:
	## HP를 읽을 수 없는 대상(디버그 더미 등)에는 보너스를 적용하지 않는다.
	var resolver := _spawn_resolver()
	var plain := Node2D.new()
	add_child_autofree(plain)
	assert_almost_eq(resolver._execute_multiplier(_execution, plain), 1.0, TOL, "판정 불가 = 1.0")


# --- 헬퍼 ---


## 검투사 로드아웃이 적용된 플레이어(디버그 직행 시작 — 실제 전직과 동일한 로드아웃 경로).
func _spawn_gladiator() -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	var trans: PlayerJobTransition = player.get_node("PlayerJobTransition")
	trans.initial_job_id = &"gladiator"
	add_child_autofree(player)
	## 공유 CombatantStats 파일 리소스를 사본으로 갈아 끼워 다른 테스트 오염을 막는다.
	var growth: PlayerStatGrowth = player.get_node("PlayerStatGrowth")
	var fresh: CombatantStats = growth.combat_stats.duplicate()
	growth.combat_stats = fresh
	player.get_node("PlayerStats").stats = fresh
	player.get_node("AttackResolver").attacker_stats = fresh
	var stats: PlayerStatsComponent = player.get_node("PlayerStats")
	stats.current_hp = fresh.max_hp
	stats.current_mp = fresh.max_mp
	return player


func _spawn_resolver() -> PlayerAttackResolver:
	return _spawn_gladiator().get_node("AttackResolver") as PlayerAttackResolver


func _make_target(hp_ratio: float, is_boss: bool) -> DummyExecuteTarget:
	var target := DummyExecuteTarget.new()
	var stats := MonsterStatsData.new()
	stats.max_hp = 1000.0
	stats.is_boss = is_boss
	target.stats = stats
	target.hp = stats.max_hp * hp_ratio
	add_child_autofree(target)
	return target
