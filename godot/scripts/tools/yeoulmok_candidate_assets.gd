## 생성 원본을 수정하지 않는 비교용 로더. 제품 씬에는 연결하지 않는다.
extends RefCounted

const SOURCE := "res://../docs/art/concepts/yeoulmok/buildings-source-v2.png"
const BODY_ALPHA := 128.0 / 255.0
const MIN_BODY_PIXELS := 20
const MIN_BODY_COLUMNS := 8


static func inspect_source(path: String = SOURCE) -> Dictionary:
	var source := Image.load_from_file(path)
	if source == null or source.is_empty():
		return {"error": "원본 이미지 읽기 실패"}
	var colors := {}
	var partial_alpha := 0
	for x in range(source.get_width()):
		for y in range(source.get_height()):
			var color := source.get_pixel(x, y)
			if color.a > 0:
				colors[color.to_html(false)] = true
				if color.a < 1:
					partial_alpha += 1
	var bodies := body_regions(source)
	if bodies.size() != 2:
		return {"error": "몸체가 정확히 두 개로 분리되지 않음"}
	var split := int((bodies[0].end.x + bodies[1].position.x) / 2)
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
		"body_regions": bodies,
		"width": source.get_width(),
		"height": source.get_height(),
		"visible_colors": colors.size(),
		"partial_alpha_pixels": partial_alpha,
		"body_gap": bodies[1].position.x - bodies[0].end.x,
		"source_sha256": FileAccess.get_sha256(path)
	}


static func body_regions(source: Image) -> Array[Rect2i]:
	# 이 고해상도 후보 시트 전용 측정 규칙. 다른 크기 자산에 자동 적용하지 않는다.
	var runs: Array[Vector2i] = []
	var start := -1
	for x in range(source.get_width() + 1):
		var count := 0
		if x < source.get_width():
			for y in range(source.get_height()):
				if source.get_pixel(x, y).a >= BODY_ALPHA:
					count += 1
		if count >= MIN_BODY_PIXELS:
			if start == -1:
				start = x
		elif start != -1:
			if x - start >= MIN_BODY_COLUMNS:
				runs.append(Vector2i(start, x))
			start = -1
	var result: Array[Rect2i] = []
	if runs.size() != 2:
		return result
	for run in runs:
		var top := -1
		var bottom := -1
		for y in range(source.get_height()):
			var count := 0
			for x in range(run.x, run.y):
				if source.get_pixel(x, y).a >= BODY_ALPHA:
					count += 1
			if count >= MIN_BODY_PIXELS:
				if top == -1:
					top = y
				bottom = y + 1
		if top == -1:
			return []
		result.append(Rect2i(run.x, top, run.y - run.x, bottom - top))
	return result


static func install(art: Node2D, inspection: Dictionary, width: float) -> void:
	var texture := ImageTexture.create_from_image(inspection.image)
	# 두 건물은 같은 배율을 사용한다. 각자 같은 폭으로 맞추면 문/재료의 비례가 달라진다.
	var reference: Rect2i = inspection.body_regions[0]
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
		var body: Rect2i = inspection.body_regions[index]
		var anchor := Vector2(body.position.x + body.size.x / 2.0, body.end.y)
		sprite.position = (Vector2(region.position) + Vector2(region.size) / 2.0 - anchor) * factor
		building.add_child(sprite)
		index += 1
