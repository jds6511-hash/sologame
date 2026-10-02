extends RefCounted
const Content = preload("res://scripts/content/game_content.gd")

static func instantiate_world(region: String = "eastern_frontier_start") -> Node:
	if not Content.SCENES.has(region):
		return null
	var world = load(Content.SCENES[region]).instantiate()
	world.map_id = region
	world.set_meta("save_directory", "user://saves")
	return world
