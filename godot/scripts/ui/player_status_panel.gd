## HUD A요소 — 플레이어 상태 패널 (초상·레벨/직업·HP 바·MP 바).
##
## `docs\art\ux\ux-foundation.md` 5장 A행: 초상(64x64)·레벨+직업명(16px)·HP 바(적색 계열+
## 수치)·MP 바(청색 계열+수치). "피격 시 HP 바 감소분 잔상 연출. HP 30% 이하 시 바 테두리
## 점멸(색+모양 이중 신호)". PlayerStatsComponent(M2 Phase3)의 hp_changed/mp_changed
## 시그널을 그대로 구독한다 — 해당 스크립트는 수정 대상이 아니다.
class_name PlayerStatusPanel
extends Panel

const LOW_HP_RATIO := 0.3
const GHOST_DRAIN_PER_SEC := 0.5  ## 잔상이 초당 실제 HP를 따라잡는 비율(0~1 스케일)
const BLINK_PERIOD_SEC := 0.6

## 초상 텍스처는 scenes/ui/player_status_panel.tscn에 player_warrior_idle.png의
## AtlasTexture(정면 idle 1프레임)로 미리 배선돼 있다. 그 region은 .tscn에 구 좌표로
## 박혀 있어 STYLE_GUIDE.md 1-2절 현행 규격(20x36, 스톤샤드식 안 1)과 어긋난다 — scenes\ui\는
## 이 태스크의 수정 범위 밖이라 .tscn을 직접 고치는 대신, 여기서 런타임에 region을
## 새 시트 좌표(정면 1프레임 = Rect2(0,0,20,36))로 보정한다.
const PORTRAIT_CROP_REGION := Rect2(0, 0, 20, 36)

var _hp_ratio := 1.0
var _ghost_ratio := 1.0
var _blink_timer := 0.0
var _hp_bar_width := 0.0
var _mp_bar_width := 0.0

@onready var _portrait: TextureRect = $Portrait
@onready var _level_job_label: Label = $LevelJobLabel
@onready var _hp_bar: Control = $HPBar
@onready var _hp_ghost: ColorRect = $HPBar/Ghost
@onready var _hp_fill: ColorRect = $HPBar/Fill
@onready var _hp_border: Panel = $HPBar/BorderBlink
@onready var _hp_label: Label = $HPBar/Label
@onready var _mp_bar: Control = $MPBar
@onready var _mp_fill: ColorRect = $MPBar/Fill
@onready var _mp_label: Label = $MPBar/Label


func _ready() -> void:
	_fix_portrait_crop()
	add_theme_stylebox_override("panel", UiStyle.make_panel_stylebox())
	UiStyle.apply_body_font(_level_job_label)
	UiStyle.apply_label_font(_hp_label)
	UiStyle.apply_label_font(_mp_label)
	_level_job_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	_hp_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	_mp_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)

	_hp_bar_width = _hp_bar.size.x
	_mp_bar_width = _mp_bar.size.x

	var border_box := StyleBoxFlat.new()
	border_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	border_box.set_border_width_all(2)
	border_box.border_color = UiStyle.COLOR_HP
	_hp_border.add_theme_stylebox_override("panel", border_box)
	_hp_border.visible = false


func _process(delta: float) -> void:
	if _ghost_ratio > _hp_ratio:
		_ghost_ratio = maxf(_hp_ratio, _ghost_ratio - GHOST_DRAIN_PER_SEC * delta)
	else:
		_ghost_ratio = _hp_ratio
	_hp_ghost.size.x = _hp_bar_width * _ghost_ratio

	if _hp_ratio <= LOW_HP_RATIO:
		_blink_timer += delta
		_hp_border.visible = true
		_hp_border.modulate.a = 0.5 + 0.5 * sin(_blink_timer * TAU / BLINK_PERIOD_SEC)
	else:
		_blink_timer = 0.0
		_hp_border.visible = false


func _fix_portrait_crop() -> void:
	var atlas := _portrait.texture as AtlasTexture
	if atlas:
		atlas.region = PORTRAIT_CROP_REGION


func set_level_and_job(level: int, job_name: String) -> void:
	_level_job_label.text = "Lv.%d %s" % [level, job_name]


func set_portrait(texture: Texture2D) -> void:
	_portrait.texture = texture


func set_hp(current_hp: float, max_hp: float) -> void:
	_hp_ratio = clampf(current_hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	_hp_fill.size.x = _hp_bar_width * _hp_ratio
	_hp_label.text = "%d/%d" % [roundi(current_hp), roundi(max_hp)]


func set_mp(current_mp: float, max_mp: float) -> void:
	var ratio := clampf(current_mp / max_mp, 0.0, 1.0) if max_mp > 0.0 else 0.0
	_mp_fill.size.x = _mp_bar_width * ratio
	_mp_label.text = "%d/%d" % [roundi(current_mp), roundi(max_mp)]
