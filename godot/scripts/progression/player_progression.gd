## 플레이어 성장 상태 — 경험치 누적·레벨업 트리거·처치 경험치 지급 (M3 B-1).
##
## m3-leveling-spec.md 3장(레벨업 트리거)·4장(레벨 차 보정)을 구현한다. 레벨/경험치의
## 권위 상태(current_level·current_exp)를 이 노드가 들고, 몬스터 처치 시 경험치를 지급한다.
## Player 씬의 자식 노드("PlayerProgression")로 배치한다(PlayerStats·AttackResolver와 동일
## 배치 패턴).
##
## 책임 경계(B-1 범위): 이 노드는 "레벨 숫자 상태와 그 전이"까지만 담당한다. 레벨업에
## 따른 실제 스탯 재계산(1차 스탯 +6.0/파생 재계산)은 B-2, 스킬 포인트 지급은 B-3 소관이며,
## 그들은 leveled_up 시그널을 구독해 자신의 일을 한다(spec 9장 의존 관계). 여기서는
## 시그널만 내보낸다.
##
## 배선(spec 7-5, DropSystem.register_monster와 동일 패턴): 월드/레벨 스크립트가 몬스터
## 스폰 시 register_monster(monster, drop_table)를 호출하면, 이 노드가 monster.died를
## 구독해 처치 순간 경험치를 지급한다. 몬스터 레벨·등급(정예/보스)은 DropTableData가
## 이미 보유하므로(골드와 동일 소스) 그대로 재사용한다.
class_name PlayerProgression
extends Node

## 레벨업 발생 — 새 레벨을 인자로 넘긴다. 다중 레벨업 시 레벨마다 1회씩 발신한다
## (B-2 스탯 재계산·B-3 스킬 포인트·B-4 HUD 연출이 구독).
signal leveled_up(new_level: int)
## 현재 레벨 내 경험치가 바뀔 때 발신(획득·레벨업 후) — B-4 경험치 바 갱신용.
## exp_to_next는 현재 레벨의 REQ(만렙이면 0).
signal exp_changed(current_exp: int, exp_to_next: int)

@export var level_curve: LevelCurveData
@export var level_diff_curve: LevelDiffCurve

var current_level: int = 1
var current_exp: int = 0  ## 현재 레벨 내 누적치 (0 <= current_exp < REQ(current_level))

# --- 순수 계산 (static — GUT 직접 검증, GameClock/노드 트리 불필요) ---


## 획득 경험치 = round(기본 EXP x 등급 x 레벨차 x 야간), 최소 1 보장(spec 3-1 구현 규약).
## 반올림은 모든 배율을 곱한 뒤 최종 1회만 수행한다(중간 반올림 누적 오차 방지).
static func calc_exp_gain(
	base_exp: int, grade_mult: float, leveldiff_mult: float, night_mult: float
) -> int:
	return maxi(1, roundi(base_exp * grade_mult * leveldiff_mult * night_mult))


# --- 상태 조회 ---


func is_max_level() -> bool:
	return current_level >= level_curve.max_level


## 다음 레벨까지 필요한 경험치(현재 레벨의 REQ). 만렙이면 다음 레벨이 없어 0.
func exp_to_next() -> int:
	if is_max_level():
		return 0
	return level_curve.req(current_level)


# --- 경험치 누적·레벨업 (spec 3-2) ---


## 경험치를 누적하고 임계 도달 시 레벨업한다. while 루프로 한 번의 획득이 여러 레벨을
## 올릴 수 있으며(초과분 이월), 만렙 도달 시 초과 경험치는 폐기하고 바를 만충 표시한다.
func add_exp(amount: int) -> void:
	if amount <= 0 or is_max_level():
		return
	current_exp += amount
	while not is_max_level() and current_exp >= level_curve.req(current_level):
		current_exp -= level_curve.req(current_level)
		current_level += 1
		leveled_up.emit(current_level)
	if is_max_level():
		current_exp = 0  ## 만렙: 초과 EXP 폐기(spec 3-2 만렙 처리)
	exp_changed.emit(current_exp, exp_to_next())


# --- 처치 경험치 지급 (spec 3-1, 4장) ---


## 몬스터 스폰 시 호출 — died 시그널을 처치 경험치 지급에 연결한다(DropSystem과 동일 패턴).
func register_monster(monster: Node, drop_table: DropTableData) -> void:
	monster.died.connect(grant_kill_exp.bind(drop_table.monster_level, drop_table.tier))


## 몬스터 1마리 처치분 경험치를 계산해 지급한다. 야간 배율은 GameClock의 낮/밤 판정을
## 따르고 보스는 제외한다(combat.md 2-3장). 레벨 차 배율은 몬스터-플레이어 레벨 차로 조회.
func grant_kill_exp(mob_level: int, tier: DropTableData.MonsterTier) -> void:
	var is_boss := tier == DropTableData.MonsterTier.BOSS
	var night_mult := 1.0
	if not is_boss and not GameClock.is_day:
		night_mult = level_curve.night_exp_multiplier
	var leveldiff_mult := level_diff_curve.multiplier(mob_level - current_level)
	var gain := calc_exp_gain(
		level_curve.mob_exp(mob_level), grade_multiplier(tier), leveldiff_mult, night_mult
	)
	add_exp(gain)


## 등급(일반/정예/보스) 경험치 배율(spec 3-1 — 골드 배율과 동일 값, LevelCurveData 참조).
func grade_multiplier(tier: DropTableData.MonsterTier) -> float:
	match tier:
		DropTableData.MonsterTier.ELITE:
			return level_curve.elite_multiplier
		DropTableData.MonsterTier.BOSS:
			return level_curve.boss_multiplier
		_:
			return 1.0
