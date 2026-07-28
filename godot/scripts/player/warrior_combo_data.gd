## 전사 기본 공격(대검) 콤보 전체 구성 (Resource).
##
## m2-warrior-skills.md 2장 — 2타 콤보, 1타 후 0.6초 이내 재입력 시 2타 연결.
class_name WarriorComboData
extends Resource

@export var steps: Array[WarriorAttackStep] = []
@export var combo_window_sec: float = 0.6  ## 이전 타 입력 후 다음 타 연결을 허용하는 시간
## 회피(Space) 방향을 조준 반대 방향(후방 점프)으로 바꿀지 — 궁수 활 콤보 전용
## (m3-archer-skills.md 1·2-2장 "후방 점프 회피 = 카이팅 그 자체"). 전사 대검은 false로
## 기존 입력 방향 대시를 유지한다. 무기(기본 공격 콤보)가 전직 시 함께 교체되므로 회피
## 스타일도 자동으로 따라간다.
@export var dodge_backward: bool = false
