## 직업별 1차 스탯 성장 배분 데이터 (Resource) — M3 B-2.
##
## m3-leveling-spec.md 5-1·7-3장(growth.md 2-1 배분표)을 필드화한다. 레벨업마다 1차 스탯
## 합계가 +6.0 오르며, 그 6.0을 직업이 힘/민첩/지력/체력에 어떻게 나눠 갖는지를 담는다.
## 주스탯(main_stat)은 공격력 = 무기 + 주스탯x2에서 쓰는 스탯을 지정한다(전사=힘, 궁수=민첩).
##
## 모험가(Lv1~10 균등 성장)도 이 리소스로 표현한다(4스탯 모두 1.5). 전직 임계
## transition_level(전사/궁수 10)까지는 모험가 배분, 그 이후 직업 배분이 적용된다
## (실제 계산은 StatGrowthCalculator, spec 5-1 순수 함수).
class_name JobGrowthData
extends Resource

## 공격력에 기여하는 주스탯(공식: 무기 공격력 + 주스탯x2, spec 5-2).
enum MainStat { STR, AGI, INT, VIT }

@export var job_id: StringName = &""
@export var display_name: String = ""
@export var main_stat: MainStat = MainStat.STR

@export_group("레벨당 성장 배분 (합 6.0 — spec 7-3 검증)")
@export var growth_str: float = 1.5
@export var growth_agi: float = 1.5
@export var growth_int: float = 1.5
@export var growth_vit: float = 1.5

## 이 레벨까지는 모험가 균등 배분, 이후부터 위 직업 배분이 적용된다(spec 5-1).
@export var transition_level: int = 10


## 레벨당 성장 배분 합계. spec 7-3 검증용(전 직업 6.0이어야 한다).
func total_growth() -> float:
	return growth_str + growth_agi + growth_int + growth_vit


## 성장 배분 합이 6.0인지 검증(spec 2장 "전 직업 +6.0/레벨" 공정성).
func is_valid() -> bool:
	return is_equal_approx(total_growth(), 6.0)


## 지정 주스탯의 레벨당 배분치(공격력 계산에서 곱할 스탯 선택용).
func growth_for(stat: MainStat) -> float:
	match stat:
		MainStat.STR:
			return growth_str
		MainStat.AGI:
			return growth_agi
		MainStat.INT:
			return growth_int
		_:
			return growth_vit
