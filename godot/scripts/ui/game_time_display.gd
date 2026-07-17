## HUD C요소 — 게임 내 시간 표시 (자리 + 더미).
##
## `docs\art\ux\ux-foundation.md` 5장 C행: "☀/☾ 아이콘 + N일차 HH:MM. 현실 30분=게임 하루
## 기준 표시. 아이콘으로 낮/밤 구분(색맹 대응)." 게임 내 시간 시스템(systems-designer 담당,
## M2 범위 밖)이 아직 없어 실제로 흐르지 않는 더미 값만 표시한다 — 시간 시스템이 구현되면
## set_time()을 실시간 값으로 주기 호출하도록 교체하면 된다.
class_name GameTimeDisplay
extends Panel

## 갈무리 폰트에 ☾(달, U+263E) 글리프가 없어 ★(U+2605)로 대체했다 — 낮(☀)과 형태가
## 뚜렷이 달라 색+아이콘 이중 신호 원칙(ux 1장 접근성)은 유지된다.
const ICON_DAY := "☀"
const ICON_NIGHT := "★"

@onready var _icon_label: Label = $HBox/IconLabel
@onready var _time_label: Label = $HBox/TimeLabel


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.make_panel_stylebox())
	UiStyle.apply_body_font(_icon_label)
	UiStyle.apply_label_font(_time_label)
	_icon_label.add_theme_color_override("font_color", UiStyle.COLOR_EXP)
	_time_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	## 더미 값 — 시간 시스템 미구현(M2 범위 밖, PROJECT_STATUS 8장 제외 목록)
	set_time(1, 14, 30, true)


## day_number: N일차. hour/minute: 24시간제. is_day: true=낮(☀), false=밤(★).
func set_time(day_number: int, hour: int, minute: int, is_day: bool) -> void:
	_icon_label.text = ICON_DAY if is_day else ICON_NIGHT
	_time_label.text = "%d일차 %02d:%02d" % [day_number, hour, minute]
