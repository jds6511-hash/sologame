## 플레이어 회복 규칙 데이터 (Resource, CB-5).
##
## combat.md 5-4장 "회복 규칙" 표의 확정 수치를 그대로 필드화했다. 포션 4티어의 가격·수량
## 자체(economy-foundation.md 5장)는 IT-1/IT-3(systems-dev) 아이템·인벤토리 몫이며, 본
## 리소스는 "포션 1회 사용의 효과·쿨다운·보스전 캡"이라는 공통 규칙만 담는다(구조만 구현 —
## M2에는 보스가 없어 보스전 캡 트리거 자체는 아직 실전 연동되지 않는다).
class_name PlayerRecoveryRules
extends Resource

@export_group("포션 (combat.md 5-4장, economy-foundation.md 5-1장 POT-HP 공통 규칙)")
@export var potion_heal_percent: float = 0.30  ## 최대 HP 대비 회복량
@export var potion_cooldown_sec: float = 8.0  ## 전 티어 공통 쿨다운
@export var potion_boss_cap: int = 5  ## 보스 전투 1회당 하드 캡 (economy-foundation.md 5-2장)

@export_group("자연 회복 (combat.md 5-4장 — 전투 이탈 시)")
@export var natural_regen_delay_sec: float = 5.0  ## 마지막 전투 행동 후 대기 시간
@export var natural_regen_percent_per_sec: float = 0.02  ## 최대 HP 대비 초당 회복량
