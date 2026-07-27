## 스킬 포인트 경제 규칙 데이터 (Resource) — M3 B-3.
##
## m3-leveling-spec.md 6장·7-4장(growth.md 6장 원본)의 기획 수치를 필드화한다. 레벨업·전직
## 시 지급량, 스킬 강화 단계별 비용(일반/궁극기), 강화당 계수 상승률을 한곳에 모아
## PlayerSkillPoints가 순수 규칙으로 소비한다. 밸런스 조정은 코드 수정 없이 이 .tres만
## 바꾸면 반영된다(CLAUDE.md "기획 수치 하드코딩 금지").
##
## 지급(spec 6-1): 레벨당 +points_per_level, 전직 1회당 +points_per_transition.
## 강화 비용(spec 6-2): 일반 스킬 Lv1~5 각 단계 [1,1,2,4], 궁극기 Lv1~3 [3,3].
##   비용 배열의 원소 수가 곧 "만렙 스킬 레벨 - 1"이다(일반 4단계=Lv5, 궁극기 2단계=Lv3).
## 계수(spec 6-2): effective = base x (1 + coefficient_step_per_level x (skill_level - 1)).
##   base_coefficient(WarriorSkillData.damage_coefficient 등)는 "스킬 레벨 1 기준값"이며,
##   런타임에 이 배율을 곱해 최종 계수를 산출한다(원본 .tres 불변, 공용 리소스 오염 방지).
class_name SkillPointRule
extends Resource

@export_group("포인트 지급 (spec 6-1)")
@export var points_per_level: int = 1
@export var points_per_transition: int = 2

@export_group("스킬 강화 비용 (spec 6-2 — 단계별 비용, 원소 수 = 만렙레벨-1)")
## 일반 스킬 Lv1->2->3->4->5 각 단계 비용(풀업 합 8).
@export var normal_upgrade_costs: PackedInt32Array = [1, 1, 2, 4]
## 궁극기 Lv1->2->3 각 단계 비용(풀업 합 6).
@export var ultimate_upgrade_costs: PackedInt32Array = [3, 3]

@export_group("계수 상승 (spec 6-2)")
## 강화 1레벨당 계수 상승률(+8%/레벨).
@export var coefficient_step_per_level: float = 0.08


## 스킬 종류(일반/궁극기)에 해당하는 단계별 비용 배열.
func upgrade_costs(is_ultimate: bool) -> PackedInt32Array:
	return ultimate_upgrade_costs if is_ultimate else normal_upgrade_costs


## 이 스킬 종류의 만렙 스킬 레벨(일반 5, 궁극기 3). 시작 Lv1 + 강화 단계 수.
func max_skill_level(is_ultimate: bool) -> int:
	return 1 + upgrade_costs(is_ultimate).size()


## current_level -> current_level+1 강화 비용. 만렙(더 올릴 수 없음)이면 -1을 돌려준다.
## 비용 배열 인덱스는 current_level-1(Lv1->2가 index 0)이다.
func upgrade_cost(current_level: int, is_ultimate: bool) -> int:
	var costs := upgrade_costs(is_ultimate)
	var index := current_level - 1
	if index < 0 or index >= costs.size():
		return -1
	return costs[index]


## 스킬 레벨 -> 계수 배율(1 + step x (level-1)). Lv1=1.0, Lv2=1.08, Lv3=1.16 ...
func coefficient_multiplier(skill_level: int) -> float:
	return 1.0 + coefficient_step_per_level * float(skill_level - 1)
