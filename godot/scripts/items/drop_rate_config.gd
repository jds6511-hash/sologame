## 드랍률·골드 배율 정책 데이터 (Resource) — IT-2.
##
## economy-foundation.md 1-1장(골드 공식 배율)·2-5장(드랍률 표)의 수치를 그대로
## 필드화했다. "몬스터별" 수치가 아니라 일반/정예/보스 등급에 공통 적용되는 정책값이므로
## DropTableData(몬스터별 데이터)와 분리했다 — 기획 수치를 코드에 하드코딩하지 않기
## 위함(CLAUDE.md 공통 규칙). 값 변경 시 economy-designer 확인 후 이 리소스만 바꾸면 된다.
class_name DropRateConfig
extends Resource

@export_group("골드 배율 (1-1장)")
@export var gold_multiplier_elite: float = 6.0
@export var gold_multiplier_boss: float = 40.0
@export var gold_multiplier_boss_repeat: float = 0.5  ## 보스 반복 처치 인플레 방지

@export_group("재료·잡템 드랍 (2-5장)")
@export var material_chance_normal: float = 0.30
@export var material_chance_elite: float = 1.0
@export var material_chance_boss: float = 1.0
@export var material_count_normal: int = 1
@export var material_count_elite: int = 2
@export var material_count_boss: int = 4

@export_group("포션 현물 드랍 (2-5장)")
@export var potion_chance_normal: float = 0.02
@export var potion_chance_elite: float = 0.20
@export var potion_chance_boss: float = 1.0
@export var potion_count_normal: int = 1
@export var potion_count_elite: int = 1
@export var potion_count_boss: int = 3

@export_group("장비 드랍 확률 — 일반/정예 (2-5장, 등급별 독립 판정)")
@export var equip_c_chance_normal: float = 0.04
@export var equip_c_chance_elite: float = 0.12
@export var equip_b_chance_normal: float = 0.015
@export var equip_b_chance_elite: float = 0.08
@export var equip_a_chance_normal: float = 0.0015
@export var equip_a_chance_elite: float = 0.012
@export var equip_s_chance_normal: float = 0.0
@export var equip_s_chance_elite: float = 0.0005

@export_group("장비 드랍 확률 — 보스 확정 1개 (2-5장, B/A/S 중 1개 확정 배분)")
@export var equip_boss_chance_b: float = 0.70
@export var equip_boss_chance_a: float = 0.25
@export var equip_boss_chance_s: float = 0.05

@export_group("드랍 장비 슬롯 분포 (2-5장 — 무기 20 / 방어구 4부위 각 15 / 장신구 3부위 각 6.7)")
@export var slot_weight_weapon: float = 20.0
@export var slot_weight_armor_body: float = 15.0
@export var slot_weight_armor_leg: float = 15.0
@export var slot_weight_armor_head: float = 15.0
@export var slot_weight_armor_foot: float = 15.0
@export var slot_weight_ring: float = 13.4  ## 반지 2슬롯분(6.7 x 2) 합산 — equip_slot 값은 1종
@export var slot_weight_necklace: float = 6.7

@export_group("스마트 드랍 (jobs.md 5-2장 — M2는 전사 1직업 고정)")
## M2에는 직업 전환이 없어 "현재 직업 계열"을 고정값으로 둔다. 다른 직업이 추가되면
## 이 필드를 플레이어 직업 조회로 대체해야 한다(기획 필요 — 후속 마일스톤).
@export var current_job_weapon_series_prefix: String = "WPN-GS-"
