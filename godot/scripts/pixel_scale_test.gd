extends Node2D
## MP-2 검증용 디버그 씬 스크립트.
## 목적: 320x180 월드 내부 해상도(Camera2D.zoom=4)와 1280x720 네이티브 UI가
## 의도대로 분리되어 있는지 육안/로그로 확인한다 (STYLE_GUIDE.md 1-1장).

const WORLD_TILE_PX := 16
const WORLD_WIDTH_TILES := 20
const WORLD_HEIGHT_TILES := 12


func _ready() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var camera := $Camera2D as Camera2D
	print("[MP-2 검증] 뷰포트(네이티브 UI 기준) 크기: %s" % viewport_size)
	print("[MP-2 검증] Camera2D.zoom: %s" % camera.zoom)
	print("[MP-2 검증] 월드 실효 가시 영역: %s" % (viewport_size / camera.zoom))


func _draw() -> void:
	# 16px 타일 체커보드 — Camera2D.zoom=4 적용 시 화면에서 64px 정사각형으로 보여야
	# 정수 스케일이 정확히 걸린 것이다.
	for y in range(WORLD_HEIGHT_TILES):
		for x in range(WORLD_WIDTH_TILES):
			var color := Color(0.25, 0.55, 0.3) if (x + y) % 2 == 0 else Color(0.15, 0.35, 0.2)
			var rect := Rect2(
				Vector2(x * WORLD_TILE_PX, y * WORLD_TILE_PX), Vector2(WORLD_TILE_PX, WORLD_TILE_PX)
			)
			draw_rect(rect, color, true)
