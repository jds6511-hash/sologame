extends Node2D
## CB-1 디버그 전투장용 배경 격자.
## 실제 타일셋(MP-1)이 아닌 순수 참조용 그리드 — 이동/대시 거리 감각을 눈으로 확인하기 위함.

const TILE_PX := 16
const COLS := 40
const ROWS := 24


func _draw() -> void:
	for y in range(ROWS):
		for x in range(COLS):
			var color := Color(0.22, 0.22, 0.26) if (x + y) % 2 == 0 else Color(0.16, 0.16, 0.19)
			var rect := Rect2(Vector2(x * TILE_PX, y * TILE_PX), Vector2(TILE_PX, TILE_PX))
			draw_rect(rect, color, true)
