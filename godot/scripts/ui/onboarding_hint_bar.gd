## 온보딩 힌트 바 (T) — docs\art\ux\onboarding.md 3장 공통 UI 컴포넌트.
##
## 상단 중앙(340, 24) 600x40, 검정 60% 반투명 모서리 둥근 사각형, 페이드인/아웃 0.3초.
## "확인" 버튼·닫기 키가 없는 자동 소멸 오버레이다(1장 원칙1·3). Tween/await 대신
## player_status_panel.gd 등 기존 HUD 스크립트와 동일하게 _process(delta) 델타 누적으로
## 페이드를 구현했다 — GUT에서 실제 타이머 없이 델타를 수동으로 넘겨 결정론적으로 검증할
## 수 있다.
##
## 두 가지 표시 모드를 제공한다:
## - show_hint()/hide_hint(): 조건 충족까지 유지되는 힌트(재노출 정책은 OnboardingHintTiming
##   담당, 이 바는 "지금 텍스트를 보여줄지"만 반영한다).
## - flash_message(): 첫 처치 알림처럼 고정 시간 후 스스로 사라지는 1회성 토스트
##   (ux-foundation.md 5장 E요소가 아직 구현되지 않아 이 바를 임시로 겸용한다 — 결과 보고 참고).
class_name OnboardingHintBar
extends CanvasLayer

enum Mode { HIDDEN, FADE_IN, VISIBLE, FADE_OUT }

const FADE_SEC := 0.3

var _mode: Mode = Mode.HIDDEN
var _fade_timer: float = 0.0
var _flash_hold_timer: float = -1.0  ## -1 = 토스트 모드 아님

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label


func _ready() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	box.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", box)
	UiStyle.apply_body_font(_label)
	_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	_label.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_label.add_theme_constant_override("outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.modulate.a = 0.0
	_panel.visible = false


func _process(delta: float) -> void:
	match _mode:
		Mode.FADE_IN:
			_fade_timer = minf(_fade_timer + delta, FADE_SEC)
			_panel.modulate.a = _fade_timer / FADE_SEC
			if _fade_timer >= FADE_SEC:
				_mode = Mode.VISIBLE
		Mode.FADE_OUT:
			_fade_timer = minf(_fade_timer + delta, FADE_SEC)
			_panel.modulate.a = 1.0 - _fade_timer / FADE_SEC
			if _fade_timer >= FADE_SEC:
				_mode = Mode.HIDDEN
				_panel.visible = false
		_:
			pass

	if _flash_hold_timer >= 0.0:
		_flash_hold_timer -= delta
		if _flash_hold_timer <= 0.0:
			_flash_hold_timer = -1.0
			_begin_fade_out()


## 조건 충족까지 유지되는 힌트 텍스트를 보여준다(원칙4 재노출 정책은 호출자가 관리).
func show_hint(text: String) -> void:
	_label.text = text
	if _mode == Mode.HIDDEN:
		_panel.visible = true
		_mode = Mode.FADE_IN
		_fade_timer = 0.0
	elif _mode == Mode.FADE_OUT:
		_mode = Mode.FADE_IN
		_fade_timer = FADE_SEC * (1.0 - _panel.modulate.a)


func hide_hint() -> void:
	if _mode == Mode.HIDDEN or _mode == Mode.FADE_OUT:
		return
	_begin_fade_out()


## 첫 처치 알림처럼 hold_sec 동안 보여준 뒤 스스로 사라지는 1회성 토스트.
func flash_message(text: String, hold_sec: float) -> void:
	_label.text = text
	_panel.visible = true
	_mode = Mode.FADE_IN
	_fade_timer = 0.0
	_flash_hold_timer = hold_sec


func is_flashing() -> bool:
	return _flash_hold_timer >= 0.0


func _begin_fade_out() -> void:
	_mode = Mode.FADE_OUT
	_fade_timer = 0.0
