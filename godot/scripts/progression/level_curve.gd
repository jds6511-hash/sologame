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
## 배포 C1: L11~19는 1→0.4 기하 보간, L20부터0.4. Legacy는 과거 fixture 재현용이다.
## QA 계산기는 Godot과 같은 half-away 반올림을 쓰며 두 프로필 전99값을 대조한다.
class_name LevelCurveData
extends Resource

enum Profile { LEGACY, C1 }

@export var max_level: int = 100  ## 만렙 (spec 전제)
@export var profile: Profile = Profile.LEGACY
@export var c1_multiplier: float = 0.4
@export var c1_blend_start_level: int = 10
@export var c1_blend_end_level: int = 20

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
	if profile == Profile.C1 and level > c1_blend_start_level:
		var blend := clampf(
			float(level - c1_blend_start_level) / float(c1_blend_end_level - c1_blend_start_level),
			0.0,
			1.0
		)
		multiplier *= pow(c1_multiplier, blend)
	return roundi(req_coefficient * pow(float(level), req_exponent) * multiplier)


## 동렙 일반 몬스터가 주는 기본 경험치 EXP(L) (등급·레벨 차·야간 배율 적용 전).
func mob_exp(level: int) -> int:
	return roundi(mob_exp_coefficient * pow(float(level), mob_exp_exponent))
