extends Control
## M 지도: 현 지역 지형·플레이어·현재 목표·후보 상인. 표시만 하며 순간이동하지 않는다.

const Navigation = preload("res://scripts/quests/quest_navigation.gd")
const Regions = preload("res://scripts/world/region_registry.gd")
var world: Node


func bind_world(value: Node) -> void:
	world = value
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and is_instance_valid(world):
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(world):
		return
	var font = load(UiStyle.FONT_BODY_PATH)
	var bounds: Rect2 = world.get_meta(
		"region_bounds", Regions.BOUNDS.get(world.map_id, Rect2(0, 0, 768, 576))
	)
	var scale_factor := minf((size.x - 100) / bounds.size.x, (size.y - 160) / bounds.size.y)
	if scale_factor <= 0:
		return
	var origin := Vector2(50, 90)
	draw_string(
		font,
		Vector2(50, 40),
		"현재 지역 지도 · 노랑: 목표 / 하늘색: 나 / 초록: 상점",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		26
	)
	var ground: TileMapLayer = world.get_node("Ground")
	for cell in ground.get_used_cells():
		var atlas := ground.get_cell_atlas_coords(cell)
		var color := Color("42664b")
		if atlas == Vector2i(1, 1):
			color = Color("2877a1")
		elif atlas in [Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(2, 2)]:
			color = Color("ae9875")
		elif atlas in [Vector2i(1, 2), Vector2i(2, 3)]:
			color = Color("666877")
		draw_rect(
			Rect2(
				origin + (Vector2(cell) * 16 - bounds.position) * scale_factor,
				Vector2.ONE * 16 * scale_factor
			),
			color
		)
	for target in Navigation.targets(world):
		var point: Vector2 = origin + (target.position - bounds.position) * scale_factor
		draw_circle(point, 9, UiStyle.COLOR_QUEST_DOT)
		draw_string(
			font,
			point + Vector2(12, -12),
			target.label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			22,
			Color.WHITE
		)
	var merchant := world.get_node_or_null("Merchant") as Node2D
	if merchant != null:
		var point := origin + (merchant.position - bounds.position) * scale_factor
		draw_circle(point, 8, Color("63c74d"))
		draw_string(font, point + Vector2(12, 24), "보급상 [F] 거래", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var player: Node2D = world.get_node("Player")
	draw_circle(origin + (player.position - bounds.position) * scale_factor, 6, Color.CYAN)
