## HUD A요소 — 플레이어 상태 패널 (초상·레벨/직업·HP 바·MP 바).
##
## `docs\art\ux\ux-foundation.md` 5장 A행: 초상(64x64)·레벨+직업명(16px)·HP 바(적색 계열+
## 수치)·MP 바(청색 계열+수치). "피격 시 HP 바 감소분 잔상 연출. HP 30% 이하 시 바 테두리
## 점멸(색+모양 이중 신호)". PlayerStatsComponent(M2 Phase3)의 hp_changed/mp_changed
## 시그널을 그대로 구독한다 — 해당 스크립트는 수정 대상이 아니다.
##
## M3: 초상을 정식 스프라이트(28x36 시트)에서 만든다. 표시할 시트는 HUD가
## `set_portrait_frames`로 넣어 주며(직업->시트 매핑은 JobDefinition이 유일한 출처 — hud.gd
## `_refresh_portrait` 참고), 이 패널은 "시트에서 어느 프레임을 어떻게 자를지"만 정한다.
## 씬(`player_status_panel.tscn`)의 기본 초상은 **player.tscn의 기본 시트와 같은 전사 신판
## 시트(player_warrior_v2_idle.png)**를 가리킨다 — 전용 시트가 없는 모험가 구간에서 HUD 초상이
## 화면의 플레이어 스프라이트와 일치하게 하는 폴백이며, 에디터 미리보기 역할도 겸한다.
class_name PlayerStatusPanel
extends Panel

const LOW_HP_RATIO := 0.3
const GHOST_DRAIN_PER_SEC := 0.5  ## 잔상이 초당 실제 HP를 따라잡는 비율(0~1 스케일)
const BLINK_PERIOD_SEC := 0.6

## 초상으로 쓰는 애니메이션·프레임 — 정면 대기 첫 프레임(얼굴이 정면으로 보이는 유일한 상태).
const PORTRAIT_ANIMATION := &"idle_front"
const PORTRAIT_FRAME_INDEX := 0
## 초상 크롭 — 프레임(28x36, STYLE_GUIDE 1-2절 2026-07-30 개정) 안에서 잘라낼 상반신 영역이며
## 좌표는 프레임 좌상단 기준 상대값이다. 규격 근거:
##   · 폭 24 = 28에서 좌우 각 2px씩 대칭 트림. 실측 alpha bbox가 전사 x2~22 / 궁수 x3~24라
##     잘리는 픽셀은 없고, 캔버스 좌우 여백(4~5px/측)이 초상을 작게 보이게 하는 몫만 줄인다.
##   · 높이 24 = 상단 24행 = 머리 + 몸통(전사는 대검까지). 전신을 넣으면 얼굴이 96px 칸에서
##     12px밖에 안 되므로 흉상으로 자른다. 표정 픽셀은 규격상 없다(STYLE_GUIDE 3-2-2절 —
##     눈 1px 점 2개가 상한) — 초상의 직업 식별은 무기·실루엣이 담당한다.
##   · 24는 초상 칸 96x96의 정수 약수라 배율이 정확히 x4가 된다(STYLE_GUIDE 1-1절 "비정수
##     스케일 금지"). 크롭 크기를 바꿀 때는 96의 약수를 유지할 것.
const PORTRAIT_CROP_RECT := Rect2(2, 0, 24, 24)

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


## 시트의 정면 대기 첫 프레임에서 상반신을 잘라낸 초상 텍스처. 프레임 자체가 시트 안의
## AtlasTexture(리전 `Rect2(c*28, r*36, 28, 36)` — STYLE_GUIDE 7-1절)이므로 **그 리전 원점에
## 크롭을 더해** 좌표를 잡는다 — 프레임 위치를 UI가 다시 계산하지 않으니 시트의 행·열 배치가
## 바뀌어도 따라간다. 시트가 없거나 정면 대기 프레임이 없으면 null(호출자가 현행 유지).
static func _make_portrait_texture(frames: SpriteFrames) -> AtlasTexture:
	if frames == null or not frames.has_animation(PORTRAIT_ANIMATION):
		return null
	if frames.get_frame_count(PORTRAIT_ANIMATION) <= PORTRAIT_FRAME_INDEX:
		return null
	var frame := frames.get_frame_texture(PORTRAIT_ANIMATION, PORTRAIT_FRAME_INDEX) as AtlasTexture
	if frame == null:
		return null
	var portrait := AtlasTexture.new()
	portrait.atlas = frame.atlas
	portrait.region = Rect2(
		frame.region.position + PORTRAIT_CROP_RECT.position, PORTRAIT_CROP_RECT.size
	)
	return portrait


func set_level_and_job(level: int, job_name: String) -> void:
	_level_job_label.text = "Lv.%d %s" % [level, job_name]


## 직업 스프라이트 시트를 초상에 반영한다(HUD가 JobDefinition에서 가져와 넣어 준다).
## 초상을 만들 수 없는 시트(null·정면 대기 없음)면 현재 초상을 그대로 둔다 — 전용 시트가 없는
## 직업(검투사)이 "전사 시트 유지"로 표현되는 데이터 규약과 같은 동작이다.
func set_portrait_frames(frames: SpriteFrames) -> void:
	var texture := _make_portrait_texture(frames)
	if texture != null:
		_portrait.texture = texture


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
