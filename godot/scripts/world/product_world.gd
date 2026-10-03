extends "res://scripts/world/eastern_frontier_starting_area.gd"
const TerritoryManager = preload("res://scripts/territory/territory_manager.gd")
const Content = preload("res://scripts/content/game_content.gd")
const Runtime = preload("res://scripts/economy/economy_runtime.gd")
const Site = preload("res://scripts/content/game_site.gd")


func _create_save_session() -> Node:
	return load("res://scripts/save/product_save.gd").Session.new()


func _prepare_region() -> void:
	if map_id in ["eastern_frontier_start", "novera_gate"]:
		super._prepare_region()
	else:
		load("res://scripts/content/game_layout.gd").prepare(self)
	set_meta("region_bounds", Content.BOUNDS[map_id])


func _init_bgm() -> void:
	BgmManager.play_for_scene(Content.BGM_CONTEXTS[map_id])
	BgmManager.bind_job_transition(_player.get_node_or_null("PlayerJobTransition"))


func _setup_quest_ui(quests: QuestController) -> void:
	load("res://scripts/content/game_selection.gd").select_quest(
		quests.journal, String(get_meta("selected_quest_id", ""))
	)
	_integrated_menu.bind_quests(quests.journal)
	var dialog = load("res://scripts/content/game_dialog.gd").new()
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
	for id in Content.NPCS:
		var data: Array = Content.NPCS[id]
		if data[0] == map_id:
			_npc(id, data[1], data[2])
	for id in Content.EDGES:
		var edge: Array = Content.EDGES[id]
		if edge[0] == map_id:
			var npc := _npc(id, edge[2], quests.journal.catalog.npc_names[id])
			npc.set_meta("region_gate", true)
	if map_id == "eastern_frontier_start":
		var site = load("res://scripts/quests/rift_investigation.gd").new()
		site.name = "RiftInvestigation"
		site.position = Content.SITES["yeoulmok_rift_mark"][0]
		add_child(site)
		site.setup(_player, quests, Content.SITES["yeoulmok_old_rift_entrance"][0])
		selection.candidates.append(site)
	for id in Content.SITES:
		var data: Array = Content.SITES[id]
		if data[4] != map_id or id in ["yeoulmok_rift_mark", "yeoulmok_old_rift_entrance"]:
			continue
		var site = Site.new()
		site.npc_id = id
		site.source = data[1]
		site.kind = data[2]
		site.position = data[0]
		_name_label(site, data[3])
		add_child(site)
		site.setup(_player, quests, dialog, _hud)
		selection.candidates.append(site)
	var has_rally := false
	for data in Content.RALLIES.values():
		has_rally = has_rally or data.region == map_id
	if has_rally:
		var defense = load("res://scripts/content/defense_spawner.gd").new()
		defense.name = "DefenseSpawner"
		add_child(defense)
		defense.start(self)
		for id in Content.RALLIES:
			var data: Dictionary = Content.RALLIES[id]
			if data.region != map_id:
				continue
			var rally = load("res://scripts/content/defense_rally.gd").new()
			rally.npc_id = id
			rally.position = data.position
			_name_label(rally, data.title)
			add_child(rally)
			rally.setup(_player, quests, dialog, _hud)
			rally.configure(defense)
			selection.candidates.append(rally)
	load("res://scripts/content/job_trial_install.gd").install(self)


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
	if not _player.has_meta("economy_candidate"):
		var runtime := Runtime.new()
		runtime.model = load("res://scripts/economy/product_economy.gd").new()
		runtime.name = "Economy"
		_player.add_child(runtime)
		runtime.install(_player, true)
	var panel = load("res://scripts/economy/economy_panel.gd").new()
	panel.name = "EconomyPanel"
	add_child(panel)
	panel.setup(_player.get_meta("economy_candidate"))
	for point in Content.MERCHANTS.get(map_id, []):
		var merchant = load("res://scripts/economy/economy_merchant.gd").new()
		merchant.name = "Merchant"
		merchant.position = point
		add_child(merchant)
		merchant.configure(_player, panel)
		get_node("WorldInteraction").candidates.append(merchant)
	if map_id == "novera_gate":
		for child in get_children():
			if child is Label and "준비 중" in child.text:
				child.text = "노베라 성문\n동쪽 관문 → 조합 거리"
	var has_habitats := false
	for habitat in Content.HABITATS.values():
		has_habitats = has_habitats or habitat[0] == map_id
	if has_habitats:
		var spawns = load("res://scripts/content/game_spawner.gd").new()
		spawns.name = "ContentSpawner"
		add_child(spawns)
		spawns.start(self)
	var territory = load("res://scripts/territory/territory_runtime.gd").new()
	territory.name = "TerritoryRuntime"
	add_child(territory)
	territory.setup(self)
	var territory_panel = load("res://scripts/territory/territory_panel.gd").new()
	territory_panel.name = "TerritoryPanel"
	add_child(territory_panel)
	territory_panel.setup(territory)
	if map_id == "eastern_frontier_start":
		var manager = TerritoryManager.new()
		manager.position = territory.DESK
		add_child(manager)
		manager.configure(_player, territory_panel)
		get_node("WorldInteraction").candidates.append(manager)
	elif load("res://scripts/territory/territory_travel.gd").is_city(map_id):
		var gate = TerritoryManager.new()
		gate.name = "CityWarpGate"
		gate.position = Content.WARP_ARRIVALS[map_id]
		add_child(gate)
		gate.configure(_player, territory_panel, true)
		get_node("WorldInteraction").candidates.append(gate)


func quest_targets() -> Array:
	return load("res://scripts/content/game_navigation.gd").targets(self)
