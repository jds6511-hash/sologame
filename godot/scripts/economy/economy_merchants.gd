extends RefCounted


## UI와 확정 거래가 같은 월드의 실제 상인 위치를 사용한다.
static func nearest(player: Node2D) -> Node2D:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return null
	var nearest_node: Node2D = null
	var distance := INF
	for node in player.get_parent().get_children():
		if not node is Node2D or not node.get_meta("economy_merchant", false):
			continue
		if node.is_queued_for_deletion() or not node.trade_enabled:
			continue
		var current: float = player.global_position.distance_to(node.global_position)
		if current <= node.trade_radius and current < distance:
			distance = current
			nearest_node = node
	return nearest_node
