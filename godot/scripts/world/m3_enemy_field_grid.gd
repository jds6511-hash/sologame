## M3 신규 적 검증 필드의 배경 격자 (C-10).
##
## 정식 타일셋 지역이 아니라 **밴드별 구역을 나눈 검증 무대**라, 이동·사거리 감각을 눈으로
## 확인할 수 있는 체커 격자만 그린다(디버그 전투장 배경과 같은 목적). 정식 지역 씬
## (동부 가도·균열 외곽 등)이 만들어지면 이 필드는 폐기하고 배치 문서 규격대로 옮긴다.
extends Node2D

const TILE_PX := 16
const COLS := 52
const ROWS := 30
## 구역 경계선 색 — 6개 구역(3열 × 2행)의 구분선.
const ZONE_COLS := 16
const ZONE_ROWS := 15


func _draw() -> void:
	for y in range(ROWS):
		for x in range(COLS):
			var dark := (x + y) % 2 == 0
			var color := Color(0.20, 0.24, 0.20) if dark else Color(0.16, 0.19, 0.16)
			if x / ZONE_COLS != (x - 1) / ZONE_COLS or y / ZONE_ROWS != (y - 1) / ZONE_ROWS:
				color = color.lightened(0.12)
			draw_rect(
				Rect2(Vector2(x * TILE_PX, y * TILE_PX), Vector2(TILE_PX, TILE_PX)), color, true
			)
