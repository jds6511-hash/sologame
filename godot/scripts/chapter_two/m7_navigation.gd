extends RefCounted
const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")
const LayoutM7 = preload("res://scripts/chapter_two/m7_layout.gd")

static func targets(world: Node) -> Array:
	var controller := world.get_node_or_null("QuestController")
	if controller == null:
		return []
	var journal: QuestJournal = controller.journal
	var states := journal.export_state()
	if states.get("MQ-01-05", {}).get("state") != "completed":
		# 기존 목표 조회는 후보 훅을 다시 부르지 않는 본문을 사용한다.
		return load("res://scripts/quests/quest_navigation.gd").local_targets(world)
	for id in journal.catalog.ordered_ids():
		if not id.begins_with("MQ-02"):
			continue
		var state: Dictionary = states.get(id, {})
		if state.get("state") == "completed":
			continue
		var definition: QuestData = journal.catalog.definitions[id]
		if state.is_empty() or state.state == "ready":
			return _project(world, "novera_commons", [Vector2(480, 320)], ("수락: " if state.is_empty() else "보고: ") + definition.title)
		for index in definition.objective_counts.size():
			if state.counts[index] >= definition.objective_counts[index]:
				continue
			var target: String = definition.objective_targets[index]
			var source: String = definition.objective_sources[index]
			var label: String = definition.objective_labels[index]
			if LayoutM7.HABITATS.has(source):
				return _project(world, "novera_outskirts", LayoutM7.HABITATS[source], label)
			if LayoutM7.SITES.has(target):
				return _project(world, "novera_outskirts", [LayoutM7.SITES[target][0]], label)
			if target == "novera_trainer":
				return _project(world, "novera_commons", [Vector2(544, 320)], label)
	return _project(world, "novera_commons", [Vector2(544, 320)], "이번 구간 완료 · 전직 [V] / 정비")

static func _project(world: Node, region: String, points: Array, label: String) -> Array:
	if region != world.map_id:
		var gate := RegionsM7.next_gate(world.map_id, region)
		if gate == "":
			return []
		return [{"position": RegionsM7.EDGES[gate][2], "label": RegionsM7.NAMES[region] + " 방향 · " + label}]
	var result := []
	for point in points:
		result.append({"position": point, "label": label})
	return result
