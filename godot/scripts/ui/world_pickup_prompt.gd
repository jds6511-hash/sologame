## 월드 아이템(WorldItem) 근접 프롬프트 — world_item.gd가 찾는 "PickupPrompt" 자식 노드.
##
## world_item.gd 헤더 주석이 "ui-dev가 만들 근접 프롬프트"로 지정해 둔 지점을 채운다.
## docs\art\ux\onboarding.md 3-6장 "월드 프롬프트는 상시 [F] 줍기" 요구 그대로 — world_item.gd
## 는 이 노드의 visible만 토글하므로(스크립트 수정 없음), 텍스트·스타일은 여기서 전담한다.
class_name WorldPickupPrompt
extends Label

const TEXT := "[F] 줍기"


func _ready() -> void:
	text = TEXT
	UiStyle.apply_label_font(self)
	add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	add_theme_constant_override("outline_size", 2)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = false
