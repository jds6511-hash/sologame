extends "res://scripts/npc/quest_npc.gd"

var trade_enabled := true
var trade_radius := 40.0
var panel: CanvasLayer


func configure(actor: PlayerController, display: CanvasLayer) -> void:
	set_meta("economy_merchant", true)
	_player = actor
	panel = display
	npc_id = "novera_merchant"
	var label := Label.new()
	label.name = "Name"
	label.text = "노베라 보급상"
	label.position = Vector2(-32, -40)
	label.size = Vector2(64, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	add_child(label)
	style_name()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-7, -20, 14, 20), Color("b86f50"))
	draw_circle(Vector2(0, -24), 5, Color("f2d3ab"))


func update_target() -> void:
	_available = _can_interact()


func interact() -> bool:
	return _can_interact() and panel.open()


func interaction_verb() -> String:
	return "거래"
