extends "res://scripts/npc/quest_npc.gd"
var panel: CanvasLayer


func configure(actor: PlayerController, display: CanvasLayer) -> void:
	_player = actor
	panel = display
	npc_id = "yeoulmok_manager"
	var label := Label.new()
	label.name = "Name"
	label.text = "여울목 관리인"
	label.position = Vector2(-40, -40)
	label.size = Vector2(80, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	style_name()


func _draw() -> void:
	draw_rect(Rect2(-7, -20, 14, 20), Color("596d48"))
	draw_circle(Vector2(0, -24), 5, Color("f2d3ab"))


func update_target() -> void:
	_available = _can_interact()


func interaction_verb() -> String:
	return "영지 관리"


func interact() -> bool:
	return _can_interact() and panel.open()
