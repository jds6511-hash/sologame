## 전장 진행은 카메라 위치와 무관하게 표시한다.
extends CanvasLayer
var manager: Node
var label: Label

func setup(value: Node) -> void:
	manager = value
	layer = 8
	label = Label.new()
	label.position = Vector2(580, 28)
	label.size = Vector2(760, 92)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_body_font(label, 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)

func _process(_delta: float) -> void:
	label.text = ""
	if not is_instance_valid(manager) or not manager.active:
		return
	var data: Dictionary = manager.definitions[manager.source]
	if data.kind == "evacuation":
		label.text = "%s · 대피 지원 %.1f / %.0f초\n피격 시 잠시 멈춤 · 원 밖 0.5초 이탈 시 초기화" % [data.title, manager.elapsed, data.get("duration", 8.0)]
	else:
		label.text = data.title
		for monster in manager.targets():
			if monster.has_method("current_telegraph"):
				var notice: String = monster.current_telegraph()
				label.text = "%s · HP %d / %d · %d단계\n%s" % [monster.stats.display_name,
					monster.hp, monster.effective_max_hp(), monster.phase,
					notice if notice != "" else "다음 공격을 준비합니다"]
				break
