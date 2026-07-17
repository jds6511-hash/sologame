## HUD·통합 메뉴 공용 스타일 상수 (UI-1/UI-2).
##
## `docs\art\STYLE_GUIDE.md` 2장 EDG32 팔레트, 2-1장 "역할 고정색(시스템 연동 — 변경 금지)",
## 1-3장 한글 폰트(갈무리 11/9) 규격을 코드 한 곳에 모아 HUD·통합 메뉴 스크립트가 공유한다.
## 색을 스크립트마다 따로 하드코딩하지 않기 위한 목적 하나뿐이라 별도 Resource로 만들지
## 않고 정적 상수 모음(class_name)으로 둔다.
class_name UiStyle
extends RefCounted

# --- STYLE_GUIDE 2-1장 역할 고정색 (변경 금지) ---
const COLOR_HP := Color("#e43b44")
const COLOR_MP := Color("#0099db")
const COLOR_EXP := Color("#feae34")
const COLOR_BUFF_BORDER := Color("#63c74d")
const COLOR_DEBUFF_BORDER := Color("#e43b44")
const COLOR_PANEL_BG := Color(0.14901961, 0.16862746, 0.26666668, 0.9)  ## #262b44, 불투명 90%
const COLOR_TEXT := Color("#ffffff")
const COLOR_TEXT_SUB := Color("#c0cbdc")
const COLOR_OUTLINE := Color("#181425")
const COLOR_ENEMY_DOT := Color("#e43b44")
const COLOR_NPC_DOT := Color("#fee761")
const COLOR_QUEST_DOT := Color("#feae34")

# --- 1-3장 한글 폰트 경로 ---
const FONT_BODY_PATH := "res://assets/fonts/Galmuri11.ttf"  ## 본문 16px+
const FONT_LABEL_PATH := "res://assets/fonts/Galmuri9.ttf"  ## 보조 라벨 13px+

const FONT_SIZE_BODY := 16
const FONT_SIZE_LABEL := 13

const COOLDOWN_RADIAL_MASK_PATH := "res://assets/icons/ui/cooldown_radial_mask.png"


## 패널 배경용 StyleBoxFlat (역할 고정색 #262b44, 90% 불투명, 1px 최암 외곽선).
static func make_panel_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PANEL_BG
	box.border_color = COLOR_OUTLINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	return box


## HP/MP/EXP 등 게이지 바 배경용 StyleBoxFlat (최암색, 테두리 없음 — 테두리는 바 종류별로 덧씌움).
static func make_bar_background_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_OUTLINE
	return box


## HP/MP/EXP 등 게이지 바 채움용 StyleBoxFlat.
static func make_bar_fill_stylebox(fill_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill_color
	return box


## 본문(16px+) 라벨에 갈무리 11 폰트를 적용한다.
static func apply_body_font(control: Control, size: int = FONT_SIZE_BODY) -> void:
	control.add_theme_font_override("font", load(FONT_BODY_PATH))
	control.add_theme_font_size_override("font_size", size)


## 보조 라벨(13px+)에 갈무리 9 폰트를 적용한다.
static func apply_label_font(control: Control, size: int = FONT_SIZE_LABEL) -> void:
	control.add_theme_font_override("font", load(FONT_LABEL_PATH))
	control.add_theme_font_size_override("font_size", size)
