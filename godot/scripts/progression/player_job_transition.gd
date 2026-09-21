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
## 2차 전직(Lv40, jobs.md 1장)도 같은 경로를 쓴다(M3 C-1): tier2_jobs에 상위 계통
## JobDefinition을 넣으면, 1차 전직을 마친 뒤 그 정의의 required_job_id가 현재 직업과 맞고
## transition_level_override(40)에 도달한 순간 다시 "전직 가능"이 서고 승계형 슬롯 교체가
## 그대로 적용된다. 정식 2차 전직 UI는 없으므로(직업 선택 화면은 1차 전용) 실행 경로는 F11~
## 디버그 키다 — Lv40 도달은 HUD의 Page Up 디버그 레벨 점프로 만든다.
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
## 2차 이상 상위 계통 직업 목록(검투사 등). 각 정의의 required_job_id가 현재 직업과 일치할
## 때만 후보가 되고, 임계 레벨은 transition_level_override(2차 Lv40)를 쓴다. 1차 직업 선택
## 화면은 available_jobs만 카드로 만들므로(ui: job_selection_screen.gd) 상위 계통을 이
## 목록으로 분리해 Lv10 선택 화면에 상위 직업이 섞이지 않게 한다.
@export var tier2_jobs: Array[JobDefinition] = []
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


## codec가 검증한 신규 모험가 인스턴스 전용. 전직 보상/환급 없이 직업만 복원한다.
func restore_saved_job(job_id: StringName) -> void:
	if job_id != ADVENTURER_JOB_ID:
		_start_as_job(_find_job(job_id))
	transition_available = (
		_next_transition_level() > 0 and _current_level() >= _next_transition_level()
	)


func _on_leveled_up(new_level: int) -> void:
	_update_availability(new_level)


## 전직 임계(1차 Lv10 / 2차 Lv40) 도달 시 전직 가능 플래그를 세운다. 다중 레벨업이 임계를
## 건너뛰어도 레벨마다 leveled_up가 발신되므로(PlayerProgression while 루프) 임계 통과 순간
## 플래그가 서고, 실제 스탯 소급은 전직 실행 시 recompute_stats(현재 레벨)로 자동 반영된다
## (spec 3-3). 1차 전직을 마친 뒤에는 같은 판정이 다음 계통(2차) 임계로 이어진다.
func _update_availability(level: int) -> void:
	if transition_available:
		return
	var threshold := _next_transition_level()
	if threshold < 0:
		return  ## 이 직업에서 갈 수 있는 상위 직업이 없다(최종 계통 또는 데이터 미등록)
	if level >= threshold:
		transition_available = true
		transition_became_available.emit(level)
		_print_transition_guide(level)


## 지금 전직할 수 있는 직업 후보. 미전직(모험가)이면 1차 목록 그대로이고(직업 선택 화면의
## 카드 순서와 인덱스가 일치해야 한다), 전직 후에는 required_job_id가 현재 직업과 일치하는
## 상위 계통만 남는다.
## 직업 선택 화면(ui: job_selection_screen.gd)이 카드를 만들 때 이 목록을 그대로 써야 하므로
## (UI가 후보 규칙을 다시 구현하면 request_transition_by_index의 인덱스와 어긋난다) 공개
## API다 — 구 이름 `_candidate_jobs()`에서 개명(M3, 유일한 외부 호출부와 동시 반영).
func candidate_jobs() -> Array[JobDefinition]:
	if not is_transitioned:
		return available_jobs
	var candidates: Array[JobDefinition] = []
	for job_def in tier2_jobs:
		if job_def != null and job_def.required_job_id == current_job_id:
			candidates.append(job_def)
	return candidates


## 다음 전직의 임계 레벨(첫 후보의 임계 — 계통 내 임계는 동일하다). 후보가 없으면 -1.
func _next_transition_level() -> int:
	for job_def in candidate_jobs():
		if job_def != null:
			return job_def.transition_level()
	return -1


## 등록된 전 직업(1차 + 상위 계통)에서 id로 찾는다.
func _find_job(job_id: StringName) -> JobDefinition:
	for job_def in available_jobs:
		if job_def != null and job_def.job_id == job_id:
			return job_def
	for job_def in tier2_jobs:
		if job_def != null and job_def.job_id == job_id:
			return job_def
	return null


