## HUD I요소 — 상호작용 프롬프트 (대상 오브젝트 상단, 월드 좌표 추종).
##
## `docs\art\ux\ux-foundation.md` 5장 I행: "[F] 대화 / [F] 채집 등 키+동사. 다수 대상 시
## 가장 가까운 1개만." 실제 상호작용 대상 판정(F 입력 시 근접 대상 탐색)은 이 UI 태스크의
## 범위 밖이다 — 아직 어떤 시스템도 "지금 상호작용 가능한 대상"을 판정해 알려주지 않으므로
## (NPC·채집물 씬 자체가 M2에 아직 없음), 이 스크립트는 "판정이 성립하면 보여줄" 표시 API만
## 제공한다. 판정 시스템이 생기면 show_prompt()/hide_prompt()를 호출하도록 연동하면 된다.
class_name InteractionPrompt
extends Label

var _target_world_position := Vector2.ZERO
var _is_active := false


func _ready() -> void:
	UiStyle.apply_label_font(self)
	add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	add_theme_constant_override("outline_size", 2)
	visible = false


## verb: "대화"/"채집" 등 동사. world_position: 대상의 월드 좌표(프롬프트가 그 위쪽에 뜬다).
## key_label: 안내할 입력 키(기본 F). onboarding.md 3-2장 "[좌클릭] 공격"처럼 F가 아닌 입력을
## 안내해야 하는 온보딩 힌트가 이 프롬프트를 재사용할 수 있도록 노출했다(기본값은 기존 동작
## 그대로 유지 — 실제 상호작용 판정 시스템 도입 시에도 하위 호환).
func show_prompt(verb: String, world_position: Vector2, key_label: String = "F") -> void:
	text = "[%s] %s" % [key_label, verb]
	_target_world_position = world_position
	_is_active = true
	visible = true
	_follow_world_position()


func hide_prompt() -> void:
	_is_active = false
	visible = false


func _process(_delta: float) -> void:
	if _is_active:
		_follow_world_position()


## CanvasLayer 하위에서도 get_viewport().get_canvas_transform()은 월드 카메라(x4 줌 포함)
## 기준 변환을 그대로 돌려주므로, 이를 이용해 월드 좌표를 네이티브 화면 픽셀로 환산한다.
func _follow_world_position() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var screen_pos: Vector2 = viewport.get_canvas_transform() * _target_world_position
	position = screen_pos - Vector2(size.x * 0.5, size.y + 8.0)
