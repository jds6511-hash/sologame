## 기존 실제 수락/처치/줍기/여행 흐름을 후보 장비 런타임에서 그대로 실행한다.
extends "res://../docs/qa/tools/yeoulmok_onboarding_probe.gd"


func _initialize() -> void:
	save_root = "user://m6_candidate_onboarding"
	super._initialize()


func _instantiate_onboarding_world() -> Node:
	return load("res://scripts/economy/economy_environment.gd").instantiate_world()


func _navigation_pitch() -> int:
	return 8


func _pickup_destination(drop: Node2D) -> Vector2:
	# 드롭 중심에 서지 않아도 실제 Area2D 프롬프트가 켜지면 줍기가 가능하다.
	# 충돌/아이템 위치는 변경하지 않는다. 도착 후 원래 프롬프트와 수량 검사는 그대로 수행한다.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.collision_mask = player.collision_mask
	for offset in [
		Vector2.ZERO,
		Vector2(0, -8),
		Vector2(-8, 0),
		Vector2(8, 0),
		Vector2(0, 8),
		Vector2(0, -12),
		Vector2(-12, 0),
		Vector2(12, 0),
		Vector2(0, 12)
	]:
		var destination: Vector2 = drop.position + offset
		query.transform = Transform2D(0, destination)
		if (
			world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
			and not _route(destination).is_empty()
		):
			return destination
	return drop.position
