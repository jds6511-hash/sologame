extends RefCounted
## 기존 타일셋으로 만든 노베라 입구 통행 구역. 도시 전체가 아니다.


static func prepare(world: Node2D) -> void:
	var ground: TileMapLayer = world.get_node("Ground")
	ground.clear()
	for y in 36:
		for x in 48:
			var tile := Vector2i(0, 0)
			if x in [0, 47] or y in [0, 35]:
				tile = Vector2i(2, 3)
			elif y in [26, 27, 28] or (x >= 20 and x <= 34 and y >= 15 and y <= 28):
				tile = Vector2i(2, 2)
			elif y == 14 and x >= 19 and x <= 35:
				tile = Vector2i(1, 2)
			elif x in [19, 35] and y >= 14 and y <= 25:
				tile = Vector2i(1, 2)
			ground.set_cell(Vector2i(x, y), 0, tile)
	for markers in world.get_node("Markers").get_children():
		if String(markers.name).begins_with("MonsterSpawns_"):
			for marker in markers.get_children():
				markers.remove_child(marker)
				marker.free()
	world.get_node("Player").position = Vector2(144, 440)
	world.get_node("Player/PlayerStats").set_respawn_position(Vector2(144, 440))
	var notice := Label.new()
	notice.text = "노베라 성문\n도시·다음 의뢰 준비 중"
	notice.position = Vector2(360, 200)
	notice.add_theme_font_size_override("font_size", 8)
	world.add_child(notice)
