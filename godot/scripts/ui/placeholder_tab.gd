## 통합 메뉴 — 미구현 탭 공용 플레이스홀더 (스킬/퀘스트 저널/지도/도감).
##
## `docs\art\ux\ux-foundation.md` 8장 M2 이후 과제 3·5·6·4번 — 각각 의존 시스템(직업
## 트리·퀘스트 구조·월드맵·도감 스키마) 확정 전이라 UI-2는 탭 자리만 만든다.
class_name PlaceholderTab
extends Control

@onready var _label: Label = $Label


func _ready() -> void:
	UiStyle.apply_body_font(_label)
	_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_SUB)


func set_message(text: String) -> void:
	_label.text = text
