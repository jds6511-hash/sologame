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

## 몬스터 1마리가 씬 트리에 추가될 때마다(스폰 시점과 무관하게) 발생한다. 스폰이 여러
## 프레임에 걸쳐 분산되므로(_ready() 직후 일괄 완료를 보장하지 않음), 부모 노드가 스폰된
## 몬스터를 빠짐없이 받으려면 get_children() 일괄 조회 대신 이 시그널을 구독해야 한다.
signal monster_spawned(monster: MonsterBase)

const RABBIT_SCENE: PackedScene = preload("res://scenes/monsters/rabbit.tscn")
const WOLF_SCENE: PackedScene = preload("res://scenes/monsters/wolf.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/monsters/rift_slime.tscn")

## 들개 마수 무리 크기 범위 — m2-monster-spec.md 6장 총괄표 "무리 크기: 2~4(어그로 공유)".
const WOLF_PACK_SIZE_MIN := 2
const WOLF_PACK_SIZE_MAX := 4
## 같은 무리 개체를 마커 주변에 흩뿌리는 반경(타일) — 레벨 배치용 시각적 수치일 뿐,
## spec이 규정하는 전투 수치는 아니다. 무리원을 원 둘레에 균등 배치(각도 = 360°/무리
## 크기)한 뒤 각도만 소폭 흔들어, 무작위 사각형 오프셋이던 이전 방식에서 발생하던
## "개체 2마리가 완전히 겹쳐 보이는" 문제(디렉터 발견)를 제거한다 — 무리 크기 2~4 범위
## 전체에서 개체 간 최소 간격이 항상 1타일 이상이 되도록 반경을 계산했다(최악值: 4마리·
## 90도 간격일 때 현 위치가 최소이며 chord = 2*r*sin(45°) ≈ 1.41*r ≥ 1.4타일).
const WOLF_PACK_SCATTER_RADIUS_TILES := 1.25
const WOLF_PACK_ANGLE_JITTER_DEG := 20.0
const TILE_SIZE_PX := 16.0  ## STYLE_GUIDE.md 1장 — 월드 타일 크기

@export var player_path: NodePath
@export var rabbit_spawn_root_path: NodePath
@export var wolf_pack_spawn_root_path: NodePath
@export var slime_spawn_root_path: NodePath

var _rng := RandomNumberGenerator.new()


## 뿔토끼(마커당 1마리, 최대 3마리)는 온보딩 튜토리얼(eastern_frontier_starting_area.gd
## _start_tutorial)이 _ready() 직후 get_children()으로 즉시 필요로 하므로 동기 스폰을
## 유지한다. 몬스터 수가 많은 들개 마수·균열 점액은 마커(무리) 단위로 한 프레임씩 양보해,
## 시작 지역 진입 시 몬스터 9~13마리를 한 프레임에 동기 생성해 발생하던 스톨(tech-artist
## 프로파일링 — 진입 직후 ~1초간 FPS 1~4)을 완화한다.
func _ready() -> void:
	_rng.randomize()
	var player := get_node_or_null(player_path) as Node2D
	_spawn_rabbits(player)
	await _spawn_wolf_packs(player)
	await _spawn_slimes(player)


func _spawn_rabbits(player: Node2D) -> void:
	for marker in _spawn_markers(rabbit_spawn_root_path):
		_spawn_monster(RABBIT_SCENE, marker.global_position, player)


## 들개 마수는 pack_id를 씬 트리 진입(_ready) 전에 지정해야 무리 어그로 그룹 등록
## (wolf_monster.gd _ready)이 올바르게 이뤄지므로, 공용 헬퍼(_spawn_monster) 대신
## 직접 인스턴스화한다. 무리(마커) 하나를 다 스폰할 때마다 한 프레임을 양보한다.
func _spawn_wolf_packs(player: Node2D) -> void:
	for marker in _spawn_markers(wolf_pack_spawn_root_path):
		var pack_id := "dogpack_%s" % marker.name
		var pack_size := _rng.randi_range(WOLF_PACK_SIZE_MIN, WOLF_PACK_SIZE_MAX)
		var base_angle := _rng.randf_range(0.0, TAU)
		for i in range(pack_size):
			var angle := (
				base_angle
				+ (TAU / pack_size) * i
				+ deg_to_rad(
					_rng.randf_range(-WOLF_PACK_ANGLE_JITTER_DEG, WOLF_PACK_ANGLE_JITTER_DEG)
				)
			)
			var offset := (
				Vector2.RIGHT.rotated(angle) * WOLF_PACK_SCATTER_RADIUS_TILES * TILE_SIZE_PX
			)
			var wolf := WOLF_SCENE.instantiate() as WolfMonster
			wolf.pack_id = pack_id
			wolf.global_position = marker.global_position + offset
			wolf.target = player
			add_child(wolf)
			monster_spawned.emit(wolf)
		await get_tree().process_frame


func _spawn_slimes(player: Node2D) -> void:
	for marker in _spawn_markers(slime_spawn_root_path):
		_spawn_monster(SLIME_SCENE, marker.global_position, player)
		await get_tree().process_frame


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
	monster_spawned.emit(monster)
	return monster
