## 궁수 기본 공격(활 사격) 1타 분량의 규격 데이터 (Resource, M3 C-4).
##
## 전사 대검 콤보와 같은 기본 공격 파이프라인(WarriorComboData.steps)을 쓰면서, 근접
## 히트박스 대신 화살 투사체를 발사한다는 점만 다르다 — arrow가 할당돼 있으면
## PlayerController가 부채꼴 히트박스를 열지 않고 ArrowProjectile을 발사한다.
##
## 상속받은 hitbox_range_tiles/hitbox_angle_deg는 원거리 기본 공격에서 쓰지 않으므로
## .tres에서 0으로 둔다(안 쓰는 필드 그룹을 남겨 두는 WarriorSkillData와 동일한 관례).
## damage_coefficient·hitstop_preset은 그대로 유효하다 — 화살 명중 시 PlayerAttackResolver가
## 이 필드를 읽어 데미지와 히트피드백을 결정한다(근접과 동일한 duck-typing 계약).
class_name ArcherAttackStep
extends WarriorAttackStep

## 이 타에서 발사할 화살 규격. null이면 근접 히트박스 경로로 되돌아간다.
@export var arrow: ArrowSpec
