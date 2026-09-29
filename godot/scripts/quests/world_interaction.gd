## 월드 상호작용 선택·프롬프트·입력의 단일 소유자. 아이템의 폴링은 메타로 억제한다.
extends Node

var player: PlayerController
var hud: Hud
var candidates: Array[Node2D] = []
var selected: Node2D


func setup(actor: PlayerController, display: Hud) -> void:
	player = actor
	hud = display
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	selected = null
	if is_instance_valid(player) and not get_tree().paused:
		for candidate in candidates:
			if not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
				continue
			candidate.update_target()
			if candidate.can_interact() and (selected == null or _before(candidate, selected)):
				selected = candidate
	if is_instance_valid(player):
		player.set_meta("world_interaction_available", selected != null)
	if is_instance_valid(hud):
		if selected != null:
			var anchor := selected.global_position - Vector2(0, 24)
			if selected.has_method("interaction_prompt_position"):
				anchor = selected.interaction_prompt_position()
			hud.show_interaction_prompt(selected.interaction_verb(), anchor, "F", self)
		else:
			hud.hide_interaction_prompt(self)


func _before(a: Node2D, b: Node2D) -> bool:
	if a.interaction_priority() != b.interaction_priority():
		return a.interaction_priority() < b.interaction_priority()
	var da := player.global_position.distance_squared_to(a.global_position)
	var db := player.global_position.distance_squared_to(b.global_position)
	if not is_equal_approx(da, db):
		return da < db
	return a.interaction_id() < b.interaction_id()


func interact() -> bool:
	refresh()
	if selected == null:
		return false
	# 해당 프레임에 선택이 ready/삭제/pause로 바뀌어도 폴링 줍기가 함께 실행되지 않는다.
	player.set_meta("world_interaction_consumed_frame", Engine.get_process_frames())
	var handled: bool = selected.interact()
	refresh()
	return handled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo() and interact():
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(player):
		player.set_meta("world_interaction_available", false)
		player.remove_meta("world_interaction_consumed_frame")
	if is_instance_valid(hud):
		hud.hide_interaction_prompt(self)
