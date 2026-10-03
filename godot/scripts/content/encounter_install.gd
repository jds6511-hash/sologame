extends RefCounted
const Content = preload("res://scripts/content/game_content.gd")
const Controller = preload("res://scripts/content/encounter_controller.gd")
const Rally = preload("res://scripts/content/encounter_rally.gd")

static func install(world: Node2D) -> Node:
	var config := {}
	for id in Content.ENCOUNTERS:
		if Content.ENCOUNTERS[id].region == world.map_id:
			config[id] = Content.ENCOUNTERS[id]
	if config.is_empty():
		return null
	var manager := Controller.new()
	manager.name = "EncounterController"
	world.add_child(manager)
	manager.setup(world, config)
	var display = load("res://scripts/content/encounter_display.gd").new()
	manager.add_child(display)
	display.setup(manager)
	for id in config:
		var rally := Rally.new()
		rally.position = config[id].position
		var label := Label.new()
		label.name = "Name"
		label.text = config[id].title
		label.position = Vector2(-100, -36)
		label.size = Vector2(200, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rally.add_child(label)
		world.add_child(rally)
		rally.setup(world.get_node("Player"), world.get_node("QuestController"),
			world.get_node("QuestDialog"), world.get_node("Hud"))
		rally.configure(manager, id, config[id])
		world.get_node("WorldInteraction").candidates.append(rally)
	return manager
