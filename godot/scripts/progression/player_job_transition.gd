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
## 궁수 등 다른 직업도 그대로 받는다(궁수 스킬 구현·전직 연결은 C-4).
##
## 시작 흐름(디렉터 확정): 게임은 jobs.md 1장 정식 흐름대로 **모험가(미전직)로 시작**해
## Lv10에 전직한다 — player.tscn은 initial_job_id를 비워 두고 모험가 공용 3종만 배선한다.
## initial_job_id에 직업을 넣으면 그 직업으로 이미 전직된 상태로 시작하는 디버그 직행
## 경로가 되며(디버그 전투장 전용), 이때 성장 배분·스킬 로드아웃까지 실제로 적용한다.
class_name PlayerJobTransition
extends Node

## Lv10(전직 임계) 도달로 전직이 가능해졌을 때 1회 발신 — B-4 HUD "전직 가능" 표시용.
signal transition_became_available(level: int)
## 전직 완료 시 새 직업 id를 실어 발신 — HUD·스마트 드랍·도감 후속 훅.
signal job_changed(job_id: StringName)

const ADVENTURER_JOB_ID := &"adventurer"
const DEFAULT_TRANSITION_LEVEL := 10
## 전직 실행 임시 키의 시작 키코드 — available_jobs 순서대로 F11, F12, ... 에 대응한다.
## 정식 전직 절차는 "도시 전직 기관 + 전직 시험 퀘스트"(jobs.md 6장)이고 그 UI/NPC 경로는
## 후속 작업이므로, 그전까지 전직을 실제로 실행할 수 있는 최소 경로로 둔다. 함수키를 raw
## keycode로 처리해 게임플레이 입력과 겹치지 않게 하고(debug_combat_arena.gd와 동일 방식),
## 디버그 전투장이 이미 쓰는 F1~F10 뒤로 배치해 그쪽과도 충돌하지 않는다.
const DEBUG_TRANSITION_FIRST_KEYCODE := KEY_F11

## 전직 가능한 1차 직업 목록(모험가 -> 선택). 데이터로만 추가하면 직업이 늘어난다.
@export var available_jobs: Array[JobDefinition] = []
## 디버그 직행 시작용 직업 id. 비우면 정식 흐름대로 모험가(미전직)로 시작해 Lv10에 전직
## 가능해진다(게임 기본값). 값이 있으면 그 직업으로 "이미 전직된" 상태로 시작하며 성장
## 배분과 스킬 로드아웃을 실제로 적용한다 — 단 전직 절차를 밟은 것이 아니므로 전직 보너스
## 스킬 포인트는 지급하지 않고 스탯 재계산도 하지 않는다(Lv1 초기 스냅샷 유지).
@export var initial_job_id: StringName = &""
## 전직 가능 시 콘솔 안내와 F11~ 직업 선택 키를 활성화할지(정식 전직 UI 이전의 임시 경로).
@export var debug_transition_keys_enabled: bool = true

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
	var initial_def := _find_job(initial_job_id)
	if initial_def != null:
		_start_as_job(initial_def)
	elif _progression:
		_update_availability(_progression.current_level)


## 디버그 직행 시작 — 전직 절차를 밟지 않고 해당 직업 상태로 시작한다. 성장 배분 전환과
## 스킬 로드아웃 적용만 하고, 스탯 재계산·전직 보너스 포인트는 건너뛴다(Lv1 스냅샷을 그대로
## 두는 PlayerStatGrowth 규약 준수 — Lv1은 모험가/직업 배분 결과가 동일하므로 정합도 유지).
func _start_as_job(job_def: JobDefinition) -> void:
	if _stat_growth and job_def.growth:
		_stat_growth.job = job_def.growth
	_apply_loadout(job_def)
	current_job_id = job_def.job_id
	is_transitioned = true


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
		_print_transition_guide(level)


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
	_apply_loadout(job_def)

	current_job_id = job_id
	is_transitioned = true
	transition_available = false
	job_changed.emit(job_id)
	print("[전직] %s 전직 완료 — 스킬 슬롯 개방·스킬 포인트 +2." % job_def.display_name)
	return true


## 승계형 스킬 슬롯 개방과 직업 무기(기본 공격 콤보) 교체를 부모 컨트롤러에 위임한다.
## 자식 _ready(직행 시작 경로)에서도 호출되는데, 그 시점 부모의 @onready 참조는 아직
## 비어 있다 — apply_transition_loadout은 슬롯 대입과 쿨다운 초기화만 하고 진행 중 동작
## 정리는 상태 확인 후에만 하므로(시작 시 전부 정지 상태) 안전하다.
func _apply_loadout(job_def: JobDefinition) -> void:
	if _controller and _controller.has_method("apply_transition_loadout"):
		_controller.apply_transition_loadout(job_def.skill_loadout(), job_def.basic_combo)


## available_jobs의 index번째 직업으로 전직을 실행한다(전직 실행 키·프로그램 경로 공용).
## 목록 범위를 벗어나거나 조건 미충족이면 false.
func request_transition_by_index(index: int) -> bool:
	if index < 0 or index >= available_jobs.size():
		return false
	var job_def := available_jobs[index]
	if job_def == null:
		return false
	return perform_transition(job_def.job_id)


## 전직 실행 임시 키 처리(F11~) — 전직 가능 상태에서만 반응한다.
func _unhandled_key_input(event: InputEvent) -> void:
	if not debug_transition_keys_enabled or not transition_available:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed() or key_event.is_echo():
		return
	var index: int = key_event.keycode - DEBUG_TRANSITION_FIRST_KEYCODE
	if index >= 0 and index < available_jobs.size():
		request_transition_by_index(index)


## 전직 가능해진 순간의 콘솔 안내 — 정식 전직 UI가 없는 동안 플레이어(디렉터)가 전직을
## 실제로 실행할 수 있게 선택 키를 함께 알린다.
func _print_transition_guide(level: int) -> void:
	var text := "[전직] Lv%d 도달 — 1차 전직이 가능합니다." % level
	if debug_transition_keys_enabled:
		for i in available_jobs.size():
			var job_def := available_jobs[i]
			if job_def == null:
				continue
			var key_name := OS.get_keycode_string(DEBUG_TRANSITION_FIRST_KEYCODE + i)
			text += "\n  %s 키 = %s 전직" % [key_name, job_def.display_name]
	print(text)


## 현재 직업의 전직 지급 무기(jobs.md 6장). 인벤토리/스마트 드랍 연동은 M3 범위 밖 — 후속 훅용.
func granted_weapon() -> ItemData:
	var job_def := _find_job(current_job_id)
	return job_def.granted_weapon if job_def != null else null


func _current_level() -> int:
	return _progression.current_level if _progression else 1
