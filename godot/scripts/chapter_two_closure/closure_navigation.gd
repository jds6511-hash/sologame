extends RefCounted
const RegionsClosure = preload("res://scripts/chapter_two_closure/closure_regions.gd")
const LayoutClosure = preload("res://scripts/chapter_two_closure/closure_layout.gd")
const OldLayout = preload("res://scripts/chapter_two/m7_layout.gd")


static func targets(world: Node) -> Array:
	var journal: QuestJournal = world.get_node("QuestController").journal
	var states := journal.export_state()
	if states.get("MQ-01-05", {}).get("state") != "completed":
		return load("res://scripts/quests/quest_navigation.gd").local_targets(world)
	var catalog = journal.catalog
	var ids: Array = catalog.available_ids(states)
	var active := []
	for id in ids:
		if states.has(id):
			active.append(id)
	for id in ids:
		if not states.has(id):
			active.append(id)
	ids = active
	if catalog.selected_quest_id in ids:
		ids.erase(catalog.selected_quest_id)
		ids.push_front(catalog.selected_quest_id)
	if ids.is_empty():
		return _project(world, "novera_commons", [LayoutClosure.GARETH], "2장 메인 완료 · 후속 이야기 준비 중")
	var id: String = ids[0]
	var definition: QuestData = catalog.definitions[id]
	var state: Dictionary = states.get(id, {})
	if state.is_empty() or state.state == "ready":
		var npc := definition.giver_id() if state.is_empty() else definition.npc_id
		var point := LayoutClosure.GARETH if npc == "novera_gareth" else Vector2(480, 320)
		return _project(
			world,
			"novera_commons",
			[point],
			("수락: " if state.is_empty() else "보고: ") + definition.title
		)
	for index in definition.objective_counts.size():
		if state.counts[index] >= definition.objective_counts[index]:
			continue
		var target: String = definition.objective_targets[index]
		var source: String = definition.objective_sources[index]
		var label: String = definition.objective_labels[index]
		if LayoutClosure.SITES.has(target):
			var site: Array = LayoutClosure.SITES[target]
			return _project(world, site[4], [site[0]], label)
		if LayoutClosure.HABITATS.has(source):
			return _project(world, "novera_rift", LayoutClosure.HABITATS[source], label)
		if OldLayout.HABITATS.has(source):
			return _project(world, "novera_outskirts", OldLayout.HABITATS[source], label)
		if OldLayout.SITES.has(target):
			return _project(world, "novera_outskirts", [OldLayout.SITES[target][0]], label)
		if target in ["novera_gareth", "novera_trainer"]:
			return _project(
				world,
				"novera_commons",
				[LayoutClosure.GARETH if target == "novera_gareth" else Vector2(544, 320)],
				label
			)
	return []


static func _project(world: Node, region: String, points: Array, label: String) -> Array:
	if region != world.map_id:
		var gate := RegionsClosure.next_gate(world.map_id, region)
		if gate == "":
			return []
		return [
			{
				"position": RegionsClosure.EDGES[gate][2],
				"label": RegionsClosure.NAMES[region] + " 방향 · " + label
			}
		]
	var result := []
	for point in points:
		result.append({"position": point, "label": label})
	return result
