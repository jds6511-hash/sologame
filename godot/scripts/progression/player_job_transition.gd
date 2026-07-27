## 전직 처리 노드 (M3 B-5) — 모험가 -> 1차 직업 전환 프레임워크.
##
## jobs.md 6장(전직 절차·보상)·m3-leveling-spec.md 3-3·8-2장(전직 임계 다중 레벨업 처리)을
## 구현한다. Lv10(전직 임계) 도달 시 "전직 가능" 플래그를 세우고(레벨업 루프 정지 없음 — spec
## 권장안), 전직 실행 시 다음을 일괄 처리한다:
##   ① 직업 성장 배분 전환 후 스탯 재계산(현재 레벨로 소급 — PlayerStatGrowth.recompute_stats)
##   ② 전직 보너스 스킬 포인트 +2 지급(PlayerSkillPoints.grant_transition_points)
##   ③ 승계형 스킬 슬롯 개방(PlayerController.apply_transition_loadout)
##   ④ 직업 전용 무기(기본 공격 콤보) 교체(같은 로드아웃 경로)
##
## Player 씬의 자식 노드("PlayerJobTransition")로 배치하며, 형제 PlayerProgression/
## PlayerStatGrowth/PlayerSkillPoints와 부모 PlayerController를 노드 경로로 참조한다(다른
## progression 노드와 동일 배치 패턴).
##
## 프레임워크는 직업 무관하게 일반화돼 있다 — available_jobs에 JobDefinition을 추가하면
## 궁수 등 다른 직업도 그대로 받는다(궁수 스킬 구현·전직 연결은 C-4). initial_job_id로 "이미
## 전직된 상태"로 시작할 수 있어 M2 전사 직행 셋업과 호환된다(실제 게임의 모험가 시작 흐름
## 전환은 디렉터 결정 사항).
class_name PlayerJobTransition
extends Node

## Lv10(전직 임계) 도달로 전직이 가능해졌을 때 1회 발신 — B-4 HUD "전직 가능" 표시용.
signal transition_became_available(level: int)
## 전직 완료 시 새 직업 id를 실어 발신 — HUD·스마트 드랍·도감 후속 훅.
signal job_changed(job_id: StringName)

const ADVENTURER_JOB_ID := &"adventurer"
const DEFAULT_TRANSITION_LEVEL := 10

## 전직 가능한 1차 직업 목록(모험가 -> 선택). 데이터로만 추가하면 직업이 늘어난다.
@export var available_jobs: Array[JobDefinition] = []
## 시작 직업 id. 비우면 모험가(미전직)로 시작해 Lv10에 전직 가능해진다. 값이 있으면 그
## 직업으로 "이미 전직된" 상태로 시작한다(M2 전사 직행 호환 — 전직 로직은 실행하지 않고
## 상태만 반영하며, 스탯/스킬/무기는 씬에 이미 세팅돼 있다고 본다).
@export var initial_job_id: StringName = &""

var current_job_id: StringName = ADVENTURER_JOB_ID
var is_transitioned: bool = false
var transition_available: bool = false

@onready var _progression: PlayerProgression = get_node_or_null("../PlayerProgression")
@onready var _stat_growth: PlayerStatGrowth = get_node_or_null("../PlayerStatGrowth")
@onready var _skill_points: PlayerSkillPoints = get_node_or_null("../PlayerSkillPoints")
@onready var _controller: Node = get_parent()


func _ready() -> void:
	if _progression:
		_progression.leveled_up.connect(_on_leveled_up)
	if initial_job_id != &"" and _find_job(initial_job_id) != null:
		## 이미 전직된 상태로 시작 — 상태만 반영(전직 로직·재계산은 실행하지 않는다).
		current_job_id = initial_job_id
		is_transitioned = true
	elif _progression:
		_update_availability(_progression.current_level)


func _on_leveled_up(new_level: int) -> void:
	_update_availability(new_level)


## 전직 임계(Lv10) 도달 시 전직 가능 플래그를 세운다. 다중 레벨업이 임계를 건너뛰어도
## 레벨마다 leveled_up가 발신되므로(PlayerProgression while 루프) 임계 통과 순간 플래그가
## 서고, 실제 스탯 소급은 전직 실행 시 recompute_stats(현재 레벨)로 자동 반영된다(spec 3-3).
func _update_availability(level: int) -> void:
	if is_transitioned or transition_available:
		return
	if level >= _transition_level():
		transition_available = true
		transition_became_available.emit(level)


## 사용 가능한 직업 정의 중 첫 전직 임계 레벨(전 직업 10). 목록이 비면 기본 10.
func _transition_level() -> int:
	for job_def in available_jobs:
		if job_def != null:
			return job_def.transition_level()
	return DEFAULT_TRANSITION_LEVEL


func _find_job(job_id: StringName) -> JobDefinition:
	for job_def in available_jobs:
		if job_def != null and job_def.job_id == job_id:
			return job_def
	return null


## 지금 이 직업으로 전직할 수 있는지 — 전직 가능(Lv10+)이고, 아직 미전직이며, 목록에 있는 직업.
func can_transition(job_id: StringName) -> bool:
	return transition_available and not is_transitioned and _find_job(job_id) != null


## 전직을 실행한다. 성공 시 스탯 재계산·스킬 포인트 지급·슬롯 개방·무기 교체를 적용하고 true.
## 조건 미충족(레벨 미달·이미 전직·미등록 직업)이면 아무것도 바꾸지 않고 false.
func perform_transition(job_id: StringName) -> bool:
	if not can_transition(job_id):
		return false
	var job_def := _find_job(job_id)

	## ① 성장 배분 전환 후 스탯 재계산(현재 레벨로 소급 — spec 3-3, jobs.md 6장 "즉시 재계산").
	if _stat_growth and job_def.growth:
		_stat_growth.job = job_def.growth
		_stat_growth.recompute_stats(_current_level())

	## ② 전직 보너스 스킬 포인트 +2(spec 6-1).
	if _skill_points:
		_skill_points.grant_transition_points()

	## ③ 승계형 스킬 슬롯 개방 + ④ 직업 무기(기본 공격 콤보) 교체.
	if _controller and _controller.has_method("apply_transition_loadout"):
		_controller.apply_transition_loadout(job_def.skill_loadout(), job_def.basic_combo)

	current_job_id = job_id
	is_transitioned = true
	transition_available = false
	job_changed.emit(job_id)
	return true


## 현재 직업의 전직 지급 무기(jobs.md 6장). 인벤토리/스마트 드랍 연동은 M3 범위 밖 — 후속 훅용.
func granted_weapon() -> ItemData:
	var job_def := _find_job(current_job_id)
	return job_def.granted_weapon if job_def != null else null


func _current_level() -> int:
	return _progression.current_level if _progression else 1
