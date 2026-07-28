## M3 C-1 검증 ② — 검투사 스킬 4종 .tres 규격과 혈투의 함성 효과
## (m3-warrior-tier2-skills.md 4장 상세 규격 · 5장 combat.md 7장 대조표).
##
## 계수·쿨다운·MP·판정 형태·모션 시간·히트스톱이 확정 규격과 일치하는지, 그리고 승계 델타
## (분쇄 베기 → 360° / 돌격 → 그로기 셋업 / 결의의 외침 → 공세형 흡혈)가 데이터에 실제로
## 반영됐는지 본다. 게이지 자체는 test_gladiator_rage_gauge.gd, 씬 배선은
## test_gladiator_combat_wiring.gd가 담당한다.
extends GutTest

const WHIRLWIND: WarriorSkillData = preload(
	"res://data/player/skills/gladiator/skill_slot4_whirlwind.tres"
)
const CHARGE_SLAM: WarriorSkillData = preload(
	"res://data/player/skills/gladiator/skill_slotq_charge_slam.tres"
)
const BLOOD_SHOUT: GladiatorSkillData = preload(
	"res://data/player/skills/gladiator/skill_slote_blood_shout.tres"
)
const BATTLE_SHOUT: WarriorSkillData = preload(
	"res://data/player/skills/skill_slote_battle_shout.tres"
)
const CRUSHING_BLOW: WarriorSkillData = preload(
	"res://data/player/skills/skill_slot4_crushing_blow.tres"
)
const CHARGE_RUSH: WarriorSkillData = preload(
	"res://data/player/skills/skill_slotq_charge_rush.tres"
)
## 처형 일격은 발동 시 damage_coefficient를 덮어쓰므로 const preload로 잡지 않는다
## (상수로 참조된 리소스는 read-only가 되어 그 쓰기가 무시된다).
const EXECUTION_PATH := "res://data/player/skills/gladiator/skill_secondary_execution.tres"

const TOL := 0.0001

var _execution: GladiatorSkillData = load(EXECUTION_PATH)
var _rage: PlayerRageModule


func before_each() -> void:
	_rage = PlayerRageModule.new()
	_rage.refresh_job(_execution)


# --- 4-1. 검투 선풍 (슬롯 4) ---


func test_whirlwind_matches_spec() -> void:
	assert_eq(WHIRLWIND.skill_name, "검투 선풍")
	assert_eq(WHIRLWIND.skill_type, WarriorSkillData.SkillType.INSTANT)
	assert_almost_eq(WHIRLWIND.damage_coefficient, 3.0, TOL, "계수 3.0(일반 스킬 규격 상단)")
	assert_almost_eq(WHIRLWIND.cooldown_sec, 9.0, TOL, "쿨다운 9초")
	assert_almost_eq(WHIRLWIND.mp_cost_percent, 0.12, TOL, "MP 12%")
	assert_almost_eq(WHIRLWIND.hitbox_angle_deg, 360.0, TOL, "자기 중심 360° 원형")
	assert_almost_eq(WHIRLWIND.hitbox_range_tiles, 2.2, TOL, "반경 2.2타일")
	assert_almost_eq(WHIRLWIND.startup_sec, 0.3, TOL, "선딜 0.3초")
	assert_almost_eq(WHIRLWIND.active_sec, 0.4, TOL, "판정 0.4초")
	assert_almost_eq(WHIRLWIND.recovery_sec, 0.4, TOL, "후딜 0.4초")
	assert_eq(WHIRLWIND.hitstop_preset, "중")
	assert_false(WHIRLWIND.self_superarmor_during_cast, "일반 스킬 — 회전 중 경직 가능")


func test_whirlwind_inherits_and_upgrades_crushing_blow() -> void:
	## 승계 델타 — 부채꼴 120° → 360°, 계수 2.4 → 3.0(+25%), 쿨다운도 함께 상향.
	assert_gt(WHIRLWIND.damage_coefficient, CRUSHING_BLOW.damage_coefficient, "계수 상향 승계")
	assert_gt(WHIRLWIND.hitbox_angle_deg, CRUSHING_BLOW.hitbox_angle_deg, "판정 형태 전방위 확장")
	assert_gt(WHIRLWIND.cooldown_sec, CRUSHING_BLOW.cooldown_sec, "계수↑ = 쿨다운↑")


