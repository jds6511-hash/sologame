## M3 C-1 검증 ① — 분노 게이지 모듈 자체 (m3-warrior-tier2-skills.md 2장).
##
## 충전(2-2)·격노(2-3)·감쇠(2-4)·소모와 처형 계수(2-3·4-4)를 PlayerRageModule 단위로 본다.
## 검투사 스킬 4종의 .tres 규격은 test_gladiator_skills.gd, 실제 씬 배선은
## test_gladiator_combat_wiring.gd가 담당한다.
extends GutTest

const WHIRLWIND: WarriorSkillData = preload(
	"res://data/player/skills/gladiator/skill_slot4_whirlwind.tres"
)
const CHARGED_SMASH: WarriorSkillData = preload(
	"res://data/player/skills/skill_secondary_charged_smash.tres"
)
## 처형 일격은 발동 시 damage_coefficient를 런타임에 덮어쓰므로(차지 강타와 동일 방식)
## const preload로 잡으면 안 된다 — GDScript가 상수로 참조된 리소스를 read-only로 표시해
## 그 쓰기가 조용히 무시된다. load()로 받아 쓰기 가능한 상태를 유지한다.
const EXECUTION_PATH := "res://data/player/skills/gladiator/skill_secondary_execution.tres"

const TOL := 0.0001

var _execution: GladiatorSkillData = load(EXECUTION_PATH)
var _rage: PlayerRageModule


func before_each() -> void:
	_rage = PlayerRageModule.new()
	_rage.refresh_job(_execution)


# --- 충전 (2-2장) ---


func test_inactive_without_rage_finisher() -> void:
	var plain := PlayerRageModule.new()
	plain.refresh_job(CHARGED_SMASH)  ## 1차 전사 우클릭 = 차지 강타 → 분노 게이지 비활성
	assert_false(plain.is_active(), "격노 파생 스킬이 없으면 분노 게이지를 쓰지 않는다")
	plain.add_from_hit_taken()
	assert_eq(plain.current_rage, 0.0, "비활성 상태에서는 충전되지 않는다")
	assert_almost_eq(plain.attack_multiplier(), 1.0, TOL, "비활성 상태 데미지 배율 1.0")


func test_starts_empty_and_is_active_for_gladiator() -> void:
	assert_true(_rage.is_active(), "검투사(격노 파생 배선) = 분노 게이지 활성")
	assert_eq(_rage.current_rage, 0.0, "시작치 0 (시간 충전 없음)")
	assert_almost_eq(_rage.max_rage(), 100.0, TOL, "최대치 100")


func test_basic_attack_hit_charges_four() -> void:
	_rage.add_from_attack(WarriorAttackStep.new(), false)
	assert_almost_eq(_rage.current_rage, 4.0, TOL, "기본 공격 명중 +4")


func test_skill_hit_charges_eight() -> void:
	_rage.add_from_attack(WHIRLWIND, false)
	assert_almost_eq(_rage.current_rage, 8.0, TOL, "스킬 명중 +8")


func test_critical_multiplies_charge_by_1_5() -> void:
	_rage.add_from_attack(WarriorAttackStep.new(), true)
	assert_almost_eq(_rage.current_rage, 6.0, TOL, "기본 공격 치명타 = 4 x 1.5")
	_rage.add_from_attack(WHIRLWIND, true)
	assert_almost_eq(_rage.current_rage, 18.0, TOL, "스킬 치명타 = +8 x 1.5")


func test_hit_taken_charges_twelve_and_is_largest_source() -> void:
	_rage.add_from_hit_taken()
	assert_almost_eq(_rage.current_rage, 12.0, TOL, "피격 +12")
	assert_gt(
		_execution.rage_gain_on_hit_taken,
		_execution.rage_gain_skill_hit,
		"피격이 최대 단일 충전원(전사 정체성 '맞으면서 밀어붙이기')"
	)


func test_charge_clamps_at_max() -> void:
	for _i in 40:
		_rage.add_from_hit_taken()
	assert_almost_eq(_rage.current_rage, 100.0, TOL, "최대치 100 초과 없음")


func test_finisher_itself_does_not_charge() -> void:
	_rage.add_from_attack(_execution, false)
	assert_eq(_rage.current_rage, 0.0, "처형 일격은 분노를 소모하는 스킬 — 충전 없음")


func test_rage_changed_signal_emitted_on_charge() -> void:
	watch_signals(_rage)
	_rage.add_from_hit_taken()
	assert_signal_emitted_with_parameters(_rage, "rage_changed", [12.0, 100.0])


# --- 격노 (2-3장) ---


func test_enrage_enters_at_eighty() -> void:
	_charge_to(79.0)
	assert_false(_rage.is_enraged(), "79에서는 격노 아님")
	assert_almost_eq(_rage.attack_multiplier(), 1.0, TOL, "미격노 배율 1.0")
	_charge_to(80.0)
	assert_true(_rage.is_enraged(), "80 이상 = 격노")
	assert_almost_eq(_rage.attack_multiplier(), 1.12, TOL, "격노 중 전 데미지 +12%")


