## 경험치 곡선 데이터 (Resource) — M3 B-1.
##
## m3-leveling-spec.md 2·7-1장(growth.md 5-1장 파생)을 그대로 필드화한다. 필요 경험치
## REQ(L)·몬스터 경험치 EXP(L)의 계수/지수와 등급·야간 배율을 전부 노출해, 페이스
## 레버 실측 조정(M3 D-2)을 코드 수정 없이 이 .tres만 바꿔 수행할 수 있게 한다
## (CLAUDE.md 공통 규칙 "기획 수치를 코드에 하드코딩하지 않는다").
##
## 수식(spec 2-1, growth.md 5-1 그대로):
##   REQ(L) = round(req_coefficient x L^req_exponent x early_multiplier)
##   early_multiplier = pre_transition_req_multiplier when L < first_transition_level, otherwise 1
##   EXP(L) = round(mob_exp_coefficient x L^mob_exp_exponent)
## 정예 x6 / 보스 x40, 야간 x1.2(보스 제외)는 각 배율 필드로 분리했다.
##
## 반올림 안전성(spec 2-1): 정수 L에서 L^2.5·L^1.5의 소수부가 정확히 .5가 되는 경우가
## 없어(무리수), roundi(half-away)와 원표(Python round, half-even)가 전 구간 일치한다.
class_name LevelCurveData
extends Resource

@export var max_level: int = 100  ## 만렙 (spec 전제)

@export_group("필요 경험치 REQ(L) (spec 7-1 — D-2 페이스 레버)")
@export var req_coefficient: float = 55.0
@export var req_exponent: float = 2.5
@export var first_transition_level: int = 10
@export_range(0.01, 1.0, 0.01) var pre_transition_req_multiplier: float = 1.0

@export_group("몬스터 경험치 EXP(L) (spec 7-1)")
@export var mob_exp_coefficient: float = 5.0
@export var mob_exp_exponent: float = 1.5

@export_group("등급·야간 배율 (spec 3-1 — 골드 배율과 동일 값)")
@export var elite_multiplier: float = 6.0
@export var boss_multiplier: float = 40.0
## 야간 경험치 배율(combat.md 2-3장 x1.2, 보스 제외). 낮/밤 판정은 GameClock이 담당하고
## 이 필드는 밤일 때 곱할 값만 제공한다(PlayerProgression.grant_kill_exp).
@export var night_exp_multiplier: float = 1.2


## L -> L+1 필요 경험치. 유효 범위는 L = 1..max_level-1이며, max_level(만렙)은 다음 레벨이
## 없어 레벨업에 쓰지 않는다(호출자가 만렙에서 이 값을 참조하지 않도록 관리).
func req(level: int) -> int:
	var multiplier := pre_transition_req_multiplier if level < first_transition_level else 1.0
	return roundi(req_coefficient * pow(float(level), req_exponent) * multiplier)


## 동렙 일반 몬스터가 주는 기본 경험치 EXP(L) (등급·레벨 차·야간 배율 적용 전).
func mob_exp(level: int) -> int:
	return roundi(mob_exp_coefficient * pow(float(level), mob_exp_exponent))
