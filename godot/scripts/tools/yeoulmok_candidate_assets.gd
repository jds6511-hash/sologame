## 생성 원본을 수정하지 않는 비교용 로더. 제품 씬에는 연결하지 않는다.
extends RefCounted

const SOURCE := "res://../docs/art/concepts/yeoulmok/buildings-source-v1.png"


static func inspect_source(path: String = SOURCE) -> Dictionary:
	var source := Image.load_from_file(path)
	if source == null or source.is_empty():
		return {"error": "원본 이미지 읽기 실패"}
	var occupied: Array[int] = []
	var colors := {}
	var partial_alpha := 0
	for x in range(source.get_width()):
		var has_pixel := false
		for y in range(source.get_height()):
			var color := source.get_pixel(x, y)
			if color.a > 0:
				colors[color.to_html(false)] = true
				has_pixel = true
				if color.a < 1:
					partial_alpha += 1
		if has_pixel:
			occupied.append(x)
	if occupied.size() < 2:
		return {"error": "불투명 영역 부족"}
	var gap := 0
	var split := -1
	for index in range(1, occupied.size()):
		var distance := occupied[index] - occupied[index - 1]
		if distance > gap:
			gap = distance
			split = (occupied[index] + occupied[index - 1]) / 2
	if gap < 8:
		return {"error": "건물 사이 투명 간격 없음"}
	var regions: Array[Rect2i] = []
	for section in [
		Rect2i(0, 0, split, source.get_height()),
		Rect2i(split, 0, source.get_width() - split, source.get_height())
	]:
		var used := source.get_region(section).get_used_rect()
		used.position += section.position
		regions.append(used)
	return {
		"image": source,
		"regions": regions,
		"width": source.get_width(),
		"height": source.get_height(),
		"visible_colors": colors.size(),
		"partial_alpha_pixels": partial_alpha,
		"transparent_gap": gap - 1,
		"source_sha256": FileAccess.get_sha256(path)
	}


static func install(art: Node2D, inspection: Dictionary, width: float) -> void:
	var texture := ImageTexture.create_from_image(inspection.image)
	# 두 건물은 같은 배율을 사용한다. 각자 같은 폭으로 맞추면 문/재료의 비례가 달라진다.
	var reference: Rect2i = inspection.regions[0]
	var factor := width / reference.size.x
	var index := 0
	for building_name in ["House", "Workshop"]:
		var building = art.get_node(building_name)
		building.drawing_kind = "root"
		building.queue_redraw()
		var old := building.get_node_or_null("CandidateSprite")
		if old != null:
			building.remove_child(old)
			old.free()
		var region: Rect2i = inspection.regions[index]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		var sprite := Sprite2D.new()
		sprite.name = "CandidateSprite"
		sprite.texture = atlas
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * factor
		sprite.position.y = -region.size.y * factor / 2
		building.add_child(sprite)
		index += 1
