extends Node2D

@export var npc_id := "yeoulmok_receptionist"
var _player: PlayerController
var _controller: QuestController
var _dialog: QuestDialog
var _hud: Hud
var _available := false


func _ready() -> void:
	style_name()


func style_name() -> void:
	var label := get_node_or_null("Name") as Label
	if label == null:
		return
	UiStyle.apply_label_font(label, 9)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("111824"))
	label.add_theme_constant_override("outline_size", 2)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH


func setup(
	player: PlayerController, controller: QuestController, dialog: QuestDialog, hud: Hud
) -> void:
	_player = player
	_controller = controller
	_dialog = dialog
	_hud = hud
	process_priority = 10


func update_target() -> void:
	_available = _can_interact()
	if _available:
		_controller.journal.record_event("REACH", npc_id, "", 0)


func _can_interact() -> bool:
	if _player == null or get_tree().paused:
		return false
	var gate := npc_id in ["yeoulmok_gatewarden", "novera_gatewarden"]
	if (
		_player.is_input_locked
		or (_player.is_hit_stunned and not gate)
		or _player.get_node("PlayerStats").is_dead()
		or (_player.attack_state != PlayerController.AttackState.NONE and not gate)
		or (_player.skill_state != PlayerController.AttackState.NONE and not gate)
		or (_player.is_dashing and not gate)
		or _player.global_position.distance_to(global_position) > 40.0
	):
		return false
	var query := PhysicsRayQueryParameters2D.create(_player.global_position, global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func interact() -> bool:
	update_target()
	if not _available:
		return false
	var opened := _dialog.open_dialog(npc_id)
	return opened


func can_interact() -> bool:
	return _can_interact()


func interaction_id() -> String:
	return npc_id


func interaction_priority() -> int:
	return 0


func interaction_verb() -> String:
	return "대화"


## 이름표의 실제 레이아웃 상단을 기준으로 HUD 안내를 배치한다.
func interaction_prompt_position() -> Vector2:
	var label: Label = get_node("Name")
	return label.global_position + Vector2(label.size.x * 0.5, 0)
