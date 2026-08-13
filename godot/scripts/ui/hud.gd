## M2 HUD — UI-1 (HP/MP 바, 스킬 슬롯 쿨다운, 미니맵, 게임 내 시간, 경험치 바, 상호작용 프롬프트).
##
## `docs\art\ux\ux-foundation.md` 5장 좌표 확정분을 그대로 구현한 CanvasLayer 씬이다.
## `docs\art\PIPELINE.md` 3장 "HUD/메뉴 등 UI는 반드시 CanvasLayer 하위에 배치 — Camera2D
## 자식으로 두면 줌이 적용되어 ux-foundation의 좌표가 어긋난다" 규칙을 따른다.
##
## M3 B-4: M2에서 표시용 setter만 있던 레벨/경험치 바를 PlayerProgression(B-1) 시그널
## 구독으로 실제 값 반영하도록 확장했다. bind_player가 이미 player를 받으므로, 그 자식
## PlayerProgression·PlayerStatGrowth를 노드 경로로 찾아 스스로 배선한다(월드 씬의 기존
## bind_player 호출만으로 레벨/EXP/레벨업 연출이 동작 — 추가 배선 불필요). 스킬 강화 화면과
## 스탯 상세(치명타% 포함)는 상시 표시가 아니므로(ux 5장 정보 위계) 통합 메뉴 K/C 탭 소관이다.
##
## M3 C-1: 검투사 분노 게이지(RageGauge)를 추가했다 — 검투사 로드아웃이 적용된 동안에만
## 스스로 표시되므로(rage_gauge.gd 헤더) HUD는 bind만 하고 표시 조건에 관여하지 않는다.
class_name Hud
extends CanvasLayer

## 레벨업 중앙 연출 총 지속(현실 초) — ux 5장 J행 "레벨업 시 화면 중앙 연출".
const LEVEL_UP_FLASH_SEC := 1.2

var _exp_bar_width := 0.0
var _job_name := "전사"
## M3 전직 UI 배선용 참조(bind_player가 채운다).
var _bound_player: PlayerController = null
var _progression: PlayerProgression = null
var _job_transition: PlayerJobTransition = null

@onready var _status_panel: PlayerStatusPanel = $PlayerStatusPanel
@onready var _minimap: MinimapDisplay = $Minimap
@onready var _game_time: GameTimeDisplay = $GameTimeDisplay
@onready var _skill_bar: SkillSlotBar = $SkillSlotBar
@onready var _rage_gauge: RageGauge = $RageGauge
@onready var _interaction_prompt: InteractionPrompt = $InteractionPrompt
@onready var _exp_bar: Control = $ExpBar
@onready var _exp_fill: ColorRect = $ExpBar/Fill
@onready var _exp_max_label: Label = $ExpBar/MaxLabel
@onready var _level_up_flash: Label = $LevelUpFlash
@onready var _job_notice: JobTransitionNotice = $JobTransitionNotice
@onready var _job_selection: JobSelectionScreen = $JobSelectionScreen
@onready var _debug_level_keys: DebugLevelKeys = $DebugLevelKeys


func _ready() -> void:
	_exp_bar_width = _exp_bar.size.x
	UiStyle.apply_label_font(_exp_max_label)
	_exp_max_label.add_theme_color_override("font_color", UiStyle.COLOR_EXP)
	_exp_max_label.visible = false
	UiStyle.apply_body_font(_level_up_flash, 48)
	_level_up_flash.add_theme_color_override("font_color", UiStyle.COLOR_EXP)
	_level_up_flash.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_level_up_flash.add_theme_constant_override("outline_size", 6)
	_level_up_flash.visible = false
	_job_notice.selection_requested.connect(_job_selection.open)