func test_enrage_changed_signal_fires_once_per_transition() -> void:
	watch_signals(_rage)
	_charge_to(80.0)
	assert_signal_emitted_with_parameters(_rage, "enrage_changed", [true])
	assert_signal_emit_count(_rage, "enrage_changed", 1, "임계 통과 1회만 발신")
	_rage.add_from_hit_taken()
	assert_signal_emit_count(_rage, "enrage_changed", 1, "격노 유지 중에는 재발신 없음")


# --- 감쇠 (2-4장) ---


func test_no_decay_during_combat() -> void:
	_charge_to(50.0)
	_rage.advance(4.9)  ## 전투 이탈 판정(5초) 이전
	assert_almost_eq(_rage.current_rage, 50.0, TOL, "전투 중에는 감쇠 없음")


func test_decays_five_per_second_after_combat_exit() -> void:
	_charge_to(50.0)
	_rage.advance(5.0)  ## 이탈 판정 경계 — 아직 감쇠 0
	assert_almost_eq(_rage.current_rage, 50.0, TOL, "경계에서는 감쇠 시작 전")
	_rage.advance(2.0)
	assert_almost_eq(_rage.current_rage, 40.0, TOL, "이탈 후 초당 -5 (2초 = -10)")


func test_full_gauge_decays_to_zero_in_twenty_seconds() -> void:
	_charge_to(100.0)
	_rage.advance(5.0)
	_rage.advance(20.0)
	assert_almost_eq(_rage.current_rage, 0.0, TOL, "만땅 → 완전 감쇠까지 20초")
	assert_false(_rage.is_enraged(), "감쇠로 격노 해제")


func test_combat_action_resets_decay_timer() -> void:
	_charge_to(50.0)
	_rage.advance(4.0)
	_rage.add_from_hit_taken()  ## 유효 전투 행동 — 이탈 타이머 초기화
	_rage.advance(4.0)
	assert_almost_eq(_rage.current_rage, 62.0, TOL, "타이머가 되돌아가 감쇠가 시작되지 않는다")


# --- 소모·처형 계수 (2-3·4-4장) ---


func test_finisher_requires_fifty() -> void:
	_charge_to(49.0)
	assert_false(_rage.can_use_finisher(), "49에서는 처형 일격 불가")
	assert_eq(_rage.consume_for_finisher(), 0.0, "발동 불가 시 소모 없음")
	assert_almost_eq(_rage.current_rage, 49.0, TOL, "거부 시 게이지 불변")
	_charge_to(50.0)
	assert_true(_rage.can_use_finisher(), "50 이상 처형 일격 가능")


func test_finisher_consumes_all_rage() -> void:
	_charge_to(88.0)
	assert_almost_eq(_rage.consume_for_finisher(), 88.0, TOL, "보유 분노 전량 소모")
	assert_eq(_rage.current_rage, 0.0, "소모 후 게이지 0")
	assert_false(_rage.is_enraged(), "소모로 격노 해제")


func test_finisher_coefficient_is_linear_in_consumed_rage() -> void:
	assert_almost_eq(_rage.finisher_coefficient(50.0), 3.5, TOL, "50 소모 = 계수 3.5")
	assert_almost_eq(_rage.finisher_coefficient(75.0), 4.25, TOL, "75 소모 = 선형 중간 4.25")
	assert_almost_eq(_rage.finisher_coefficient(100.0), 5.0, TOL, "100 소모 = 계수 5.0")
	## 선형성 — 등간격 소모량의 계수 증분이 일정해야 한다.
	var d1 := _rage.finisher_coefficient(70.0) - _rage.finisher_coefficient(60.0)
	var d2 := _rage.finisher_coefficient(90.0) - _rage.finisher_coefficient(80.0)
	assert_almost_eq(d1, d2, TOL, "선형 비례")


func test_finisher_coefficient_stays_below_ultimate_floor() -> void:
	## 4-4장 — 상한 5.0은 궁극기 하한(6.0) 아래로 억제해 대지 분쇄(8.0) 위상을 침범하지 않는다.
	assert_lt(_rage.finisher_coefficient(100.0), 6.0, "처형 계수 상한 < 궁극기 하한 6.0")


# --- 헬퍼 ---


## 게이지를 정확히 target_rage로 맞춘다(충전 경로를 거친 뒤 값을 확정해 격노 상태까지 갱신).
func _charge_to(target_rage: float) -> void:
	_rage.current_rage = 0.0
	while _rage.current_rage < target_rage:
		_rage.add_from_attack(WarriorAttackStep.new(), false)  ## +4씩
	_rage.current_rage = target_rage
	_rage._refresh_enrage()