# --- 4-2. 난입 강타 (슬롯 Q) ---


func test_charge_slam_matches_spec() -> void:
	assert_eq(CHARGE_SLAM.skill_name, "난입 강타")
	assert_eq(CHARGE_SLAM.skill_type, WarriorSkillData.SkillType.DASH)
	assert_almost_eq(CHARGE_SLAM.damage_coefficient, 1.5, TOL, "계수 1.5(이동기 규격 상한)")
	assert_almost_eq(CHARGE_SLAM.cooldown_sec, 11.0, TOL, "쿨다운 11초")
	assert_almost_eq(CHARGE_SLAM.mp_cost_percent, 0.10, TOL, "MP 10%")
	assert_almost_eq(CHARGE_SLAM.dash_distance_tiles, 2.5, TOL, "돌진 2.5타일(돌격 모션 재사용)")
	assert_almost_eq(CHARGE_SLAM.dash_duration_sec, 0.3, TOL, "돌진 0.3초")
	assert_almost_eq(CHARGE_SLAM.startup_sec, 0.12, TOL, "선딜 0.12초")
	assert_almost_eq(CHARGE_SLAM.recovery_sec, 0.35, TOL, "후딜 0.35초")
	assert_eq(CHARGE_SLAM.hitstop_preset, "중")
	assert_false(CHARGE_SLAM.self_superarmor_during_cast, "이동기 — 무적/슈퍼아머 없음")


func test_charge_slam_inherits_and_upgrades_charge_rush() -> void:
	## 승계 델타 — 돌진 규격은 그대로(모션 재사용), 계수와 기절만 강화된다.
	assert_almost_eq(
		CHARGE_SLAM.dash_distance_tiles, CHARGE_RUSH.dash_distance_tiles, TOL, "돌진 거리 동일"
	)
	assert_almost_eq(CHARGE_SLAM.dash_duration_sec, CHARGE_RUSH.dash_duration_sec, TOL, "돌진 시간 동일")
	assert_gt(CHARGE_SLAM.damage_coefficient, CHARGE_RUSH.damage_coefficient, "계수 1.3 → 1.5")
	assert_almost_eq(CHARGE_SLAM.on_hit_stun_sec, 0.4, TOL, "기절 0.3 → 0.4초")


# --- 4-3. 혈투의 함성 (슬롯 E) ---


func test_blood_shout_matches_spec() -> void:
	assert_eq(BLOOD_SHOUT.skill_name, "혈투의 함성")
	assert_eq(BLOOD_SHOUT.skill_type, WarriorSkillData.SkillType.BUFF_HEAL)
	assert_almost_eq(BLOOD_SHOUT.cooldown_sec, 22.0, TOL, "쿨다운 22초")
	assert_almost_eq(BLOOD_SHOUT.mp_cost_percent, 0.20, TOL, "MP 20%(버프·힐 고정값)")
	assert_almost_eq(BLOOD_SHOUT.buff_duration_sec, 8.0, TOL, "지속 8초")
	assert_almost_eq(BLOOD_SHOUT.lifesteal_percent, 0.12, TOL, "흡혈 12%")
	assert_almost_eq(BLOOD_SHOUT.lifesteal_total_cap_percent, 0.30, TOL, "총 회복 상한 30%")
	assert_almost_eq(BLOOD_SHOUT.rage_gain_buff_percent, 0.50, TOL, "분노 충전 +50%")
	assert_almost_eq(BLOOD_SHOUT.grants_superarmor_sec, 2.0, TOL, "슈퍼아머 2초")
	assert_almost_eq(BLOOD_SHOUT.startup_sec, 0.4, TOL, "선딜 0.4초(포효 모션 재사용)")
	assert_almost_eq(BLOOD_SHOUT.recovery_sec, 0.3, TOL, "후딜 0.3초")


