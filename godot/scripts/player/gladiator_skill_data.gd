## 검투사(전사 2차 전직) 스킬 슬롯 1개 분량의 규격 데이터 (Resource, M3 C-1).
##
## m3-warrior-tier2-skills.md 2·4장의 검투사 고유 항목만 추가하고, 계수/쿨다운/MP/모션
## 시간처럼 전 직업 공통인 항목은 WarriorSkillData를 그대로 상속해 재사용한다 —
## ArcherSkillData(C-4)와 동일한 확장 방식이다. 상속 덕분에 JobDefinition의 스킬 슬롯
## (WarriorSkillData 타입)과 PlayerController·PlayerAttackResolver의 duck-typing 계약,
## 스킬 강화(B-3, skill_name을 skill_id로 쓴다)에 그대로 들어간다.
##
## 스킬 유형은 상속받은 SkillType을 재사용한다:
##   검투 선풍 = INSTANT(360° 원형) / 난입 강타 = DASH / 혈투의 함성 = BUFF_HEAL /
##   처형 일격 = INSTANT + is_rage_finisher(우클릭 격노 파생 — 차지 홀드가 아니다).
##
## 분노 게이지 규칙(2장)은 **처형 일격 리소스 하나가 소유**한다 — 게이지를 켜는 조건이
## "격노 파생 스킬이 배선돼 있는가"이고 충전량이 기본 4 / 스킬 8로 균일해서, 전 스킬에 같은
## 값을 복제하는 대신 튜닝 지점을 한 파일로 모았다(상세는 player_rage_module.gd 헤더).
class_name GladiatorSkillData
extends WarriorSkillData

@export_group("처형 일격 — 우클릭 격노 파생 (4-4장)")
## true면 이 슬롯은 분노 게이지를 소모하는 피니셔다. PlayerController가 우클릭 입력에서
## 차지 강타 대신 이 스킬을 발동하고, PlayerRageModule이 이 리소스의 게이지 규칙을 읽는다.
@export var is_rage_finisher: bool = false
## 소모 분노 선형 비례 계수 — 하한 소모(rage_finisher_min) ~ 만땅(rage_max).
## damage_coefficient는 발동 시점에 이 두 값으로 덮어써진다(차지 강타와 동일 방식).
@export var rage_coefficient_at_min: float = 3.5
@export var rage_coefficient_at_max: float = 5.0
## 처형 보너스 — 대상 현재 HP가 이 비율 이하면 계수에 배율이 곱해진다.
@export var execute_hp_threshold: float = 0.25
@export var execute_multiplier: float = 1.5  ## 잡몹·정예
@export var execute_boss_multiplier: float = 1.15  ## 보스는 감쇠(후반 즉살 방지)

@export_group("분노 게이지 규칙 (2-1~2-4장) — 격노 파생 스킬이 함께 소유한다")
@export var rage_max: float = 100.0
@export var rage_gain_basic_hit: float = 4.0  ## 기본 공격 명중당
@export var rage_gain_skill_hit: float = 8.0  ## 스킬 명중(캐스트당 1회)
@export var rage_gain_crit_multiplier: float = 1.5  ## 치명타 명중 시 충전량 배율
@export var rage_gain_on_hit_taken: float = 12.0  ## 피격당(최대 단일 충전원)
@export var rage_finisher_min: float = 50.0  ## 처형 일격 발동 하한
@export var rage_enrage_threshold: float = 80.0  ## 격노(공격력 버프) 진입선
@export var enrage_attack_buff_percent: float = 0.12  ## 격노 중 전 데미지 +12%
## 전투 이탈 판정 시간(초)과 이탈 후 초당 감쇠량(combat.md 5-4 "마지막 유효 전투 행동 후").
@export var rage_combat_exit_sec: float = 5.0
@export var rage_decay_per_sec: float = 5.0

@export_group("혈투의 함성 — 흡혈·분노 가속 (4-3장)")
## 가한 피해의 이 비율만큼 HP를 회복한다(0.12 = 12%).
@export var lifesteal_percent: float = 0.0
## 1회 발동당 흡혈 총 회복 상한(최대 HP 대비). combat.md 7장 힐 총량 규격 하드 캡이라
## 스킬 강화 배율을 곱하지 않는다.
@export var lifesteal_total_cap_percent: float = 0.30
## 분노 충전량 가산 비율(0.50 = +50%).
@export var rage_gain_buff_percent: float = 0.0
## 버프 지속 시간(초). 0이면 검투사 버프가 아니다(적용하지 않음).
@export var buff_duration_sec: float = 0.0
