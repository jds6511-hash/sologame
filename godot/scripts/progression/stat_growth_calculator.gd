## 스탯 자동 성장 순수 계산기 (M3 B-2) — m3-leveling-spec.md 5장.
##
## (레벨, 직업)의 "순수 함수"로 1차 스탯과 파생 스탯을 계산한다. 레벨업마다 누적 가산하는
## 방식이 아니라 매번 통째로 재계산하므로(spec 5-3), 부동소수 누적 오차가 없고 세이브에
## 레벨·직업만 저장하면 스탯을 복원할 수 있으며 다중 레벨업·전직 소급이 자동으로 맞는다.
##
## 상태를 갖지 않는 정적 함수로만 구성한다(DamageCalculator와 동일한 공용 모듈 방침).
## GUT가 노드 트리 없이 임의 레벨을 단발로 검증할 수 있다(spec 5-3).
##
## 1차 스탯(spec 5-1): stat_x = 초기 + min(L-1, 전직임계-1) x 모험가성장 + max(L-전직임계,0) x 직업성장
## 파생 스탯(spec 5-2): 최대 HP/MP·공격력·방어력·치명타(민첩 경유). 공격력/방어력은 스탯
##   기여분 + 동렙 B급 장비 기여분(gear_baseline, 책임 분리 주의는 StatGrowthFormula 참고).
class_name StatGrowthCalculator
extends RefCounted


## 1차 스탯 1종(spec 5-1). growth는 해당 스탯의 직업 레벨당 배분치.
static func primary_stat(
	level: int, growth: float, job: JobGrowthData, f: StatGrowthFormula
) -> float:
	var adventurer_levels := mini(level - 1, job.transition_level - 1)
	var job_levels := maxi(level - job.transition_level, 0)
	return f.initial_stat + adventurer_levels * f.adventurer_growth + job_levels * growth


## 1차 스탯 4종을 한 번에 계산해 Dictionary로 돌려준다(키: str/agi/int/vit).
static func compute_primary(level: int, job: JobGrowthData, f: StatGrowthFormula) -> Dictionary:
	return {
		"str": primary_stat(level, job.growth_str, job, f),
		"agi": primary_stat(level, job.growth_agi, job, f),
		"int": primary_stat(level, job.growth_int, job, f),
		"vit": primary_stat(level, job.growth_vit, job, f),
	}


## 주스탯 값(공격력 = 무기 + 주스탯x2에서 쓰는 스탯) 추출.
static func main_stat_value(primary: Dictionary, main_stat: JobGrowthData.MainStat) -> float:
	match main_stat:
		JobGrowthData.MainStat.STR:
			return primary["str"]
		JobGrowthData.MainStat.AGI:
			return primary["agi"]
		JobGrowthData.MainStat.INT:
			return primary["int"]
		_:
			return primary["vit"]


# --- 파생 스탯 (spec 5-2) ---


static func max_hp(vit: float, level: int, f: StatGrowthFormula) -> float:
	return f.hp_base + vit * f.hp_per_vit + level * f.hp_per_level


static func max_mp(intelligence: float, level: int, f: StatGrowthFormula) -> float:
	return f.mp_base + intelligence * f.mp_per_int + level * f.mp_per_level


## 공격력의 "스탯 기여분"(주스탯 x 계수) — 장비 기여 제외(spec 5-2 책임 분리).
static func attack_contribution(main_stat: float, f: StatGrowthFormula) -> float:
	return main_stat * f.attack_per_main_stat


## 방어력의 "스탯 기여분"(체력 x 계수) — 장비 기여 제외.
static func defense_contribution(vit: float, f: StatGrowthFormula) -> float:
	return vit * f.defense_per_vit


## 동렙 B급 무기 공격력(임시 장비 기준선, StatGrowthFormula 주의 참고).
static func gear_weapon_attack(level: int, f: StatGrowthFormula) -> float:
	return f.weapon_attack_base + level * f.weapon_attack_per_level


## 동렙 B급 방어구 4부위 방어 합(임시 장비 기준선).
static func gear_armor_defense(level: int, f: StatGrowthFormula) -> float:
	return f.armor_defense_base + level * f.armor_defense_per_level


## (레벨, 직업)으로 계산한 스탯을 CombatantStats에 통째로 채운다(내부 float 유지).
## 공격력/방어력은 스탯 기여분 + 동렙 B급 장비 기준선의 합. 치명타%는 이 함수가 채우는
## agility 값을 DamageCalculator가 전투 시점에 공식(5+민첩x0.05, 상한 40%)으로 산출한다.
static func apply(
	stats: CombatantStats, level: int, job: JobGrowthData, f: StatGrowthFormula
) -> void:
	var primary := compute_primary(level, job, f)
	var main := main_stat_value(primary, job.main_stat)
	stats.attack_power = gear_weapon_attack(level, f) + attack_contribution(main, f)
	stats.defense = gear_armor_defense(level, f) + defense_contribution(primary["vit"], f)
	stats.max_hp = max_hp(primary["vit"], level, f)
	stats.max_mp = max_mp(primary["int"], level, f)
	stats.agility = primary["agi"]
