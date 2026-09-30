extends RefCounted
const RegionsClosure = preload("res://scripts/chapter_two_closure/closure_regions.gd")
const HABITATS := {
	"novera_dungeon_habitat": [Vector2(544, 400), Vector2(704, 400), Vector2(848, 400)]
}
const SITES := {
	"novera_return_record_a":
	[Vector2(400, 272), "novera_return_record_a_site", "INTERACT", "서쪽 귀환 기록", "novera_outskirts"],
	"novera_return_record_b":
	[Vector2(1072, 384), "novera_return_record_b_site", "INTERACT", "동쪽 귀환 기록", "novera_outskirts"],
	"novera_rift_chamber":
	[Vector2(432, 320), "novera_rift_chamber_site", "REACH", "조사실 도달 표식", "novera_rift"],
	"novera_rift_relic":
	[Vector2(928, 272), "novera_rift_relic_site", "INTERACT", "유물 조사", "novera_rift"],
	"novera_rift_record_a":
	[Vector2(224, 240), "novera_rift_record_a_site", "INTERACT", "입구실 측량 기록", "novera_rift"],
	"novera_rift_record_b":
	[Vector2(656, 272), "novera_rift_record_b_site", "INTERACT", "조사실 측량 기록", "novera_rift"],
}
const GARETH := Vector2(656, 320)


static func prepare(world: Node2D) -> void:
	var bounds: Rect2 = RegionsClosure.BOUNDS[world.map_id]
	world.set_meta("region_bounds", bounds)
	load("res://scripts/world/region_boundary.gd").install(world, bounds)
	var ground: TileMapLayer = world.get_node("Ground")
	ground.clear()
	for y in 40:
		for x in 64:
			var tile := Vector2i(2, 2)
			if x in [0, 63] or y in [0, 39]:
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
	camera.limit_right = 1024
	camera.limit_bottom = 640
