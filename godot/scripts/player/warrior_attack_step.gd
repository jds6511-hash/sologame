## 기본 공격 콤보 1타 분량의 판정·모션 데이터 (Resource).
##
## m2-warrior-skills.md 2장 "대검 2타 콤보" 표의 열을 그대로 필드화했다.
## 데미지 실적용(CB-3)·히트스톱 실연출(CB-7)은 별도 태스크 담당이며,
## 본 리소스는 그 태스크가 참조할 판정 규격만 제공한다.
class_name WarriorAttackStep
extends Resource

@export var damage_coefficient: float = 1.0  ## 스킬 계수 (CB-3 데미지 공식 입력값)
@export var hitbox_range_tiles: float = 1.8  ## 판정 범위 반경(타일)
@export var hitbox_angle_deg: float = 90.0  ## 판정 부채꼴 각도(도)
@export var startup_sec: float = 0.15  ## 선딜
@export var active_sec: float = 0.10  ## 판정 지속
@export var recovery_sec: float = 0.25  ## 후딜
## combat.md 5-3장 히트스톱 프리셋 이름 — CB-7 HitFeedback 모듈이 이 값으로 프리셋을 선택한다.
@export_enum("약", "중", "강") var hitstop_preset: String = "약"


## 이 타의 총 모션 시간(선딜+판정+후딜)
func get_total_motion_sec() -> float:
	return startup_sec + active_sec + recovery_sec
