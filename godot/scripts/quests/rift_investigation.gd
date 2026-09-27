extends Node2D

const SOURCE := "yeoulmok_old_rift_site"
var player: PlayerController
var controller: QuestController
var reach_position: Vector2


func setup(actor: PlayerController, quests: QuestController, entrance: Vector2) -> void:
	player = actor
	controller = quests
	reach_position = entrance
	var label := Label.new()
	label.text = "균열 표식"
	label.position = Vector2(-18, -18)
	label.add_theme_font_size_override("font_size", 8)
	add_child(label)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(0.35, 0.8, 0.9))
	draw_line(Vector2(-3, -6), Vector2(2, 6), Color(0.1, 0.2, 0.3), 2.0)


func update_target() -> void:
	if can_reach():
		controller.journal.record_event("REACH", "yeoulmok_old_rift_entrance", SOURCE, 0)


func can_reach() -> bool:
	return (
		is_instance_valid(player)
		and not get_tree().paused
		and not player.get_node("PlayerStats").is_dead()
		and player.global_position.distance_to(reach_position) <= 32.0
		and _visible_from(reach_position)
	)


func can_interact() -> bool:
	if not is_instance_valid(player) or get_tree().paused:
		return false
	var state: Dictionary = controller.journal.export_state().get("MQ-01-04", {})
	return (
		state.get("state") == "active"
		and state.get("counts") == [1, 0]
		and not player.is_input_locked
		and not player.is_hit_stunned
		and not player.get_node("PlayerStats").is_dead()
		and player.attack_state == PlayerController.AttackState.NONE
		and player.skill_state == PlayerController.AttackState.NONE
		and not player.is_dashing
		and player.global_position.distance_to(global_position) <= 40.0
		and _visible_from(global_position)
	)


func _visible_from(point: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(player.global_position, point, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func interact() -> bool:
	if not can_interact():
		return false
	controller.journal.record_event("INTERACT", "yeoulmok_rift_mark", SOURCE, 0)
	return true


func interaction_id() -> String:
	return "yeoulmok_rift_mark"


func interaction_priority() -> int:
	return 1


func interaction_verb() -> String:
	return "조사"
