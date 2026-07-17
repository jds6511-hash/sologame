## 전투 참여자(공격자/피격자)의 최소 전투 스탯 데이터 (Resource).
##
## growth.md 1-2장 파생 스탯 공식(공격력 = 무기 공격력 + 주스탯x2, 방어력 등)의
## "결과값"을 담는 그릇이다. 레벨업에 따른 성장 계산 자체는 이 태스크의 범위 밖이므로—
## 아직 레벨업 성장 시스템(자동 성장 곡선)이 구현되지 않았다— 지금은 growth.md 2-2장
## 기준선 검산표의 Lv1 고정값을 담은 .tres(godot/data/combat/)로 정식화해 두고, 레벨업
## 성장 시스템이 구현되면 이 리소스를 매 레벨 동적으로 갈아끼우거나 채워 넣는 방식으로
## 대체하면 된다 (M2 Phase3: PlayerStatsComponent가 이 리소스를 HP/MP 실체 데이터로 사용).
class_name CombatantStats
extends Resource

@export var attack_power: float = 0.0  ## growth.md 1-2장: 무기 공격력 + 주스탯x2
@export var agility: float = 0.0  ## 치명타 확률 계산용 (combat.md 6장)
@export var defense: float = 0.0  ## growth.md 1-2장: 방어구 방어 합 + 체력x1
@export var max_hp: float = 0.0  ## growth.md 1-2장: 50 + 체력x10 + 레벨x5
@export var max_mp: float = 0.0  ## growth.md 1-2장: 30 + 지력x5 + 레벨x2