func test_blood_shout_switches_from_defensive_to_offensive() -> void:
	## 승계 델타 — 결의의 외침(방어 +20% · 슈퍼아머 3초)에서 공세형(흡혈 · 분노 가속)으로.
	assert_gt(BATTLE_SHOUT.defense_buff_percent, 0.0, "1차는 방어 버프형")
	assert_almost_eq(BLOOD_SHOUT.defense_buff_percent, 0.0, TOL, "2차는 방어 버프 없음")
	assert_gt(BLOOD_SHOUT.lifesteal_percent, 0.0, "2차는 흡혈로 유지")
	assert_gt(BLOOD_SHOUT.cooldown_sec, BATTLE_SHOUT.cooldown_sec, "쿨다운 20 → 22초")


func test_lifesteal_heals_twelve_percent_of_damage() -> void:
	_rage.apply_buff(BLOOD_SHOUT, 1.0, 1000.0)
	assert_almost_eq(_rage.lifesteal_heal(200.0), 24.0, TOL, "가한 피해의 12% 회복")


func test_lifesteal_total_is_capped_at_thirty_percent_of_max_hp() -> void:
	_rage.apply_buff(BLOOD_SHOUT, 1.0, 1000.0)
	var total := 0.0
	for _i in 100:
		total += _rage.lifesteal_heal(500.0)
	assert_almost_eq(total, 300.0, TOL, "1회 발동당 총 회복 상한 = 최대 HP 30%")


func test_lifesteal_cap_ignores_skill_upgrade_multiplier() -> void:
	## combat.md 7장 힐 총량 하드 캡 — 스킬 강화로 넘길 수 없어야 한다(4-3장).
	_rage.apply_buff(BLOOD_SHOUT, 2.0, 1000.0)
	var total := 0.0
	for _i in 100:
		total += _rage.lifesteal_heal(500.0)
	assert_almost_eq(total, 300.0, TOL, "강화 배율이 총 회복 상한을 올리지 않는다")


func test_buff_accelerates_rage_gain_by_fifty_percent() -> void:
	_rage.apply_buff(BLOOD_SHOUT, 1.0, 1000.0)
	_rage.add_from_hit_taken()
	assert_almost_eq(_rage.current_rage, 18.0, TOL, "피격 12 x 1.5(분노 충전 +50%)")


func test_buff_expires_after_eight_seconds() -> void:
	_rage.apply_buff(BLOOD_SHOUT, 1.0, 1000.0)
	_rage.advance(8.0)
	assert_eq(_rage.lifesteal_heal(500.0), 0.0, "8초 후 흡혈 종료")
	_rage.add_from_hit_taken()
	assert_almost_eq(_rage.current_rage, 12.0, TOL, "8초 후 분노 가속 종료")


# --- 4-4. 처형 일격 (우클릭 격노 파생) ---


func test_execution_matches_spec() -> void:
	assert_eq(_execution.skill_name, "처형 일격")
	assert_true(_execution.is_rage_finisher, "우클릭 격노 파생 피니셔")
	assert_almost_eq(_execution.cooldown_sec, 0.0, TOL, "쿨다운 없음(분노가 재사용 제한)")
	assert_almost_eq(_execution.mp_cost_percent, 0.0, TOL, "MP 0%")
	assert_almost_eq(_execution.hitbox_angle_deg, 120.0, TOL, "전방 부채꼴 120°")
	assert_almost_eq(_execution.hitbox_range_tiles, 2.4, TOL, "2.4타일")
	assert_almost_eq(_execution.startup_sec, 0.35, TOL, "선딜 0.35초")
	assert_almost_eq(_execution.active_sec, 0.15, TOL, "판정 0.15초")
	assert_almost_eq(_execution.recovery_sec, 0.5, TOL, "후딜 0.5초")
	assert_eq(_execution.hitstop_preset, "강", "피니셔 = 강 고정")
	assert_true(_execution.self_superarmor_during_cast, "선딜~판정 슈퍼아머")


func test_execution_bonus_values_match_spec() -> void:
	assert_almost_eq(_execution.execute_hp_threshold, 0.25, TOL, "처형 보너스 HP 25% 이하")
	assert_almost_eq(_execution.execute_multiplier, 1.5, TOL, "잡몹·정예 ×1.5")
	assert_almost_eq(_execution.execute_boss_multiplier, 1.15, TOL, "보스 ×1.15 감쇠")
	assert_lt(
		_execution.execute_boss_multiplier, _execution.execute_multiplier, "보스는 감쇠되어야 한다(후반 즉살 방지)"
	)
