## 데미지 공식 상수 데이터 (Resource).
##
## combat.md 6장 "데미지 공식" 표의 상수를 그대로 필드화했다.
## DamageCalculator가 이 값을 입력으로 받아 공식을 계산하며, 밸런스 조정은
## 이 리소스(.tres) 값만 바꾸면 코드 수정 없이 반영된다.
class_name DamageFormulaData
extends Resource

## 치명타 배율 (고정값, combat.md 6장 — 실시간 액션에서 랜덤 폭사 방지 목적으로 고정)
@export var crit_multiplier: float = 1.5

## 치명타 발동 확률 = base_crit_chance + agility * crit_chance_per_agility (상한 crit_chance_cap)
@export var base_crit_chance: float = 0.05
@export var crit_chance_per_agility: float = 0.0005  ## 민첩 1당 +0.05%
@export var crit_chance_cap: float = 0.40

## 위치 보정 — combat.md 6장: "후방 공격 1.15(도적 계열 핵심 보너스), 그 외 1.0"
## 즉 후방 판정 보정은 도적 계열 전용 보너스이며, 그 외 직업은 항상 1.0을 쓴다.
@export var backattack_multiplier: float = 1.15
@export var default_position_multiplier: float = 1.0

## 랜덤 보정 범위 (균등 분포)
@export var random_variance_min: float = 0.95
@export var random_variance_max: float = 1.05