## player: player.tscn 루트(PlayerController). stats: player.tscn의 "PlayerStats" 자식
## (PlayerStatsComponent). 통합 예시: 월드 씬에 이 HUD 씬을 추가한 뒤
## `hud.bind_player(player, player.get_node("PlayerStats"))` 호출.
func bind_player(player: PlayerController, stats: PlayerStatsComponent) -> void:
	_bound_player = player
	_skill_bar.bind_player(player, stats)
	_minimap.bind_player(player)
	stats.hp_changed.connect(_status_panel.set_hp)
	stats.mp_changed.connect(_status_panel.set_mp)
	_status_panel.set_hp(stats.current_hp, stats.stats.max_hp)
	_status_panel.set_mp(stats.current_mp, stats.stats.max_mp)
	## 분노 게이지(M3 C-1)는 검투사 로드아웃일 때만 스스로 나타난다 — 여기서는 연결만 한다.
	_rage_gauge.bind_player(player)
	## 직업명 표시가 전직 노드의 JobDefinition을 참조하므로 진행도보다 먼저 잡아 둔다.
	_job_transition = player.get_node_or_null("PlayerJobTransition") as PlayerJobTransition
	_bind_progression(player)
	_bind_job_transition()
	## 디버그 직행 시작(initial_job_id)은 job_changed를 발신하지 않으므로 바인드 시점에도 맞춘다.
	_refresh_portrait()


## 레벨·경험치 바를 PlayerProgression(B-1)에 연결한다(m3-leveling-spec 7-5). 노드가 없는
## 씬에서는 Lv1 고정 표시로 폴백한다(하위 호환).
func _bind_progression(player: PlayerController) -> void:
	_job_name = _resolve_job_name(player)
	var progression := player.get_node_or_null("PlayerProgression") as PlayerProgression
	if progression == null:
		_status_panel.set_level_and_job(1, _job_name)
		return
	_progression = progression
	_debug_level_keys.bind_progression(progression)
	progression.leveled_up.connect(_on_leveled_up)
	progression.exp_changed.connect(_on_exp_changed)
	_status_panel.set_level_and_job(progression.current_level, _job_name)
	_on_exp_changed(progression.current_exp, progression.exp_to_next())


## 전직 UI(M3) 배선 — 전직 가능 알림과 직업 선택 화면을 PlayerJobTransition(B-5)에 연결한다.
## 노드가 없는 씬(구버전·테스트 씬)에서는 알림이 표시되지 않고 화면도 열리지 않는다.
func _bind_job_transition() -> void:
	_job_notice.bind_transition(_job_transition)
	_job_selection.bind_transition(_job_transition)
	if _job_transition:
		_job_transition.job_changed.connect(_on_job_changed)


## 전직 완료 시 레벨·직업 라벨을 새 직업명으로 갱신한다 — 직업명은 bind 시점 스냅샷이라
## 이 갱신이 없으면 전직해도 "모험가"로 남는다.
func _on_job_changed(_job_id: StringName) -> void:
	_job_name = _resolve_job_name(_bound_player)
	var level: int = _progression.current_level if _progression else 1
	_status_panel.set_level_and_job(level, _job_name)
	_refresh_portrait()


## HUD 초상을 현재 직업의 스프라이트 시트로 맞춘다(M3 3-A). 시트는 **PlayerJobTransition이
## 아는 JobDefinition.sprite_frames를 그대로** 읽는다 — 인게임 스프라이트를 갈아 끼우는 것과
## 같은 데이터 출처이므로(PlayerVisualModule.set_job_sprite_frames) 직업->시트 매핑을 UI가 다시
## 만들지 않아 어긋날 수 없다. 시트를 못 찾는 두 경우는 모두 "현재 초상 유지"가 정답이다:
##   · 모험가 — 등록된 JobDefinition이 없다. 씬 기본 초상이 player.tscn 기본 시트(전사 신판)와
##     같은 시트라 화면의 플레이어 스프라이트와 일치한다.
##   · 검투사 — 정의는 있으나 sprite_frames가 비어 있다(= 전사 시트 유지가 데이터로 표현된
##     상태). 전직 전 전사 초상이 그대로 남아 인게임 스프라이트와 일치한다.
func _refresh_portrait() -> void:
	var job_def := _current_job_definition()
	if job_def == null:
		return
	_status_panel.set_portrait_frames(job_def.sprite_frames)


