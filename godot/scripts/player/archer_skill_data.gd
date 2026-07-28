## 궁수 스킬 슬롯 1개 분량의 규격 데이터 (Resource, M3 C-4).
##
## m3-archer-skills.md 4·5장(속사·곡예 사격·매의 눈·관통 폭사·조준 모드)의 궁수 고유 항목만
## 추가하고, 계수/쿨다운/MP/모션 시간처럼 전 직업 공통인 항목은 WarriorSkillData를 그대로
## 상속해 재사용한다. 상속 덕분에 JobDefinition의 스킬 슬롯(WarriorSkillData 타입)과
## PlayerController·PlayerAttackResolver의 기존 duck-typing 계약에 그대로 들어간다 —
## 전직 프레임워크(B-5)나 스킬 강화(B-3, skill_name을 skill_id로 쓴다) 수정이 불필요하다.
##
## 스킬 유형은 상속받은 SkillType을 재사용한다:
##   속사 = INSTANT(+투사체 3발) / 곡예 사격 = DASH(+투사체 1발) /
##   매의 눈 = BUFF_HEAL(궁수 버프 필드) / 관통 폭사 = ULTIMATE(+무제한 관통 투사체) /
##   조준 모드 = 우클릭 슬롯에 두고 is_aim_stance로 "스탠스"임을 표시(전사 차지와 분기).
class_name ArcherSkillData
extends WarriorSkillData

@export_group("원거리 투사체 (속사·곡예 사격·관통 폭사 — 4장)")
## 발사할 화살 규격. null이면 근접 판정 스킬로 취급한다(모험가 공용 강타 등).
@export var arrow: ArrowSpec
## 1회 시전당 발사 수 — 속사는 3발(4-1장), 나머지는 1발.
@export var projectile_count: int = 1
## 연사 간격(초) — 속사 0.08초. 1발 스킬에서는 쓰지 않는다.
@export var projectile_interval_sec: float = 0.0

@export_group("조준 모드 (우클릭 스탠스 — 5장)")
## true면 이 슬롯은 전사식 차지(홀드→발사)가 아니라 궁수식 조준 스탠스로 동작한다.
@export var is_aim_stance: bool = false
## 조준 중 이동 속도 배율(×0.4 — "느리지만 멈추지는 않음").
@export var aim_move_speed_multiplier: float = 0.4
## 조준 중 좌클릭 사격에 쓰이는 화살(관통 3체·사거리 ×1.5·속도 20타일·초).
@export var aimed_arrow: ArrowSpec
## 조준 중 사격 사이클(초) — 0.65초(hipfire 0.5초보다 느린 정조준의 대가).
@export var aim_shot_cycle_sec: float = 0.65

@export_group("궁수 자기 버프 (매의 눈 — 4-3장)")
## 치명타 확률 가산(0.15 = +15%p). combat.md 6장 상한 40% 안에서 작동한다.
@export var crit_chance_bonus: float = 0.0
## 기본/스킬 사거리 가산(타일).
@export var attack_range_bonus_tiles: float = 0.0
## 공격 속도 가산 비율(0.15 = +15%) — 기본 공격 사이클이 그만큼 빨라진다.
@export var attack_speed_bonus_percent: float = 0.0
## 버프 지속 시간(초). 0이면 궁수 버프가 아니다(적용하지 않음).
@export var buff_duration_sec: float = 0.0
