## 엔진의 hover 지연/화면 가장자리 배치를 사용하고 설명 크기만 통일한다.
extends Button


func _make_custom_tooltip(text: String) -> Object:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("132234")
	style.border_color = Color("dfbd79")
	style.set_border_width_all(2)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	UiStyle.apply_body_font(label, 25)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.custom_minimum_size.x = 470
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel
