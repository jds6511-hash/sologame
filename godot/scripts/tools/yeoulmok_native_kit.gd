## 정수 픽셀 원본과 명시 앵커를 사용하는 격리된 여울목 비교 키트.
extends RefCounted

const DIRECTORY := "res://../docs/art/concepts/yeoulmok/native-kit/"
const PLACEMENTS := {
	"barrel": [Vector2(83, 450), Vector2(60, 498)],
	"crate": [Vector2(243, 450), Vector2(258, 450)],
	"logs": [Vector2(65, 456)],
	"basket": [Vector2(259, 488)],
	"bench": [Vector2(218, 488)]
}
const DIRECTIONS := {"n": Vector2i.UP, "e": Vector2i.RIGHT, "s": Vector2i.DOWN, "w": Vector2i.LEFT}


static func install(art: Node2D) -> Dictionary:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "manifest.json"))
	if not manifest is Dictionary or not manifest.has_all(["buildings", "props"]):
		return {"error": "픽셀 키트 매니페스트 읽기 실패"}
	var image := Image.load_from_file(DIRECTORY + "environment.png")
	if image == null or image.is_empty():
		return {"error": "픽셀 키트 원본 읽기 실패"}
	var texture := ImageTexture.create_from_image(image)
	for name in ["House", "Workshop"]:
		var entry: Dictionary = manifest.buildings[name]
		var building = art.get_node(name)
		building.drawing_kind = "root"
		building.position = Vector2(entry.origin[0], entry.origin[1])
		building.queue_redraw()
		building.add_child(_sprite(texture, entry))
	var floor_art = art.get_node("Floor")
	floor_art.native_kit = true
	floor_art.queue_redraw()
	_install_environment(art, texture, manifest)
	for kind in PLACEMENTS:
		for position in PLACEMENTS[kind]:
			var prop := Node2D.new()
			prop.name = "Native_" + kind
			prop.set_meta("native_decoration", true)
			prop.position = position
			prop.add_child(_sprite(texture, manifest.props[kind]))
			art.add_child(prop)
	return manifest


static func _install_environment(art: Node2D, texture: Texture2D, manifest: Dictionary) -> void:
	var surface := Node2D.new()
	surface.name = "NativeSurface"
	surface.z_index = -1
	art.add_child(surface)
	var ground: TileMapLayer = art.get_parent().get_node("Ground")
	for y in range(23, 33):
		for x in range(3, 22):
			var cell := Vector2i(x, y)
			var atlas := ground.get_cell_atlas_coords(cell)
			if atlas.y != 0 or atlas.x not in [0, 1, 2, 3]:
				continue
			var kind := ("grass" if atlas.x < 2 else "dirt") + str(variant_for(cell))
			var sprite := _sprite(texture, manifest.tiles[kind])
			sprite.position = Vector2(cell * 16)
			surface.add_child(sprite)
	for y in range(12, 33):
		for x in range(1, 26):
			var cell := Vector2i(x, y)
			var atlas := ground.get_cell_atlas_coords(cell)
			if atlas == Vector2i(1, 1):
				_add_edges(surface, ground, texture, manifest, cell, "shore")
			elif atlas in [Vector2i(2, 0), Vector2i(3, 0)]:
				_add_edges(surface, ground, texture, manifest, cell, "road")
	for x in [48, 64, 80, 224, 240, 256]:
		var sprite := _sprite(texture, manifest.tiles.fence)
		sprite.position = Vector2(x, 520)
		surface.add_child(sprite)
	for position in [Vector2(16, 384), Vector2(16, 416), Vector2(288, 368)]:
		var sprite := _sprite(texture, manifest.tiles.shrub1)
		sprite.position = position
		surface.add_child(sprite)
	for position in [Vector2(112, 272), Vector2(192, 272)]:
		var sprite := _sprite(texture, manifest.tiles.reeds)
		sprite.position = position
		surface.add_child(sprite)


static func variant_for(cell: Vector2i) -> int:
	# 32비트 값을 두 번 혼합한다. 곱셈 중간값은 signed int64 범위 안이다.
	var value := ((cell.x * 73856093) ^ (cell.y * 19349663)) & 0xffffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff
	value = ((value ^ (value >> 16)) * 0x45d9f3b) & 0xffffffff
	return (value ^ (value >> 16)) & 1


static func _add_edges(
	surface: Node2D,
	ground: TileMapLayer,
	texture: Texture2D,
	manifest: Dictionary,
	cell: Vector2i,
	kind: String
) -> void:
	for direction in DIRECTIONS:
		var neighbor := ground.get_cell_atlas_coords(cell + DIRECTIONS[direction])
		if not _edge_neighbor(neighbor, kind):
			continue
		var sprite := _sprite(texture, manifest.tiles[kind + "_" + direction])
		sprite.position = Vector2(cell * 16)
		sprite.set_meta("edge_kind", kind)
		surface.add_child(sprite)
	# 직선 경계가 없는 두 변 사이에 대각 육지만 있을 때 안쪽 모서리를 메운다.
	for corner in ["ne", "se", "sw", "nw"]:
		var first: Vector2i = DIRECTIONS[corner[0]]
		var second: Vector2i = DIRECTIONS[corner[1]]
		if not _edge_neighbor(ground.get_cell_atlas_coords(cell + first + second), kind):
			continue
		if _edge_neighbor(ground.get_cell_atlas_coords(cell + first), kind):
			continue
		if _edge_neighbor(ground.get_cell_atlas_coords(cell + second), kind):
			continue
		var sprite := _sprite(texture, manifest.tiles[kind + "_" + corner])
		sprite.position = Vector2(cell * 16)
		sprite.set_meta("corner_kind", kind)
		sprite.set_meta("corner_direction", corner)
		surface.add_child(sprite)


static func _edge_neighbor(atlas: Vector2i, kind: String) -> bool:
	var grass := atlas in [Vector2i(0, 0), Vector2i(1, 0)]
	return grass or (kind == "shore" and atlas in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1)])


static func _sprite(texture: Texture2D, entry: Dictionary) -> Sprite2D:
	var region: Array = entry.region
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(region[0], region[1], region[2], region[3])
	var sprite := Sprite2D.new()
	sprite.name = "NativeSprite"
	sprite.texture = atlas
	sprite.centered = false
	sprite.position = -Vector2(entry.anchor[0], entry.anchor[1])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite
