## 스탯 성장 공식 상수 데이터 (Resource) — M3 B-2.
##
## m3-leveling-spec.md 5장(growth.md 1-2·2·3장)의 기획 수치를 필드화한다. 직업 무관 공통
## 상수(초기 스탯·모험가 성장치·파생 공식 계수·동렙 B급 장비 기준선)를 한곳에 모아 직업별
## JobGrowthData와 조합해 StatGrowthCalculator가 순수 함수로 스탯을 계산한다. 밸런스 조정은
## 코드 수정 없이 이 .tres만 바꾸면 반영된다(CLAUDE.md "기획 수치 하드코딩 금지").
##
## [장비 기준선 주의 — 책임 분리(spec 5-2)] 공격력/방어력의 "무기·방어구 기여분"은 원래
## 아이템 시스템 몫이다. 그러나 M3 현재 인벤토리(InventoryComponent)가 플레이어 씬에
## 배선돼 있지 않아(장비 미착용), 검산표(spec 2-3, "동렙 B급 장비 착용" 기준)와 M2에서
## 승인된 전투 밸런스를 유지하려면 성장 계층이 이 B급 장비 곡선을 임시로 대신 공급해야
## 한다(기존 warrior_lv1_combatant_stats.tres가 Lv1 B급 착용 스냅샷을 담던 것의 레벨 확장).
## 향후 인벤토리 장비가 플레이어에 배선되면 이 gear_* 값을 0으로 두어 이중 계산을 막고,
## 무기·방어구 기여를 아이템 시스템으로 이관한다.
class_name StatGrowthFormula
extends Resource

@export_group("1차 스탯 (spec 5-1)")
## Lv1 초기 스탯(4종 동일).
@export var initial_stat: float = 8.0
## 모험가 구간(Lv1~전직 임계) 레벨당 4스탯 균등 성장치.
@export var adventurer_growth: float = 1.5

@export_group("파생 스탯 계수 (spec 5-2, growth.md 1-2)")
## 최대 HP = hp_base + 체력xhp_per_vit + 레벨xhp_per_level.
@export var hp_base: float = 50.0
@export var hp_per_vit: float = 10.0
@export var hp_per_level: float = 5.0
## 최대 MP = mp_base + 지력xmp_per_int + 레벨xmp_per_level.
@export var mp_base: float = 30.0
@export var mp_per_int: float = 5.0
@export var mp_per_level: float = 2.0
## 공격력 스탯 기여분 = 주스탯 x attack_per_main_stat.
@export var attack_per_main_stat: float = 2.0
## 방어력 스탯 기여분 = 체력 x defense_per_vit.
@export var defense_per_vit: float = 1.0

@export_group("동렙 B급 장비 기준선 (임시 — 인벤토리 배선 시 0 처리, 상단 주의 참고)")
## 무기 공격력 = weapon_attack_base + 레벨 x weapon_attack_per_level (spec 2-3, B급 x1.00).
@export var weapon_attack_base: float = 8.0
@export var weapon_attack_per_level: float = 1.6
## 방어구 4부위 방어 합 = armor_defense_base + 레벨 x armor_defense_per_level.
@export var armor_defense_base: float = 5.0
@export var armor_defense_per_level: float = 1.5
