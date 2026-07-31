## 전투 참여자(공격자/피격자)의 최소 전투 스탯 데이터 (Resource).
##
## growth.md 1-2장 파생 스탯 공식(공격력 = 무기 공격력 + 주스탯x2, 방어력 등)의
## "결과값"을 담는 그릇이다. 레벨업에 따른 성장 계산 자체는 이 태스크의 범위 밖이므로—
## 아직 레벨업 성장 시스템(자동 성장 곡선)이 구현되지 않았다— 지금은 growth.md 2-2장
## 기준선 검산표의 Lv1 고정값을 담은 .tres(godot/data/combat/)로 정식화해 두고, 레벨업
## 성장 시스템이 구현되면 이 리소스를 매 레벨 동적으로 갈아끼우거나 채워 넣는 방식으로
## 대체하면 된다 (M2 Phase3: PlayerStatsComponent가 이 리소스를 HP/MP 실체 데이터로 사용).
##
## **[런타임에 값이 덮어써지는 .tres는 반드시 resource_local_to_scene = true로 둔다]**
## 성장 계층(StatGrowthCalculator.apply)은 이 리소스의 필드를 in-place로 갈아끼운다. 그런데
## Godot은 .tres를 경로 단위로 캐시하므로, 씬이 파일 백업 리소스를 **직접** 물면 한 번의
## 재계산이 그 캐시 인스턴스를 영구히 오염시킨다 — 같은 프로세스에서 이후 만들어지는 모든
## 플레이어가 Lv1 스냅샷(공격 26.0/방어 14.0) 대신 Lv1 정밀값(25.6/14.5)을 보게 된다
## (씬 전환·월드 재진입에서 실제로 터지는 런타임 버그였다).
## `resource_local_to_scene = true`를 켜면 씬 인스턴스화 시점에 엔진이 사본을 만들고, 그 씬
## 안의 **모든** 참조를 같은 사본으로 리맵한다 — 파일은 "초기값 템플릿"이 되고 공유 참조
## 구조(AttackResolver·PlayerStats·PlayerStatGrowth가 한 인스턴스)는 그대로 유지된다.
## 검증: test/progression/test_shared_combat_stats_isolation.gd.
class_name CombatantStats
extends Resource

@export var attack_power: float = 0.0  ## growth.md 1-2장: 무기 공격력 + 주스탯x2
@export var agility: float = 0.0  ## 치명타 확률 계산용 (combat.md 6장)
@export var defense: float = 0.0  ## growth.md 1-2장: 방어구 방어 합 + 체력x1
@export var max_hp: float = 0.0  ## growth.md 1-2장: 50 + 체력x10 + 레벨x5
@export var max_mp: float = 0.0  ## growth.md 1-2장: 30 + 지력x5 + 레벨x2
