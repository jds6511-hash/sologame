extends "res://scripts/economy/economy_environment.gd".CandidateWorld
const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")
const LayoutM7 = preload("res://scripts/chapter_two/m7_layout.gd")


func _init_bgm() -> void:
	BgmManager.play_for_scene(map_id if map_id == "novera_outskirts" else scene_file_path)
	BgmManager.bind_job_transition(_player.get_node_or_null("PlayerJobTransition"))


func _create_save_session() -> Node:
	return load("res://scripts/chapter_two/m7_environment.gd").SessionM7.new()


func _prepare_region() -> void:
	if map_id in ["eastern_frontier_start", "novera_gate"]:
		super._prepare_region()
	else:
		LayoutM7.prepare(self)
	set_meta("region_bounds", RegionsM7.BOUNDS[map_id])


func _setup_quest_ui(quests: QuestController) -> void:
	if map_id in ["eastern_frontier_start", "novera_gate"]:
		super._setup_quest_ui(quests)
	else:
		_integrated_menu.bind_quests(quests.journal)
		var dialog := QuestDialog.new()
		dialog.name = "QuestDialog"
		add_child(dialog)
		dialog.setup(quests)
		var tracker = load("res://scripts/ui/quest_tracker.gd").new()
		tracker.name = "QuestTracker"
		add_child(tracker)
		tracker.setup(quests)
		var selection = load("res://scripts/quests/world_interaction.gd").new()
		selection.name = "WorldInteraction"
		add_child(selection)
		selection.setup(_player, _hud)
	for id in RegionsM7.EDGES:
		if (
			RegionsM7.EDGES[id][0] == map_id
			and id not in ["yeoulmok_gatewarden", "novera_gatewarden"]
		):
			var npc := _npc(id, RegionsM7.EDGES[id][2], quests.journal.catalog.npc_names[id])
			npc.set_meta("region_gate", true)
	if map_id == "novera_commons":
		_npc("novera_receptionist", Vector2(480, 320), "노베라 조합 접수원")
		_npc("novera_trainer", Vector2(544, 320), "전직 안내인")
	if map_id == "novera_outskirts":
		for id in LayoutM7.SITES:
			var data: Array = LayoutM7.SITES[id]
			var site = load("res://scripts/chapter_two/m7_site.gd").new()
			site.npc_id = id
			site.source = data[1]
			site.kind = data[2]
			site.position = data[0]
			_name_label(site, data[3])
			add_child(site)
			site.setup(_player, quests, get_node("QuestDialog"), _hud)
			get_node("WorldInteraction").candidates.append(site)


func _npc(id: String, point: Vector2, title: String) -> Node2D:
	var npc = load("res://scenes/npc/quest_receptionist.tscn").instantiate()
	npc.npc_id = id
	npc.position = point
	npc.get_node("Name").text = title
	add_child(npc)
	npc.setup(_player, get_node("QuestController"), get_node("QuestDialog"), _hud)
	get_node("WorldInteraction").candidates.append(npc)
	return npc


func _name_label(node: Node2D, title: String) -> void:
	var label := Label.new()
	label.name = "Name"
	label.text = title
	label.position = Vector2(-40, -36)
	label.size = Vector2(80, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(label)


func _ready() -> void:
	super._ready()
	if String(get_meta("save_boot_error", "")) != "":
		return
	for child in get_node("EconomyPanel").get_children():
		if child is Label:
			child.text = "M7 후보 · " + RegionsM7.NAMES[map_id] + "\n목표 지도 [M] · 의뢰 [J] · 전직 [V]"
	if map_id == "novera_gate":
		for child in get_children():
			if child is Label and "준비 중" in child.text:
				child.text = "노베라 성문\n동쪽 관문 → 조합 거리"
	if map_id == "novera_commons":
		var merchant = load("res://scripts/economy/economy_merchant.gd").new()
		merchant.name = "Merchant"
		merchant.position = Vector2(416, 416)
		add_child(merchant)
		merchant.configure(_player, get_node("EconomyPanel"))
		get_node("WorldInteraction").candidates.append(merchant)
	if map_id == "novera_outskirts":
		var spawns = load("res://scripts/chapter_two/m7_spawner.gd").new()
		spawns.name = "OutskirtsSpawner"
		add_child(spawns)
		spawns.start(self)


func quest_targets() -> Array:
	return load("res://scripts/chapter_two/m7_navigation.gd").targets(self)