## 지금 이 직업으로 전직할 수 있는지 — 전직 가능 임계에 도달했고, 현재 직업에서 갈 수 있는
## 후보인지(미전직이면 1차 목록, 전직 후면 전제 조건이 맞는 상위 계통).
func can_transition(job_id: StringName) -> bool:
	if not transition_available:
		return false
	for job_def in candidate_jobs():
		if job_def != null and job_def.job_id == job_id:
			return true
	return false


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
		# 직업 변경으로 최대치가 낮아지면 초과분만 제거한다. 전직으로 회복하지 않는다.
		var vitals := get_node_or_null("../PlayerStats") as PlayerStatsComponent
		if vitals != null:
			vitals.current_hp = minf(vitals.current_hp, vitals.stats.max_hp)
			vitals.current_mp = minf(vitals.current_mp, vitals.stats.max_mp)
			vitals.hp_changed.emit(vitals.current_hp, vitals.stats.max_hp)
			vitals.mp_changed.emit(vitals.current_mp, vitals.stats.max_mp)

	## ② 전직 보너스 스킬 포인트 +2(spec 6-1).
	if _skill_points:
		var available_ids: Array[StringName] = []
		for skill in job_def.skill_loadout().values():
			if skill != null:
				available_ids.append(StringName(skill.skill_name))
		_skill_points.refund_unavailable_skills(available_ids)
		_skill_points.grant_transition_points()

	## ③ 승계형 스킬 슬롯 개방 + ④ 직업 무기(기본 공격 콤보) 교체.
	_apply_loadout(job_def)

	current_job_id = job_id
	is_transitioned = true
	transition_available = false
	job_changed.emit(job_id)
	print("[전직] %s 전직 완료 — 스킬 슬롯 개방·스킬 포인트 +2." % job_def.display_name)
	## 다음 계통(2차 Lv40) 임계를 이미 넘긴 상태로 전직했을 수도 있으므로 곧바로 재판정한다.
	_update_availability(_current_level())
	return true


## 승계형 스킬 슬롯 개방과 직업 무기(기본 공격 콤보) 교체, 직업 전용 스프라이트 시트 교체를
## 부모 컨트롤러에 위임한다.
## 자식 _ready(직행 시작 경로)에서도 호출되는데, 그 시점 부모의 @onready 참조는 아직
## 비어 있다 — apply_transition_loadout은 슬롯 대입과 쿨다운 초기화만 하고 진행 중 동작
## 정리는 상태 확인 후에만 하므로(시작 시 전부 정지 상태) 안전하다. 시트 교체도 같은 이유로
## PlayerVisualModule이 캐시해 두고 컨트롤러 _ready의 setup에서 Sprite 노드에 반영한다.
func _apply_loadout(job_def: JobDefinition) -> void:
	if _controller == null:
		return
	if _controller.has_method("apply_transition_loadout"):
		_controller.apply_transition_loadout(job_def.skill_loadout(), job_def.basic_combo)
	var visual := _controller.get("visual") as PlayerVisualModule
	if visual != null:
		visual.set_job_sprite_frames(job_def.sprite_frames)


## 현재 전직 후보 목록의 index번째 직업으로 전직을 실행한다(전직 실행 키·직업 선택 화면
## 공용). 미전직 상태에서는 후보 목록이 available_jobs 그대로이므로 화면의 카드 번호와
## 인덱스가 일치한다. 범위를 벗어나거나 조건 미충족이면 false.
func request_transition_by_index(index: int) -> bool:
	var candidates := candidate_jobs()
	if index < 0 or index >= candidates.size():
		return false
	var job_def := candidates[index]
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
	if index >= 0 and index < candidate_jobs().size():
		request_transition_by_index(index)


## 전직 가능해진 순간의 콘솔 안내 — 정식 전직 UI가 없는 동안 플레이어(디렉터)가 전직을
## 실제로 실행할 수 있게 선택 키를 함께 알린다.
func _print_transition_guide(level: int) -> void:
	var candidates := candidate_jobs()
	var tier_name := "2차" if is_transitioned else "1차"
	var text := "[전직] Lv%d 도달 — %s 전직이 가능합니다." % [level, tier_name]
	if debug_transition_keys_enabled:
		for i in candidates.size():
			var job_def := candidates[i]
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
