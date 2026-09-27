extends Node2D

@export var npc_id := "yeoulmok_receptionist"
var _player: PlayerController
var _controller: QuestController
var _dialog: QuestDialog
var _hud: Hud
var _available := false


func setup(
	player: PlayerController, controller: QuestController, dialog: QuestDialog, hud: Hud
) -> void:
	_player = player
	_controller = controller
	_dialog = dialog
	_hud = hud
	process_priority = 10


func _process(_delta: float) -> void:
	update_target()


func update_target() -> void:
	var was_available := _available
	_available = _can_interact()
	_player.set_meta("npc_interaction_available", _available)
	if _available:
		_controller.journal.record_event("REACH", npc_id, "", 0)
		_hud.show_interaction_prompt("대화", global_position - Vector2(0, 24))
	elif was_available:
		_hud.hide_interaction_prompt()


func _can_interact() -> bool:
	if _player == null or get_tree().paused:
		return false
	if (
		_player.is_input_locked
		or _player.is_hit_stunned
		or _player.get_node("PlayerStats").is_dead()
		or _player.attack_state != PlayerController.AttackState.NONE
		or _player.skill_state != PlayerController.AttackState.NONE
		or _player.is_dashing
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
	if opened:
		_hud.hide_interaction_prompt()
	return opened


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and interact():
		get_viewport().set_input_as_handled()
