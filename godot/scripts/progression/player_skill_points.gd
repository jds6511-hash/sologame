## 스킬 포인트 경제 상태 노드 (M3 B-3) — m3-leveling-spec.md 6장.
##
## B-1 PlayerProgression의 leveled_up 시그널을 구독해 레벨업마다 포인트를 지급하고,
## 전직 보너스는 B-5(전직 처리)가 grant_transition_points()를 호출해 지급한다. 잔여 포인트와
## 스킬별 강화 레벨을 이 노드가 권위 상태로 들고, 강화 요청(try_upgrade_skill)을 비용 차감과
## 함께 처리한다. HUD(B-4)는 points_changed·skill_upgraded 시그널을 구독해 표시를 갱신한다.
##
## Player 씬의 자식 노드("PlayerSkillPoints")로 배치하며, 형제 PlayerProgression을 노드 경로로
## 참조한다(PlayerStatGrowth와 동일 구독 패턴).
##
## 책임 경계: 포인트/강화 상태·실제 지출 장부·API·시그널을 담당한다. B-5가 새 로드아웃의
## 스킬 목록으로 교체 스킬 환급을 요청하고 전직 보너스를 지급한 뒤 슬롯을 교체한다.
## 리스펙(상시 유료 초기화, spec 6-3)은 M3 범위 밖이라 구현하지 않는다.
##
## 스킬 식별(spec 6-3 Dictionary { skill_id: level }): skill_id는 상위 계약이며, 현재 전사
## 스킬은 WarriorSkillData.skill_name을 그대로 id로 쓴다(별도 id 필드를 추가해 원본 .tres·공용
## WarriorSkillData 스키마를 건드리지 않기 위한 선택 — 표시명이 곧 고유 식별자). API는
## StringName skill_id로 일반화해 두어 직업/스킬이 늘어도 그대로 재사용한다.
class_name PlayerSkillPoints
extends Node

## 잔여/누적 포인트가 바뀔 때 발신(지급·강화 차감 후) — B-4 HUD 갱신용.
signal points_changed(available_points: int, spent_points: int)
## 스킬이 강화되어 레벨이 오를 때 발신 — B-4 HUD 갱신용.
signal skill_upgraded(skill_id: StringName, new_level: int)

## 지급/비용/계수 규칙(spec 7-4). 밸런스 값은 전부 이 리소스에 있다.
@export var rule: SkillPointRule

var available_points: int = 0  ## 사용 가능한 잔여 포인트
var spent_points: int = 0  ## 강화에 쓴 누적 포인트

## 스킬별 현재 강화 레벨 { StringName skill_id: int(1~max) }. 미등록 스킬은 Lv1로 간주한다
## (계수 배율 1.0). 강화된 스킬만 항목이 생긴다.
var _skill_levels: Dictionary = {}
## 현재 규칙에서 비용을 재계산하지 않고 실제 지출액을 환급한다.
var _skill_costs: Dictionary = {}

@onready var _progression: PlayerProgression = get_node_or_null("../PlayerProgression")


func _ready() -> void:
	if _progression:
		_progression.leveled_up.connect(_on_leveled_up)


# --- 포인트 지급 (spec 6-1) ---


## 레벨업 1회당 points_per_level 지급. 다중 레벨업은 레벨마다 leveled_up가 발신되어
## 이 함수가 각각 호출된다.
func _on_leveled_up(_new_level: int) -> void:
	_grant_points(rule.points_per_level)


## 전직 완료 시 B-5가 호출하는 공개 API — 전직 보너스 포인트 지급(spec 6-1, 전직 1회당 +2).
func grant_transition_points() -> void:
	_grant_points(rule.points_per_transition)


func _grant_points(amount: int) -> void:
	if amount <= 0:
		return
	available_points += amount
	points_changed.emit(available_points, spent_points)


## 지급받은 총 포인트(잔여 + 사용). spec 6-1 순수식 (level-1) + 2 x 전직횟수와 대응한다.
func earned_points() -> int:
	return available_points + spent_points


# --- 스킬 강화 (spec 6-2, 6-3) ---


## 스킬의 현재 강화 레벨(미등록 = Lv1).
func get_skill_level(skill_id: StringName) -> int:
	return int(_skill_levels.get(skill_id, 1))


## 다음 레벨로 강화 가능한지 — 만렙이 아니고 잔여 포인트가 비용 이상인지.
func can_upgrade_skill(skill_id: StringName, is_ultimate: bool) -> bool:
	var cost := rule.upgrade_cost(get_skill_level(skill_id), is_ultimate)
	return cost >= 0 and available_points >= cost


## 스킬을 한 단계 강화한다. 성공 시 비용을 차감하고 레벨을 올린 뒤 시그널을 발신하고 true를
## 돌려준다. 만렙이거나 잔여 포인트가 부족하면 아무것도 바꾸지 않고 false를 돌려준다.
func try_upgrade_skill(skill_id: StringName, is_ultimate: bool) -> bool:
	if not can_upgrade_skill(skill_id, is_ultimate):
		return false
	var cost := rule.upgrade_cost(get_skill_level(skill_id), is_ultimate)
	var new_level := get_skill_level(skill_id) + 1
	_skill_levels[skill_id] = new_level
	available_points -= cost
	spent_points += cost
	_skill_costs[skill_id] = int(_skill_costs.get(skill_id, 0)) + cost
	skill_upgraded.emit(skill_id, new_level)
	points_changed.emit(available_points, spent_points)
	return true


## 전직으로 사라지는 스킬만 초기화·환급한다. 공통 스킬 강화와 총 획득량은 유지한다.
func refund_unavailable_skills(available_ids: Array[StringName]) -> void:
	var refund := 0
	for skill_id in _skill_levels.keys():
		if skill_id in available_ids:
			continue
		refund += int(_skill_costs.get(skill_id, 0))
		_skill_levels.erase(skill_id)
		_skill_costs.erase(skill_id)
	if refund > 0:
		available_points += refund
		spent_points -= refund
		points_changed.emit(available_points, spent_points)


# --- 계수 적용 (spec 6-2) — 전투/버프 실행 경로가 참조 ---


## 스킬의 현재 강화 레벨에 해당하는 계수 배율(1 + 8% x (level-1)).
func effective_multiplier(skill_id: StringName) -> float:
	return rule.coefficient_multiplier(get_skill_level(skill_id))


## base_coefficient("스킬 레벨 1 기준값")에 강화 배율을 곱한 최종 계수(원본 값 불변).
func effective_coefficient(base_coefficient: float, skill_id: StringName) -> float:
	return base_coefficient * effective_multiplier(skill_id)
