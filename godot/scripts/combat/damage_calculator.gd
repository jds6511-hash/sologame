## 데미지 공식 계산기 (CB-3).
##
## combat.md 6장의 공식을 그대로 구현한 순수 함수 모음이다.
## 상태를 갖지 않는 정적 함수로만 구성해(RefCounted, 인스턴스화 불필요) 플레이어/몬스터
## 어느 쪽이 공격자·피격자든 동일하게 재사용할 수 있게 한다(공용 모듈 방침).
##
## 공식: 최종 데미지 = 공격력 x 스킬 계수 x 방어 감산 x 치명타 배율 x 위치 보정 x 랜덤 보정
##   방어 감산 = 100 / (100 + 대상 방어력)   … 제산형 방어
class_name DamageCalculator
extends RefCounted


## 치명타 발동 확률 계산 (combat.md 6장: 5% + 민첩x0.05%, 상한 40%)
static func calculate_crit_chance(agility: float, formula: DamageFormulaData) -> float:
	var chance := formula.base_crit_chance + agility * formula.crit_chance_per_agility
	return clampf(chance, 0.0, formula.crit_chance_cap)


## 치명타 발동 여부를 확률에 따라 굴린다. rng를 넘기면 결정적 테스트가 가능하다.
static func roll_critical(crit_chance: float, rng: RandomNumberGenerator = null) -> bool:
	var roll: float = rng.randf() if rng else randf()
	return roll < crit_chance


## 랜덤 보정치(0.95~1.05)를 굴린다. rng를 넘기면 결정적 테스트가 가능하다.
static func roll_random_variance(
	formula: DamageFormulaData, rng: RandomNumberGenerator = null
) -> float:
	if rng:
		return rng.randf_range(formula.random_variance_min, formula.random_variance_max)
	return randf_range(formula.random_variance_min, formula.random_variance_max)


## 최종 데미지 계산.
## random_variance를 0.0 이상 값으로 넘기면 그 값을 그대로 쓴다(GUT 테스트용 결정적 계산).
## 음수(기본 -1.0)면 내부에서 랜덤 보정을 새로 굴린다.
static func calculate_damage(
	attack_power: float,
	skill_coefficient: float,
	target_defense: float,
	formula: DamageFormulaData,
	is_critical: bool = false,
	is_backattack: bool = false,
	random_variance: float = -1.0
) -> float:
	var defense_reduction := 100.0 / (100.0 + target_defense)
	var crit_multiplier := formula.crit_multiplier if is_critical else 1.0
	var position_multiplier := (
		formula.backattack_multiplier if is_backattack else formula.default_position_multiplier
	)
	var variance := random_variance if random_variance >= 0.0 else roll_random_variance(formula)
	return (
		attack_power
		* skill_coefficient
		* defense_reduction
		* crit_multiplier
		* position_multiplier
		* variance
	)
