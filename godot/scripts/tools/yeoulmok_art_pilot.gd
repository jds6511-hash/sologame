## 여울목 한 화면 비교용 원본 픽셀 작화. 제품 씬에는 연결하지 않는다.
## 기존 경계/퀘스트 좌표 보존. 건물 충돌은 이 시제품 인스턴스에만 추가한다.
extends Node2D

const INK := Color("3e2731")
const WOOD := Color("b86f50")
const LIGHT := Color("e4a672")
const DARK := Color("733e39")
const GREEN := Color("3e8948")
const LEAF := Color("265c42")
const STONE := Color("8b9bb4")
const HOUSE := Rect2(48, 376, 48, 48)
const WORKSHOP := Rect2(224, 376, 48, 48)
const FOOTPRINTS := [Rect2(52, 400, 40, 24), Rect2(228, 404, 40, 20)]
const CROP_PATCHES := [Rect2(76, 468, 18, 48), Rect2(232, 468, 19, 48)]
var drawing_kind := "root"
var native_kit := false


func _ready() -> void:
	if drawing_kind != "root":
		return
	get_parent().get_node("Ground").z_index = -2
	y_sort_enabled = true
	var floor_art = get_script().new()
	floor_art.name = "Floor"
	floor_art.drawing_kind = "floor"
	floor_art.z_index = -1
	add_child(floor_art)
	for index in range(2):
		var building = get_script().new()
		building.name = "House" if index == 0 else "Workshop"
		building.drawing_kind = "house" if index == 0 else "workshop"
		var bounds: Rect2 = HOUSE if index == 0 else WORKSHOP
		building.position = Vector2(bounds.get_center().x, bounds.end.y)
		add_child(building)
	for footprint in FOOTPRINTS:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = footprint.size
		shape.shape = rectangle
		body.position = footprint.get_center()
		body.add_child(shape)
		add_child(body)
	queue_redraw()


func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _draw() -> void:
	if drawing_kind == "root":
		return
	if drawing_kind in ["house", "workshop"]:
		_house(Vector2(-24, -48), drawing_kind == "workshop")
		return
	# 광장 중앙은 비워 두고 조용한 흙에 판석 군집을 배치한다.
	_box(96, 400, 128, 112, WOOD)
	for p in [
		Vector2(143, 426),
		Vector2(158, 439),
		Vector2(146, 454),
		Vector2(160, 479),
		Vector2(144, 495),
		Vector2(187, 441),
		Vector2(213, 450)
	]:
		draw_rect(Rect2(p, Vector2(10, 5)), Color("c28569"))
		draw_rect(Rect2(p + Vector2(-2, 1), Vector2(13, 3)), Color("c28569"))
	for x in [48, 224]:
		_box(x, 384, 48, 136, WOOD)
		for y in range(476, 516, 14):
			_box(x + 5, y, 37, 1, Color("c28569"))
	# 도로 중앙과 접수원/플레이어 사이에는 소품을 놓지 않는다.
	_box(192, 432, 80, 32, WOOD)
	if not native_kit:
		for p in [Vector2(57, 442), Vector2(65, 446), Vector2(57, 451)]:
			_log(p)
		_barrel(Vector2(78, 436))
		_crate(Vector2(238, 438))
		_crate(Vector2(250, 438))
		_bench(Vector2(233, 459))
		_basket(Vector2(254, 480))
		_barrel(Vector2(55, 484))
	# 작은 재배 구역은 접수원 접근 동선의 바깥에 둔다.
	for patch in CROP_PATCHES:
		for y in range(int(patch.position.y) + 4, int(patch.end.y), 14):
			for x in [patch.position.x, patch.end.x - 7]:
				_box(x, y, 7, 2, DARK)
				_box(x + 2, y - 4, 2, 5, LEAF)
				_box(x, y - 4, 6, 2, GREEN)
	if not native_kit:
		for x in [51, 64, 77, 90, 228, 241, 254, 267]:
			_box(x, 522, 3, 9, DARK)
			_box(x, 522, 2, 8, LIGHT)
		for x in [51, 228]:
			_box(x, 526, 42, 2, WOOD)
		# 관목은 마을 외곽에만 두어 내부 실루엣을 가리지 않는다.
		for p in [Vector2(20, 370), Vector2(20, 408), Vector2(291, 371)]:
			_box(p.x, p.y + 4, 17, 8, LEAF)
			_box(p.x + 3, p.y, 11, 12, GREEN)
			_box(p.x + 5, p.y + 2, 6, 2, Color("63c74d"))


