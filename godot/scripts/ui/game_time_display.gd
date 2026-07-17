## HUD C요소 — 게임 내 시간 표시.
##
## `docs\art\ux\ux-foundation.md` 5장 C행: "☀/☾ 아이콘 + N일차 HH:MM. 현실 30분=게임 하루
## 기준 표시. 아이콘으로 낮/밤 구분(색맹 대응)." G2-4로 게임 내 시간 오토로드(GameClock,
## scripts/world/game_clock.gd)가 생겨, 매 프레임 그 값을 읽어 표시한다(디버그 HUD의
## 상태 라벨 갱신 방식과 동일하게 _process에서 텍스트를 다시 그린다).
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
	UiStyle.apply_label_font(_icon_label)
	UiStyle.apply_label_font(_time_label)
	_icon_label.add_theme_color_override("font_color", UiStyle.COLOR_EXP)
	_time_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	_refresh_from_game_clock()


func _process(_delta: float) -> void:
	_refresh_from_game_clock()


func _refresh_from_game_clock() -> void:
	set_time(GameClock.day_number, GameClock.get_hour(), GameClock.get_minute(), GameClock.is_day)


## day_number: N일차. hour/minute: 24시간제. is_day: true=낮(☀), false=밤(★).
func set_time(day_number: int, hour: int, minute: int, is_day: bool) -> void:
	_icon_label.text = ICON_DAY if is_day else ICON_NIGHT
	_time_label.text = "%d일차 %02d:%02d" % [day_number, hour, minute]
