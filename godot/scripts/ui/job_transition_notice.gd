## HUD 전직 가능 알림 (M3 전직 UI) — Lv10 도달 시 우측에 상시 표시되는 배너.
##
## PlayerJobTransition(B-5)의 `transition_became_available`를 구독해 표시되고, 전직이
## 끝나면(`job_changed`) 사라진다. 배너를 클릭하거나 V 키를 누르면 직업 선택 화면을 열어
## 달라고 `selection_requested`를 발신한다(화면을 직접 열지 않는다 — HUD가 배선한다).
##
## 위치는 `docs\art\ux\ux-foundation.md` 5장 E행(알림 토스트, 우측 D 하단 연동)의 앵커를
## 재사용한다. 전직 알림의 정식 규격은 ux 문서 8절 12번("전직 화면")이 아직 미작성이라
## 기존 E행 앵커·폰트 등급에 맞춰 배치했다 — 정식 UX 설계 시 재확인 필요.
##
## 4초 후 사라지는 토스트와 달리 **전직을 실행할 때까지 계속 남는다** — 전직은 놓치면
## 안 되는 1회성 분기이고, 정식 전직 절차(도시 전직 기관·전직 시험 퀘스트, jobs.md 6장)가
## 구현되기 전까지 이 배너가 유일한 정식 진입점이기 때문이다.
class_name JobTransitionNotice
extends Panel

## 배너 클릭 또는 V 키 입력 — 직업 선택 화면을 열어 달라는 요청.
signal selection_requested

## 직업 선택 화면을 여는 키. 정식 입력 액션을 추가하려면 project.godot 변경이 필요한데
## 그 파일은 다른 작업과 충돌하므로, F11~F12(전직 디버그 키)와 겹치지 않는 raw keycode로
## 처리한다(player_job_transition.gd의 디버그 키와 동일 방식). 메뉴 단축키(I/C/K/J/M/B)와도
## 겹치지 않는 키를 골랐다 — 정식 키 배치는 UX 확정 시 조정.
const OPEN_KEYCODE := KEY_V
## 주의를 끄는 밝기 맥동 1회 길이(현실 초). 색만이 아니라 움직임으로도 신호를 준다(ux 1장).
const PULSE_SEC := 0.9

var _transition: PlayerJobTransition = null
var _pulse_tween: Tween = null

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _hint_label: Label = $VBox/HintLabel


func _ready() -> void:
	add_theme_stylebox_override("panel", _make_notice_stylebox())
	UiStyle.apply_body_font(_title_label)
	_title_label.add_theme_color_override("font_color", UiStyle.COLOR_EXP)
	UiStyle.apply_label_font(_hint_label)
	_hint_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	visible = false


## 경험치 색(#feae34) 테두리를 두른 패널 — "성장 관련 알림"이라는 역할색 신호(STYLE_GUIDE 2-1).
func _make_notice_stylebox() -> StyleBoxFlat:
	var box := UiStyle.make_panel_stylebox()
	box.border_color = UiStyle.COLOR_EXP
	box.set_border_width_all(2)
	return box


## transition: player.tscn의 "PlayerJobTransition" 자식. null이면(구버전 씬) 배너는 계속 숨김.
func bind_transition(transition: PlayerJobTransition) -> void:
	_transition = transition
	if transition == null:
		return
	transition.transition_became_available.connect(_on_became_available)
	transition.job_changed.connect(_on_job_changed)
	## 이미 전직 가능한 상태로 bind되는 경우(세이브 로드·디버그 시작)도 즉시 표시한다.
	set_available(transition.transition_available)


func _on_became_available(_level: int) -> void:
	set_available(true)


func _on_job_changed(_job_id: StringName) -> void:
	set_available(false)


## 배너 표시/숨김을 전환한다(테스트·외부 호출 공용).
func set_available(is_available: bool) -> void:
	visible = is_available
	if is_available:
		_start_pulse()
		return
	_stop_pulse()


func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate:a", 0.55, PULSE_SEC * 0.5)
	_pulse_tween.tween_property(self, "modulate:a", 1.0, PULSE_SEC * 0.5)


func _stop_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	modulate.a = 1.0


func _gui_input(event: InputEvent) -> void:
	var button_event := event as InputEventMouseButton
	if button_event == null or not button_event.pressed:
		return
	if button_event.button_index == MOUSE_BUTTON_LEFT:
		selection_requested.emit()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.keycode == OPEN_KEYCODE:
		selection_requested.emit()
		get_viewport().set_input_as_handled()
