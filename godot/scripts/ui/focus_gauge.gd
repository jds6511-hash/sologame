extends Label
## 명사수에게만 표시하는 일시 자원. 저장/게임 상태를 변경하지 않는다.
var player: PlayerController


func _ready() -> void:
	position = Vector2(600, 866)
	size = Vector2(650, 44)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.apply_body_font(self, 22)
	add_theme_color_override("font_color", Color("72d6d0"))
	add_theme_color_override("font_outline_color", Color("172038"))
	add_theme_constant_override("outline_size", 4)


func _process(_delta: float) -> void:
	visible = is_instance_valid(player) and player.skill_slot_4 is SharpshooterSkillData
	if not visible:
		return
	var amount: float = player._shots.focus.value
	text = "집중 %d / 100 · %s" % [int(amount), "[R] 관통탄 가능" if amount >= 50 else "관통탄에 50 필요"]