func _house(p: Vector2, workshop: bool) -> void:
	var x := p.x
	var y := p.y
	_box(x + 3, y + 25, 42, 23, INK)
	_box(x + 4, y + 26, 40, 20, LIGHT)
	for seam in [29, 35, 41]:
		_box(x + 5, y + seam, 38, 1, WOOD)
	_box(x + 4, y + 44, 40, 4, STONE)
	for beam in [5, 22, 41]:
		_box(x + beam, y + 26, 3, 18, DARK)
	_box(x + 17, y + 32, 13, 16, DARK)
	_box(x + 19, y + 33, 9, 14, WOOD)
	_box(x + 27, y + 40, 1, 1, LIGHT)
	_box(x + 8, y + 30, 9, 8, INK)
	_box(x + 9, y + 31, 7, 5, STONE)
	_box(x + 12, y + 31, 1, 6, DARK)
	if workshop:
		# 작업장은 낮은 맞배 대신 단층 차양과 노출된 기둥으로 구별한다.
		_box(x + 1, y + 17, 46, 12, INK)
		_box(x + 2, y + 18, 44, 9, DARK)
		for rib in range(3, 46, 6):
			_box(x + rib, y + 19, 2, 8, WOOD)
		_box(x, y + 28, 48, 3, LIGHT)
		_box(x + 2, y + 31, 2, 17, DARK)
		_box(x + 44, y + 31, 2, 17, DARK)
	else:
		draw_colored_polygon(
			PackedVector2Array([p + Vector2(0, 27), p + Vector2(24, 3), p + Vector2(48, 27)]), INK
		)
		draw_colored_polygon(
			PackedVector2Array([p + Vector2(3, 25), p + Vector2(24, 5), p + Vector2(45, 25)]), DARK
		)
		for row in range(11, 26, 5):
			var inset := 27 - row
			_box(x + inset, y + row, 48 - inset * 2, 2, WOOD)
			for shingle in range(inset + 4, 47 - inset, 8):
				_box(x + shingle, y + row - 2, 1, 2, WOOD)
		_box(x + 30, y + 16, 8, 4, LIGHT)
		_box(x + 35, y + 3, 5, 13, STONE)
		_box(x + 34, y + 2, 7, 3, DARK)
	_box(x + 15, y + 48, 18, 3, STONE)


func _barrel(p: Vector2) -> void:
	draw_rect(Rect2(p, Vector2(11, 14)), DARK)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(9, 12)), WOOD)
	for y in [3, 10]:
		draw_rect(Rect2(p + Vector2(0, y), Vector2(11, 2)), STONE)
	draw_rect(Rect2(p + Vector2(2, 1), Vector2(7, 2)), INK)


func _crate(p: Vector2) -> void:
	draw_rect(Rect2(p, Vector2(11, 11)), DARK)
	draw_rect(Rect2(p + Vector2.ONE, Vector2(9, 9)), WOOD)
	draw_line(p + Vector2(1, 1), p + Vector2(9, 9), LIGHT, 1)


func _log(p: Vector2) -> void:
	draw_rect(Rect2(p, Vector2(13, 4)), DARK)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(10, 2)), WOOD)
	draw_rect(Rect2(p + Vector2(11, 1), Vector2(2, 2)), LIGHT)


func _bench(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(1, 4), Vector2(2, 7)), DARK)
	draw_rect(Rect2(p + Vector2(18, 4), Vector2(2, 7)), DARK)
	draw_rect(Rect2(p, Vector2(22, 5)), WOOD)
	draw_rect(Rect2(p, Vector2(22, 1)), LIGHT)
	draw_rect(Rect2(p + Vector2(7, -2), Vector2(6, 3)), STONE)


func _basket(p: Vector2) -> void:
	draw_rect(Rect2(p, Vector2(10, 7)), DARK)
	draw_rect(Rect2(p + Vector2(1, 1), Vector2(8, 5)), WOOD)
	for x in [2, 5, 8]:
		draw_rect(Rect2(p + Vector2(x, 1), Vector2(1, 5)), LIGHT)
