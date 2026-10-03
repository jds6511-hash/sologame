extends "res://scripts/npc/quest_npc.gd"
var panel: CanvasLayer
var city_gate := false


func configure(
	actor: PlayerController,
	display: CanvasLayer,
	gate: bool = false,
	holding_id: String = "yeoulmok"
) -> void:
	_player = actor
	panel = display
	city_gate = gate
	npc_id = "city_warp_gate" if gate else holding_id + "_manager"
	var label := Label.new()
	label.name = "Name"
	label.text = "도시 워프" if gate else ("잿골 영지 관리" if holding_id == "jaetgol" else "여울목 관리인")
	label.position = Vector2(-40, -40)
	label.size = Vector2(80, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	style_name()


func _draw() -> void:
	if city_gate:
		draw_arc(Vector2(0, -12), 12, 0, TAU, 24, Color("70c5e6"), 3)
		draw_line(Vector2(-12, 0), Vector2(12, 0), Color("70c5e6"), 3)
		return
	draw_rect(Rect2(-7, -20, 14, 20), Color("596d48"))
	draw_circle(Vector2(0, -24), 5, Color("f2d3ab"))


func update_target() -> void:
	_available = _can_interact()


func interaction_verb() -> String:
	return "도시 이동" if city_gate else "영지 관리"


func interact() -> bool:
	return _can_interact() and panel.open()
