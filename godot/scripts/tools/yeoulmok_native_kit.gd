## 정수 픽셀 원본과 명시 앵커를 사용하는 격리된 여울목 비교 키트.
extends RefCounted

const DIRECTORY := "res://../docs/art/concepts/yeoulmok/native-kit/"
const PLACEMENTS := {
	"barrel": [Vector2(83, 450), Vector2(60, 498)],
	"crate": [Vector2(243, 450), Vector2(258, 450)],
	"logs": [Vector2(65, 456)],
	"basket": [Vector2(259, 488)],
	"bench": [Vector2(224, 488)]
}


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
			var kind := ("grass" if atlas.x < 2 else "dirt") + str((x + y) % 2)
			var sprite := _sprite(texture, manifest.tiles[kind])
			sprite.position = Vector2(cell * 16)
			surface.add_child(sprite)
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
