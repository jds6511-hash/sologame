## S06 통합 메뉴 — 인벤토리 탭 (연동 인터페이스만 노출, 직접 구현 금지).
##
## 인벤토리 실제 기능(줍기·장착·버리기, IT-3)은 systems-dev가 병렬로 구현 중이라, 이
## 태스크(UI-2)에서는 연동 지점만 만든다 — `get_content_root()`가 돌려주는 Control 아래에
## IT-3 완성 후 실제 인벤토리 UI 서브트리를 추가하면 된다.
class_name InventoryTabStub
extends Control

@onready var _placeholder_label: Label = $PlaceholderLabel
@onready var _content_root: Control = $ContentRoot


func _ready() -> void:
	UiStyle.apply_body_font(_placeholder_label)
	_placeholder_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_SUB)


## IT-3 연동 지점 — 이 Control의 자식으로 실제 인벤토리 그리드/장비창 UI를 추가하면 된다.
func get_content_root() -> Control:
	return _content_root
