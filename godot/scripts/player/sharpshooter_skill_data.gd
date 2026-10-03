class_name SharpshooterSkillData
extends ArcherSkillData
## 명사수 전용 비용/집중 규격. 피해·투사체·회피는 기존 궁수 계약을 사용한다.

@export var focus_charge_cap: int = 15
@export var focus_cost: int = 0
@export var grants_breathing: bool = false
## 음수이면 기존 비율 MP 계산을 사용한다.
@export var fixed_mp_cost: int = -1
