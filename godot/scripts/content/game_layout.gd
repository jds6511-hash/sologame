extends RefCounted
const Content = preload("res://scripts/content/game_content.gd")
const Boundary = preload("res://scripts/world/region_boundary.gd")


static func prepare(world: Node2D) -> void:
	if Content.LAYOUTS.has(world.map_id):
		_prepare_generated(world)
	elif world.map_id == "novera_rift":
		_prepare_rift(world)
	else:
		_prepare_field(world)


static func _prepare_generated(world: Node2D) -> void:
	var data: Dictionary = Content.LAYOUTS[world.map_id]
	var bounds: Rect2 = Content.BOUNDS[world.map_id]
	world.set_meta("region_bounds", bounds)
	Boundary.install(world, bounds)
	var ground: TileMapLayer = world.get_node("Ground")
	ground.clear()
	var dimensions := Vector2i(bounds.size / 16)
	for y in dimensions.y:
		for x in dimensions.x:
			var cell := Vector2i(x, y)
			var tile: Vector2i = data.floor
			for patch in data.patches:
				if patch.rect.has_point(cell):
					tile = patch.tile
			if y in [0, dimensions.y - 1] or x in [0, dimensions.x - 1]:
				tile = Vector2i(2, 3)
			ground.set_cell(cell, 0, tile)
	for group in world.get_node("Markers").get_children():
		if String(group.name).begins_with("MonsterSpawns_"):
			for child in group.get_children():
				group.remove_child(child)
				child.free()
	world.get_node("Player").position = data.spawn
	world.get_node("Player/PlayerStats").set_respawn_position(data.spawn)
	var camera: Camera2D = world.get_node("Player/Camera2D")
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)


static func _prepare_field(world: Node2D) -> void:
	var bounds: Rect2 = Content.BOUNDS[world.map_id]
	world.set_meta("region_bounds", bounds)
	Boundary.install(world, bounds)
	var ground: TileMapLayer = world.get_node("Ground")
	ground.clear()
	var dimensions := Vector2i(bounds.size / 16)
	for y in dimensions.y:
		for x in dimensions.x:
			var tile := Vector2i(0, 0)
			if y in [0, dimensions.y - 1] or x in [0, dimensions.x - 1]:
				tile = Vector2i(2, 3)
			elif world.map_id == "novera_commons":
				if y in range(18, 28) or x in range(28, 36):
					tile = Vector2i(2, 2)
				elif y in range(9, 14) and x in range(20, 44):
					tile = Vector2i(1, 2)
			else:
				if y in range(23, 26) or x in range(16, 19):
					tile = Vector2i(2, 0)
				elif y in range(27, 30) and x in range(25, 65):
					tile = Vector2i(1, 1)
			ground.set_cell(Vector2i(x, y), 0, tile)
	for group in world.get_node("Markers").get_children():
		if String(group.name).begins_with("MonsterSpawns_"):
			for child in group.get_children():
				group.remove_child(child)
				child.free()
	world.get_node("Player").position = Vector2(144, 384)
	world.get_node("Player/PlayerStats").set_respawn_position(Vector2(144, 384))
	var camera: Camera2D = world.get_node("Player/Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.size.x)
	camera.limit_bottom = int(bounds.size.y)


static func _prepare_rift(world: Node2D) -> void:
	var bounds: Rect2 = Content.BOUNDS[world.map_id]
	world.set_meta("region_bounds", bounds)
	Boundary.install(world, bounds)
	var ground: TileMapLayer = world.get_node("Ground")
	ground.clear()
	for y in int(bounds.size.y / 16):
		for x in int(bounds.size.x / 16):
			var tile := Vector2i(2, 2)
			if x in [0, int(bounds.size.x / 16) - 1] or y in [0, int(bounds.size.y / 16) - 1]:
				tile = Vector2i(2, 3)
			elif x in [20, 48] and y not in range(17, 24):
				tile = Vector2i(1, 2)
			ground.set_cell(Vector2i(x, y), 0, tile)
	for group in world.get_node("Markers").get_children():
		if String(group.name).begins_with("MonsterSpawns_"):
			for child in group.get_children():
				group.remove_child(child)
				child.free()
	world.get_node("Player").position = Vector2(144, 320)
	world.get_node("Player/PlayerStats").set_respawn_position(Vector2(144, 320))
	var camera: Camera2D = world.get_node("Player/Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.size.x)
	camera.limit_bottom = int(bounds.size.y)
