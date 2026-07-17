## 전사 스킬 슬롯 1개 분량의 규격 데이터 (Resource, CB-2).
##
## m2-warrior-skills.md 3~5장의 스킬별 계수·쿨다운·MP·판정·모션 시간을 그대로 필드화했다.
## 스킬 유형(SkillType)에 따라 사용하는 필드 그룹이 다르며(예: BUFF_HEAL은 판정/이동 필드를
## 쓰지 않는다), 스킬 종류가 늘어날 때마다 새 Resource 클래스를 만드는 대신 단일 스키마로
## 통합했다 — scripts/ai/monster_stats_data.gd(종별로 안 쓰는 필드 그룹이 있는 것과 동일한
## 기존 코드베이스 관례)를 그대로 따른 선택이다.
##
## PlayerController가 이 리소스를 소비해 판정 히트박스를 열고, attack_hit 시그널로
## (step, target)을 emit하면 PlayerAttackResolver가 damage_coefficient/hitstop_preset
## 필드를 그대로 읽어 데미지·히트피드백을 적용한다(WarriorAttackStep과 동일한 duck-typing
## 계약 — combat.md 9-1장 "프리셋만 고르면 되는" 공용 파이프라인 원칙).
class_name WarriorSkillData
extends Resource

enum SkillType {
	INSTANT,  ## 즉발 (강타, 분쇄 베기)
	CHARGE,  ## 차징(홀드) — 우클릭 차지 강타 전용
	DASH,  ## 이동기 (질주, 돌격)
	BUFF_HEAL,  ## 버프·힐 (응급 처치, 결의의 외침) — 판정 없는 자기 대상 스킬
	ULTIMATE,  ## 궁극기 (대지 분쇄)
}

@export var skill_name: String = ""
@export var skill_type: SkillType = SkillType.INSTANT
@export var cooldown_sec: float = 5.0
@export var mp_cost_percent: float = 0.08  ## 최대 MP 대비 비율 (combat.md 7장 규격)

@export_group("판정/모션 — INSTANT·DASH·ULTIMATE·CHARGE 공통 (BUFF_HEAL은 미사용)")
@export var damage_coefficient: float = 1.0  ## CB-3 데미지 공식 입력값 (CHARGE는 런타임에 덮어씀)
@export var hitbox_range_tiles: float = 2.0
## 판정 부채꼴 각도(도). 360=원형 광역(대지 분쇄). 돌격처럼 문서가 "직선 폭 N타일"로
## 규정한 경우는 폭에 상응하는 좁은 각도로 근사한다(PlayerController._build_sector_polygon
## 재사용 — 별도 사각형 판정 형태를 새로 만들지 않기 위한 단순화, 값은 .tres에서 조정 가능).
@export var hitbox_angle_deg: float = 120.0
@export var startup_sec: float = 0.25
@export var active_sec: float = 0.1
@export var recovery_sec: float = 0.3  ## CHARGE는 런타임에 홀드 비율로 덮어씀
@export_enum("약", "중", "강") var hitstop_preset: String = "중"
## 판정 진행 중 경직을 무시하는 슈퍼아머 여부 (combat.md 5-1 "슈퍼아머 스킬 시전 중" —
## 차지 강타·대지 분쇄 전용, m2-warrior-skills.md 3·5-4장). STARTUP~ACTIVE 구간에 적용된다.
@export var self_superarmor_during_cast: bool = false

@export_group("이동기 전용 (질주·돌격) — combat.md 3장 '이동기는 무적 없음'")
@export var dash_distance_tiles: float = 0.0
@export var dash_duration_sec: float = 0.0

@export_group("돌격 전용 부가효과 — 명중 시 몬스터 스턴/넉백")
## 몬스터 측 MobStaggerComponent 연동이 아직 어떤 몬스터 씬에도 배선되지 않아(ai-dev 후속
## 과제), 이 필드는 데이터로만 노출하고 실제 부가효과 적용은 후속 통합 패스에서 처리한다.
@export var on_hit_stun_sec: float = 0.0

@export_group("버프·힐 전용 (응급 처치·결의의 외침) — 판정 없는 자기 대상 스킬")
@export var self_heal_percent: float = 0.0
@export var grants_superarmor_sec: float = 0.0
@export var defense_buff_percent: float = 0.0
@export var defense_buff_duration_sec: float = 0.0

@export_group("차지 강타 전용 (우클릭) — 홀드 시간 선형 비례 계수·후딜")
@export var charge_min_hold_sec: float = 0.3
@export var charge_max_hold_sec: float = 1.2
@export var charge_min_coefficient: float = 1.6
@export var charge_max_coefficient: float = 3.0
@export var charge_min_recovery_sec: float = 0.5
@export var charge_max_recovery_sec: float = 0.7


## 이 스킬의 ACTIVE 단계 지속시간. DASH는 돌진 이동 시간을 판정 지속으로 쓴다.
func get_active_duration_sec() -> float:
	if skill_type == SkillType.DASH:
		return dash_duration_sec
	return active_sec
