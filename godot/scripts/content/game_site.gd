extends "res://scripts/npc/quest_npc.gd"
const Content = preload("res://scripts/content/game_content.gd")
const Investigation = preload("res://scripts/content/field_investigation.gd")
var source := ""
var kind := "REACH"
var investigation: Node2D


func setup(
	player: PlayerController, controller: QuestController, dialog: QuestDialog, hud: Hud
) -> void:
	super.setup(player, controller, dialog, hud)
	if Investigation.CONFIG.has(npc_id):
		investigation = Investigation.new()
		investigation.name = "FieldInvestigation"
		add_child(investigation)
		investigation.setup(self, get_parent().get_node("WorldInteraction"))


func update_target() -> void:
	_available = _can_interact()
	if _available and kind == "REACH":
		_controller.journal.record_event(kind, npc_id, source, 0)


func interact() -> bool:
	if not can_interact():
		return false
	if investigation != null:
		return investigation.begin()
	_controller.journal.record_event(kind, npc_id, source, 0)
	if Content.SITE_NOTICES.has(npc_id):
		_dialog.open_notice(Content.SITE_NOTICES[npc_id])
	return true


func can_interact() -> bool:
	# REACH는 자동 관측만 한다. 미수락/완료 표식은 드롭의 F 입력을 가로채지 않는다.
	if kind != "INTERACT" or not _can_interact():
		return false
	return expects_interaction()


func expects_interaction() -> bool:
	for id in _controller.journal.catalog.ordered_ids():
		if _controller.journal.expects_event(id, kind, npc_id, source):
			return true
	return false


func interaction_verb() -> String:
	return "조사" if kind == "INTERACT" else "표식 확인"


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6, Color("41a6f6"))
	draw_line(Vector2(0, -8), Vector2(0, -18), Color.WHITE, 2)
