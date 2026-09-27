class_name UiPauseArbiter
extends Node

var _holder: Node


static func for_world(world: Node) -> UiPauseArbiter:
	var arbiter := world.get_node_or_null("UiPauseArbiter") as UiPauseArbiter
	if arbiter == null:
		arbiter = UiPauseArbiter.new()
		arbiter.name = "UiPauseArbiter"
		world.add_child(arbiter)
	return arbiter


func acquire(holder: Node) -> bool:
	if not is_instance_valid(holder) or not holder.is_inside_tree():
		return false
	if _holder == holder:
		return true
	if is_instance_valid(_holder) or get_tree().paused:
		return false
	_holder = holder
	_holder.tree_exiting.connect(_holder_exiting, CONNECT_ONE_SHOT)
	get_tree().paused = true
	return true


func release(holder: Node) -> void:
	if _holder != holder or not is_instance_valid(_holder):
		return
	if _holder.tree_exiting.is_connected(_holder_exiting):
		_holder.tree_exiting.disconnect(_holder_exiting)
	_holder = null
	get_tree().paused = false


func suspend() -> Node:
	var previous := _holder
	if is_instance_valid(previous):
		release(previous)
	return previous


func _holder_exiting() -> void:
	_holder = null
	get_tree().paused = false


func _exit_tree() -> void:
	if is_instance_valid(_holder):
		release(_holder)
