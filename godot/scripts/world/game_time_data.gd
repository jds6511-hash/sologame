## 게임 내 시간 규칙 데이터 (Resource) — G2-4.
##
## `reputation-territory.md` 4장(게임 내 시간 확정)·`combat.md` 2-3장(주야간 전투 규칙)의
## 확정 수치를 그대로 필드화했다. 수치를 코드에 하드코딩하지 않기 위함(CLAUDE.md 공통 규칙).
## 값 변경 시 systems-designer 확인 후 이 리소스만 바꾸면 된다.
##
## 낮:밤 = 20분:10분(2:1)을 "게임 시계 24시간에도 그대로 2:1로 투영"하는 단일 배속 모델을
## 쓴다 — 낮 00:00~16:00(16시간)·밤 16:00~24:00(8시간)로 고정하고, 게임 시계는 항상 같은
## 배속(현실 1초 = 게임 48초)으로 흐른다. 이렇게 하면 "낮 구간엔 게임 1시간이 더 길게
## 흐른다"는 별도 배속 전환 없이, 현실 시간 비율(20:10)과 게임 시계 비율(16:8)이 동일한
## 2:1이 되어 한 가지 상수(day_phase_fraction)만으로 낮/밤 경계를 계산할 수 있다.
## (기획 문서에 낮/밤의 정확한 게임 시각 경계는 명시돼 있지 않아 systems-dev가 채택한
## 해석 — 결과 보고에 "가정"으로 명시.)
class_name GameTimeData
extends Resource

@export_group("게임 하루 길이 (reputation-territory.md 4장)")
## 게임 하루 전체의 현실 초 — 현실 30분 = 게임 하루(디렉터 확정)
@export var real_seconds_per_game_day: float = 1800.0
## 낮 구간의 현실 초 — 낮 20분 : 밤 10분(2:1) 확정분. 밤 구간은 나머지(위 값 - 이 값)로 계산한다.
@export var real_seconds_day_phase: float = 1200.0

@export_group("야간 전투 배율 (combat.md 2-3장, 보스 제외)")
## 야간 일반·정예 몬스터 HP/공격력 배율 (디렉터 확정 ×1.2, 보스 제외)
@export var night_monster_stat_multiplier: float = 1.2
## 야간 일반·정예 몬스터 아이템 드랍률 배율 (economy-foundation.md 9장 채택 확정 ×1.15,
## 골드 제외·보스 제외)
@export var night_item_drop_rate_multiplier: float = 1.15
## 야간 경험치 배율 (combat.md 2-3장 확정 ×1.2) — 경험치 시스템 자체가 M2에 미구현이라
## 이 필드는 현재 어디서도 참조하지 않는다. 경험치 시스템 구현 시(M3 백로그) 사용할 것.
@export var night_exp_multiplier: float = 1.2
