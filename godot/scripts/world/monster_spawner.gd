## 몬스터 스폰 시스템 (MP-4) — world 씬의 스폰 마커(Marker2D) 위치에 몬스터 3종을
## m2-monster-spec.md 6장 총괄표의 무리 구성 그대로 배치한다.
##
## 배치 규칙 (스폰 마커 그룹별, level-designer가 MP-3에서 배치한 마커를 그대로 사용):
## - 뿔토끼: 마커 1개당 1마리 스폰(비어그로 공유 — spec 3-1장). MP-3가 배치한 마커 3개 =
##   3마리로 spec 6장 "무리 크기 1~3(비어그로 공유)" 범위를 만족한다.
## - 들개 마수: 마커 1개당 2~4마리를 마커 주변에 흩뿌려 스폰하고, 같은 마커에서 나온
##   개체들에 동일한 pack_id를 부여해 무리 어그로 공유(PackAggroCoordinator, CB-6)가
##   마커 단위로 작동하게 한다.
## - 균열 점액: 마커 1개당 1마리 스폰(솔로 — pack_id 없음).
##
## 스폰된 모든 몬스터의 target은 player_path로 지정된 플레이어 노드를 그대로 주입한다
## (monster_base.gd가 문서화한 "외부 주입" 결합 지점 — MP-4가 이 결합을 맡는다).
class_name MonsterSpawner
extends Node2D

const RABBIT_SCENE: PackedScene = preload("res://scenes/monsters/rabbit.tscn")
const WOLF_SCENE: PackedScene = preload("res://scenes/monsters/wolf.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/monsters/rift_slime.tscn")

## 들개 마수 무리 크기 범위 — m2-monster-spec.md 6장 총괄표 "무리 크기: 2~4(어그로 공유)".
const WOLF_PACK_SIZE_MIN := 2
const WOLF_PACK_SIZE_MAX := 4
## 같은 무리 개체를 마커 주변에 겹치지 않게 흩뿌리는 반경(타일) — 레벨 배치용 시각적
## 수치일 뿐, spec이 규정하는 전투 수치는 아니다.
const WOLF_PACK_SCATTER_RADIUS_TILES := 1.0
const TILE_SIZE_PX := 16.0  ## STYLE_GUIDE.md 1장 — 월드 타일 크기

@export var player_path: NodePath
@export var rabbit_spawn_root_path: NodePath
@export var wolf_pack_spawn_root_path: NodePath
@export var slime_spawn_root_path: NodePath

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var player := get_node_or_null(player_path) as Node2D
	_spawn_rabbits(player)
	_spawn_wolf_packs(player)
	_spawn_slimes(player)


func _spawn_rabbits(player: Node2D) -> void:
	for marker in _spawn_markers(rabbit_spawn_root_path):
		_spawn_monster(RABBIT_SCENE, marker.global_position, player)


## 들개 마수는 pack_id를 씬 트리 진입(_ready) 전에 지정해야 무리 어그로 그룹 등록
## (wolf_monster.gd _ready)이 올바르게 이뤄지므로, 공용 헬퍼(_spawn_monster) 대신
## 직접 인스턴스화한다.
func _spawn_wolf_packs(player: Node2D) -> void:
	for marker in _spawn_markers(wolf_pack_spawn_root_path):
		var pack_id := "dogpack_%s" % marker.name
		var pack_size := _rng.randi_range(WOLF_PACK_SIZE_MIN, WOLF_PACK_SIZE_MAX)
		for i in range(pack_size):
			var offset := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0))
			offset *= WOLF_PACK_SCATTER_RADIUS_TILES * TILE_SIZE_PX
			var wolf := WOLF_SCENE.instantiate() as WolfMonster
			wolf.pack_id = pack_id
			wolf.global_position = marker.global_position + offset
			wolf.target = player
			add_child(wolf)


func _spawn_slimes(player: Node2D) -> void:
	for marker in _spawn_markers(slime_spawn_root_path):
		_spawn_monster(SLIME_SCENE, marker.global_position, player)


func _spawn_markers(root_path: NodePath) -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	var root := get_node_or_null(root_path)
	if root == null:
		return markers
	for child in root.get_children():
		if child is Marker2D:
			markers.append(child)
	return markers


## global_position은 반드시 add_child보다 먼저 설정해야 한다 — MonsterBase._ready()가
## home_position을 그 시점의 global_position으로 캡처하기 때문(귀환/도주 판정의 기준점).
func _spawn_monster(scene: PackedScene, spawn_position: Vector2, player: Node2D) -> MonsterBase:
	var monster := scene.instantiate() as MonsterBase
	monster.global_position = spawn_position
	monster.target = player
	add_child(monster)
	return monster
