extends RefCounted
const Content = preload("res://scripts/content/game_content.gd")


static func targets(world: Node) -> Array:
	var journal: QuestJournal = world.get_node("QuestController").journal
	var states := journal.export_state()
	var catalog = journal.catalog
	var ids: Array = catalog.available_ids(states)
	var selected_id := String(journal.get_meta("selected_quest_id", ""))
	if selected_id in ids:
		ids.erase(selected_id)
		ids.push_front(selected_id)
	if ids.is_empty():
		return _project(
			world, "novera_commons", [Content.NPCS["novera_examiner"][1]], "1막 완료 · 여울목 복구권"
		)
	var id: String = ids[0]
	var definition: QuestData = catalog.definitions[id]
	var state: Dictionary = states.get(id, {})
	if state.get("state") == "ready" and catalog.allows_field_report(id):
		return []
	if state.is_empty() or state.state == "ready":
		var npc := definition.giver_id() if state.is_empty() else definition.npc_id
		return _npc(world, npc, ("수락: " if state.is_empty() else "보고: ") + definition.title)
	for index in definition.objective_counts.size():
		if state.counts[index] >= definition.objective_counts[index]:
			continue
		var target: String = definition.objective_targets[index]
		var source: String = definition.objective_sources[index]
		var label: String = definition.objective_labels[index]
		if Content.TRIAL_TARGETS.has(source):
			var points := []
			if world.has_node("JobTrialManager"):
				for monster in world.get_node("JobTrialManager").targets():
					if not monster.is_dead() and not monster.is_queued_for_deletion() and monster.trial_source == source:
						points.append(monster.global_position)
			return _project(world, "durgan_training", points if not points.is_empty() else [Vector2(224, 352)], label if not points.is_empty() else "훈련 시작 / 재개 [F] · " + label)
		if Content.MARKER_HABITATS.has(source):
			var habitat: Array = Content.MARKER_HABITATS[source]
			var markers := world.get_node_or_null(habitat[1])
			var points := []
			if markers != null:
				for marker in markers.get_children():
					points.append(marker.position)
			return _project(world, habitat[0], points, label)
		if Content.SITES.has(target):
			var site: Array = Content.SITES[target]
			return _project(world, site[4], [site[0]], label)
		if Content.HABITATS.has(source):
			var habitat: Array = Content.HABITATS[source]
			return _project(world, habitat[0], habitat[1], label)
		if Content.DEFENSE_WAVES.has(source):
			var wave: Dictionary = Content.DEFENSE_WAVES[source]
			var points := []
			if world.map_id == wave.region:
				for monster in world.get_node("MonsterSpawner").get_children():
					if (
						monster is MonsterBase
						and not monster.is_queued_for_deletion()
						and monster.get_meta("spawn_source_id", "") == source
						and not monster.is_dead()
					):
						points.append(monster.global_position)
			if points.is_empty():
				for rally in Content.RALLIES.values():
					if rally.region == wave.region:
						return _project(
							world, wave.region, [rally.position], "방어 재개 [F] · " + label
						)
			return _project(world, wave.region, points, label)
		if Content.NPCS.has(target):
			return _project(world, Content.NPCS[target][0], [Content.NPCS[target][1]], label)
		if Content.EDGES.has(target):
			return _npc(world, target, label)
	return []


static func _npc(world: Node, id: String, label: String) -> Array:
	if Content.NPCS.has(id):
		return _project(world, Content.NPCS[id][0], [Content.NPCS[id][1]], label)
	if Content.EDGES.has(id):
		return _project(world, Content.EDGES[id][0], [Content.EDGES[id][2]], label)
	return []


static func _project(world: Node, region: String, points: Array, label: String) -> Array:
	if region != world.map_id:
		var gate := Content.next_gate(world.map_id, region)
		if gate == "":
			return []
		return [
			{"position": Content.EDGES[gate][2], "label": Content.NAMES[region] + " 방향 · " + label}
		]
	var result := []
	for point in points:
		result.append({"position": point, "label": label})
	return result