## 직업명은 **전직 노드가 아는 JobDefinition.display_name을 먼저** 쓴다(M3 C-1). 성장 데이터
## (PlayerStatGrowth.job = JobGrowthData)는 "레벨당 스탯 배분" 단위라 검투사가 전사 배분
## (job_growth_warrior.tres)을 그대로 재사용하며, 그 display_name("전사")을 쓰면 2차 전직 후에도
## 라벨이 "전사"로 남는다. 전직 노드가 없는 씬(구버전·테스트)이나 모험가(등록된 직업 정의가
## 없다)는 기존대로 성장 데이터명으로 폴백한다.
func _resolve_job_name(player: PlayerController) -> String:
	var definition_name := _job_definition_name()
	if not definition_name.is_empty():
		return definition_name
	var growth := player.get_node_or_null("PlayerStatGrowth")
	if growth and growth.job:
		return growth.job.display_name
	return "전사"


## 현재 직업 id와 일치하는 JobDefinition의 표시명. 등록된 정의가 없으면 빈 문자열.
func _job_definition_name() -> String:
	var job_def := _current_job_definition()
	return job_def.display_name if job_def != null else ""


## 현재 직업 id와 일치하는 JobDefinition(1차 목록 -> 상위 계통 순서로 찾는다). 직업명과 초상
## 시트가 같은 정의에서 나와야 둘이 어긋나지 않으므로 조회를 한 곳으로 모았다. 전직 노드가
## 없는 씬(구버전·테스트)이나 모험가(등록된 정의가 없다)면 null.
func _current_job_definition() -> JobDefinition:
	if _job_transition == null:
		return null
	var job_def := _find_job(_job_transition.available_jobs)
	return job_def if job_def != null else _find_job(_job_transition.tier2_jobs)


func _find_job(definitions: Array[JobDefinition]) -> JobDefinition:
	for job_def in definitions:
		if job_def != null and job_def.job_id == _job_transition.current_job_id:
			return job_def
	return null


## 현재 레벨 내 경험치 변동 반영. exp_to_next<=0 이면 만렙 — 바를 만충하고 MAX를 표기한다
## (ux 5장 J행 "레벨업 시 …", spec 3-2 만렙 만충 표시).
func _on_exp_changed(current_exp: int, next_exp: int) -> void:
	if next_exp <= 0:
		_exp_fill.size.x = _exp_bar_width
		_exp_max_label.visible = true
		return
	_exp_max_label.visible = false
	set_exp_ratio(float(current_exp) / float(next_exp))


func _on_leveled_up(new_level: int) -> void:
	_status_panel.set_level_and_job(new_level, _job_name)
	_play_level_up_flash(new_level)


## 화면 중앙에 "레벨 업!" 문구를 페이드 인/아웃하는 간단 연출(ux 5장 J행 규격 내).
func _play_level_up_flash(new_level: int) -> void:
	_level_up_flash.text = "레벨 업!  Lv.%d" % new_level
	_level_up_flash.visible = true
	_level_up_flash.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_level_up_flash, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.5)
	tween.tween_property(_level_up_flash, "modulate:a", 0.0, LEVEL_UP_FLASH_SEC - 0.7)
	tween.tween_callback(_hide_level_up_flash)


func _hide_level_up_flash() -> void:
	_level_up_flash.visible = false


## 경험치 바 채움 비율(0~1) 직접 설정 — 하위 호환 유지(테스트·외부 호출용).
func set_exp_ratio(ratio: float) -> void:
	_exp_fill.size.x = _exp_bar_width * clampf(ratio, 0.0, 1.0)


## 게임 내 시간 표시 연동 지점 — GameClock 주기 호출로 갱신된다.
func set_game_time(day_number: int, hour: int, minute: int, is_day: bool) -> void:
	_game_time.set_time(day_number, hour, minute, is_day)


## 상호작용 판정 시스템(M2 미구현) 연동 지점 — 근접 대상 판정이 생기면 이 함수를 호출.
## key_label: 안내할 입력 키(기본 F) — interaction_prompt.gd 참고.
func show_interaction_prompt(
	verb: String, world_position: Vector2, key_label: String = "F"
) -> void:
	_interaction_prompt.show_prompt(verb, world_position, key_label)


func hide_interaction_prompt() -> void:
	_interaction_prompt.hide_prompt()
