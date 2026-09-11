## HUD B요소 — 미니맵 (단순 구현).
##
## `docs\art\ux\ux-foundation.md` 5장 B행: "주변 지형+플레이어(중앙 화살표)+적(붉은 점)+
## NPC(노란 점)+퀘스트 목표(별). 클릭 불가(순수 표시)."
##
## M2 범위의 "단순 구현" — 지형 렌더링은 하지 않는다(맵 텍스처 파이프라인은 ux-foundation
## 8장 M2 이후 과제). 플레이어는 항상 중앙 고정 화살표(씬에 정적 배치)로 표시하고, 몬스터/
## NPC는 "monsters"/"npcs" 그룹에 속한 Node2D를 조회해 점으로 찍는다. 몬스터는
## MonsterBase에서 등록한다. NPC·퀘스트 목표 표시는 후속 구현 범위다.
class_name MinimapDisplay
extends Panel

const RADIUS_PX := 120.0  ## 240x240 패널의 절반 (2026-07-18 1920x1080 재기준)
const WORLD_TO_MINIMAP_SCALE := 0.08  ## 임의 축척(단순 구현) — 정식 축척은 M2 이후 확정
const ENEMY_GROUP := "monsters"
const NPC_GROUP := "npcs"
const DOT_SIZE := Vector2(4, 4)

var _player: Node2D = null

@onready var _dots_root: Control = $Dots


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.make_panel_stylebox())


func bind_player(player: Node2D) -> void:
	_player = player


func _process(_delta: float) -> void:
	if _player == null:
		return
	for child in _dots_root.get_children():
		child.queue_free()
	_draw_group_dots(get_tree().get_nodes_in_group(ENEMY_GROUP), UiStyle.COLOR_ENEMY_DOT)
	_draw_group_dots(get_tree().get_nodes_in_group(NPC_GROUP), UiStyle.COLOR_NPC_DOT)


func _draw_group_dots(nodes: Array, color: Color) -> void:
	var center := Vector2(RADIUS_PX, RADIUS_PX)
	for node in nodes:
		if not (node is Node2D):
			continue
		if node.is_queued_for_deletion() or (node is MonsterBase and node.is_dead()):
			continue
		var offset: Vector2 = (
			(node.global_position - _player.global_position) * WORLD_TO_MINIMAP_SCALE
		)
		if offset.length() > RADIUS_PX:
			continue
		var dot := ColorRect.new()
		dot.size = DOT_SIZE
		dot.color = color
		dot.position = center + offset - DOT_SIZE * 0.5
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots_root.add_child(dot)
