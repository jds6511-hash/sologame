## M3 B-2 통합 검증 — PlayerStatGrowth가 PlayerProgression.leveled_up를 구독해 스탯을
## 재계산하고, 늘어난 최대 HP/MP만큼 현재값을 가산하는지(spec 3-2 규약) 확인한다.
## 공유 파일 리소스 오염을 피하려고 CombatantStats는 매 테스트 새로 만든다.
extends GutTest

const FORMULA: StatGrowthFormula = preload("res://data/progression/stat_growth_formula.tres")
const JOB_WARRIOR: JobGrowthData = preload("res://data/progression/job_growth_warrior.tres")
const LEVEL_CURVE: LevelCurveData = preload("res://data/progression/level_curve.tres")
const LEVEL_DIFF_CURVE: LevelDiffCurve = preload("res://data/progression/level_diff_curve.tres")
const RECOVERY: PlayerRecoveryRules = preload("res://data/combat/player_recovery_rules.tres")

const TOL := 0.0001

var _root: Node2D
var _stats: CombatantStats
var _prog: PlayerProgression
var _stats_comp: PlayerStatsComponent
var _growth: PlayerStatGrowth


func before_each() -> void:
	## Lv1 스냅샷(기존 warrior_lv1_combatant_stats.tres와 동일)으로 초기화.
	_stats = CombatantStats.new()
	_stats.attack_power = 26.0
	_stats.agility = 8.0
	_stats.defense = 14.0
	_stats.max_hp = 135.0
	_stats.max_mp = 72.0

	_root = Node2D.new()
	add_child_autofree(_root)

	_stats_comp = PlayerStatsComponent.new()
	_stats_comp.name = "PlayerStats"
	_stats_comp.stats = _stats
	_stats_comp.recovery_rules = RECOVERY
	_root.add_child(_stats_comp)

	_prog = PlayerProgression.new()
	_prog.name = "PlayerProgression"
	_prog.level_curve = LEVEL_CURVE
	_prog.level_diff_curve = LEVEL_DIFF_CURVE
	_root.add_child(_prog)

	_growth = PlayerStatGrowth.new()
	_growth.name = "PlayerStatGrowth"
	_growth.job = JOB_WARRIOR
	_growth.formula = FORMULA
	_growth.combat_stats = _stats
	_root.add_child(_growth)


func after_each() -> void:
	GameClock.reset()


func test_single_level_up_recomputes_shared_stats() -> void:
	_prog.add_exp(LEVEL_CURVE.req(1))  ## Lv1 -> Lv2
	assert_eq(_prog.current_level, 2)
	## Lv2 전사 검산값(spec 2-3): 공격 30.2 / HP 155 / 방어 17.5 / MP 81.5.
	assert_almost_eq(_stats.attack_power, 30.2, TOL, "공격력 재계산")
	assert_almost_eq(_stats.max_hp, 155.0, TOL, "최대 HP 재계산")
	assert_almost_eq(_stats.defense, 17.5, TOL, "방어력 재계산")
	assert_almost_eq(_stats.max_mp, 81.5, TOL, "최대 MP 재계산")


func test_level_up_bumps_current_hp_mp_by_increase() -> void:
	## spec 3-2 규약: 늘어난 최대치만큼 현재값 가산(전체 회복 아님).
	_prog.add_exp(LEVEL_CURVE.req(1))  ## Lv2: maxHP 135->155(+20), maxMP 72->81.5(+9.5)
	assert_almost_eq(_stats_comp.current_hp, 155.0, TOL, "현재 HP += 20")
	assert_almost_eq(_stats_comp.current_mp, 81.5, TOL, "현재 MP += 9.5")


func test_current_hp_bump_is_partial_not_full_heal() -> void:
	## 최대치 미만에서 레벨업하면 증가분만 더해질 뿐 만피가 되지 않는다.
	_stats_comp.current_hp = 50.0
	_prog.add_exp(LEVEL_CURVE.req(1))  ## +20 → 70 (최대 155보다 훨씬 낮음)
	assert_almost_eq(_stats_comp.current_hp, 70.0, TOL, "50 + 20 = 70 (만피 아님)")


func test_multi_level_up_accumulates_increases() -> void:
	var lump := LEVEL_CURVE.req(1) + LEVEL_CURVE.req(2)  ## Lv1 -> Lv3
	_prog.add_exp(lump)
	assert_eq(_prog.current_level, 3)
	## Lv3 전사: 체력 11 → HP 50+110+15 = 175, MP 지력 11 → 30+55+6 = 91.
	assert_almost_eq(_stats.max_hp, 175.0, TOL, "Lv3 최대 HP")
	assert_almost_eq(_stats.max_mp, 91.0, TOL, "Lv3 최대 MP")
	## 현재 HP는 Lv1 만피(135)에서 시작해 (175-135)=40 가산 → 175.
	assert_almost_eq(_stats_comp.current_hp, 175.0, TOL, "누적 증가분 반영")


func test_recompute_stats_does_not_bump_current() -> void:
	## 세이브 로드·전직용 공개 API: 스탯만 세팅, 현재 HP/MP 불변.
	_stats_comp.current_hp = 100.0
	_growth.recompute_stats(40)
	assert_almost_eq(_stats.max_hp, 1065.0, TOL, "Lv40 최대 HP 세팅")
	assert_almost_eq(_stats_comp.current_hp, 100.0, TOL, "현재 HP는 불변")
