## 전사 기본 공격(대검) 콤보 전체 구성 (Resource).
##
## m2-warrior-skills.md 2장 — 2타 콤보, 1타 후 0.6초 이내 재입력 시 2타 연결.
class_name WarriorComboData
extends Resource

@export var steps: Array[WarriorAttackStep] = []
@export var combo_window_sec: float = 0.6  ## 이전 타 입력 후 다음 타 연결을 허용하는 시간
