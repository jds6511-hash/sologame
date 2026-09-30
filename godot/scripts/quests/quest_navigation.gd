extends RefCounted
## 현재 메인 목표의 표시 위치. 진행/보상에는 쓰지 않는 읽기 전용 투영.

const Regions = preload("res://scripts/world/region_registry.gd")
const HABITATS := {
	"yeoulmok_rabbit_habitat": "Markers/MonsterSpawns_뿔토끼",
	"yeoulmok_dog_habitat": "Markers/MonsterSpawns_들개마수"
}


static func targets(world: Node) -> Array:
	var controller := world.get_node_or_null("QuestController") as QuestController
	if controller == null:
		return []
	var journal := controller.journal
	var states := journal.export_state()
	for id in journal.catalog.ORDER:
		var definition: QuestData = journal.catalog.definitions[id]
		var state: Dictionary = states.get(id, {})
		if state.get("state") == "completed":
			continue
		if state.is_empty():
			return _npc(world, definition.giver_id(), "수락: " + definition.title)
		if state.state == "ready":
			return _npc(world, definition.npc_id, "보고: " + definition.title)
		for index in definition.objective_counts.size():
			if state.counts[index] >= definition.objective_counts[index]:
				continue
			var target: String = definition.objective_targets[index]
			var source: String = definition.objective_sources[index]
			var label: String = definition.objective_labels[index]
			if definition.objective_kinds[index] == "KILL" and HABITATS.has(source):
				var markers := world.get_node_or_null(HABITATS[source])
				var result := []
				if markers != null:
					for marker in markers.get_children():
						result.append({"position": marker.global_position, "label": label})
				return result
			if target in ["yeoulmok_old_rift_entrance", "yeoulmok_rift_mark"]:
				var site := world.get_node_or_null("RiftInvestigation")
				if site != null:
					var point: Vector2 = site.reach_position if target.ends_with("entrance") else site.global_position
					return [{"position": point, "label": label}]
			return _npc(world, target, label)
	if states.get("MQ-01-05", {}).get("state") == "completed":
		return [{"position": Regions.GATES[world.map_id], "label": "관문 이동 [F]"}]
	return []


static func _npc(world: Node, id: String, label: String) -> Array:
	for node in world.get_children():
		if node is Node2D and node.get("npc_id") == id:
			return [{"position": node.global_position, "label": label}]
	return []
