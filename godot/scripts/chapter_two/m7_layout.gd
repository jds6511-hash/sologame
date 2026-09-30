extends RefCounted
const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")
const HABITATS := {
	"novera_dog_habitat": [Vector2(384, 560), Vector2(608, 560), Vector2(832, 560)],
	"novera_water_habitat": [Vector2(448, 352), Vector2(672, 352), Vector2(896, 352)],
	"novera_rift_habitat": [Vector2(544, 128), Vector2(736, 128), Vector2(928, 128), Vector2(1120, 128)],
}
const SITES := {
	"novera_water_marker": [Vector2(352, 272), "novera_water_site", "REACH", "물가 통행 표식"],
	"novera_rift_marker": [Vector2(1120, 272), "novera_rift_site", "INTERACT", "균열 흔적 조사"],
	"novera_patrol_marker": [Vector2(272, 128), "novera_patrol_site", "REACH", "외곽 정찰 표식"],
}

static func prepare(world: Node2D) -> void:
	var bounds: Rect2 = RegionsM7.BOUNDS[world.map_id]
	world.set_meta("region_bounds", bounds)
	load("res://scripts/world/region_boundary.gd").install(world, bounds)
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
