## 몬스터 스폰 시스템 (MP-4 → C-10 확장) — world 씬의 스폰 마커(Marker2D) 위치에 몬스터를
## 스펙의 무리 구성 그대로 배치한다. M2 3종은 `m2-monster-spec.md` 6장 총괄표,
## M3 신규 7종은 `m3-monster-spec.md` 8-1장 총괄표·7장 아종 스펙을 따른다.
##
## 배치 규칙 (스폰 마커 그룹별, level-designer가 배치한 마커를 그대로 사용):
## - 뿔토끼: 마커 1개당 1마리 스폰(비어그로 공유 — m2 spec 3-1장).
## - 들개 마수: 마커 1개당 2~4마리를 마커 주변에 흩뿌려 스폰하고, 같은 마커에서 나온
##   개체들에 동일한 pack_id를 부여해 무리 어그로 공유(PackAggroCoordinator, CB-6)가
##   마커 단위로 작동하게 한다.
## - 균열 점액: 마커 1개당 1마리 스폰(솔로 — pack_id 없음).
## - **숲거미**: 마커 1개당 1마리(개별 급습 — m3 spec 4-1 "어그로 공유 없음", pack_id 개념 없음).
##   마커를 4~6타일 간격으로 묶어 배치하면 "느슨한 2~3마리 군집"이 성립한다(배치 문서 참조).
## - **그림자 숲거미**: **야간 전용**(m3 spec 7-1). GameClock 야간 전환 시 스폰하고 낮에
##   소멸시킨다. 야간 ×1.2 배율 자체는 `monster_base.gd`가 인스턴스별로 적용한다.
## - **무법자 2~3 / 노상강도 3~4 / 밀렵꾼 1~2 / 임프 2~4**: 마커 1개당 무리 스폰 + 동일
##   pack_id(어그로 공유 O, 공격 토큰 2). 그룹명 접두사는 각 몬스터 스크립트가 정한다
##   (`outlaw_pack_<id>` / `imp_pack_<id>`)므로 여기서는 pack_id 문자열만 부여한다.
## - **포효 임프장(정예)**: 마커 1개당 임프장 1마리 + 호위 일반 임프 2~3마리를 **같은 pack_id**로
##   스폰한다(m3 spec 7-4 "지휘관 셋업" — 포효 버프 대상 아군 동반).
##
## 스폰된 모든 몬스터의 target은 player_path로 지정된 플레이어 노드를 그대로 주입한다
## (monster_base.gd가 문서화한 "외부 주입" 결합 지점 — MP-4가 이 결합을 맡는다).
class_name MonsterSpawner
extends Node2D

## 몬스터 1마리가 씬 트리에 추가될 때마다(스폰 시점과 무관하게) 발생한다. 스폰이 여러
## 프레임에 걸쳐 분산되고 야간 전용 종은 밤이 될 때마다 새로 스폰되므로, 부모 노드가
## 스폰된 몬스터를 빠짐없이 받으려면 get_children() 일괄 조회 대신 이 시그널을 구독해야 한다.
signal monster_spawned(monster: MonsterBase)

const RABBIT_SCENE: PackedScene = preload("res://scenes/monsters/rabbit.tscn")
const WOLF_SCENE: PackedScene = preload("res://scenes/monsters/wolf.tscn")
const SLIME_SCENE: PackedScene = preload("res://scenes/monsters/rift_slime.tscn")
const FOREST_SPIDER_SCENE: PackedScene = preload("res://scenes/monsters/forest_spider.tscn")
const SHADOW_FOREST_SPIDER_SCENE: PackedScene = preload(
	"res://scenes/monsters/shadow_forest_spider.tscn"
)
const OUTLAW_SCENE: PackedScene = preload("res://scenes/monsters/outlaw.tscn")
const HIGHWAYMAN_SCENE: PackedScene = preload("res://scenes/monsters/highwayman.tscn")
const POACHER_SCENE: PackedScene = preload("res://scenes/monsters/poacher.tscn")
const IMP_SCENE: PackedScene = preload("res://scenes/monsters/imp.tscn")
const IMP_LORD_SCENE: PackedScene = preload("res://scenes/monsters/imp_lord.tscn")

## 무리 크기 범위 (x=최소, y=최대) — 각 spec 총괄표의 "무리 구성" 그대로.
const WOLF_PACK_SIZE := Vector2i(2, 4)  ## m2 spec 6장
const OUTLAW_PACK_SIZE := Vector2i(2, 3)  ## m3 spec 4-2
const HIGHWAYMAN_PACK_SIZE := Vector2i(3, 4)  ## m3 spec 7-2 (원본보다 1마리 많게)
const POACHER_PACK_SIZE := Vector2i(1, 2)  ## m3 spec 7-3 (매복형이라 소수)
const IMP_PACK_SIZE := Vector2i(2, 4)  ## m3 spec 4-3
const IMP_LORD_ESCORT_SIZE := Vector2i(2, 3)  ## m3 spec 7-4 (임프장 1 + 일반 임프 2~3)

## 같은 무리 개체를 마커 주변에 흩뿌리는 반경(타일) — 레벨 배치용 시각적 수치일 뿐,
## spec이 규정하는 전투 수치는 아니다. 무리원을 원 둘레에 균등 배치(각도 = 360°/무리
## 크기)한 뒤 각도만 소폭 흔들어, 무작위 사각형 오프셋이던 이전 방식에서 발생하던
## "개체 2마리가 완전히 겹쳐 보이는" 문제(디렉터 발견)를 제거한다 — 전 종의 무리 크기
## 상한이 4마리이므로 개체 간 최소 간격이 항상 1타일 이상이 되도록 반경을 계산했다
## (최악값: 4마리·90도 간격일 때 chord = 2*r*sin(45°) ≈ 1.41*r ≥ 1.4타일).
const PACK_SCATTER_RADIUS_TILES := 1.25
const PACK_ANGLE_JITTER_DEG := 20.0
const TILE_SIZE_PX := 16.0  ## STYLE_GUIDE.md 1장 — 월드 타일 크기

@export var player_path: NodePath

@export_group("M2 3종 스폰 마커 그룹")
@export var rabbit_spawn_root_path: NodePath
@export var wolf_pack_spawn_root_path: NodePath
@export var slime_spawn_root_path: NodePath

@export_group("M3 신규 7종 스폰 마커 그룹 (C-10)")
@export var forest_spider_spawn_root_path: NodePath
## 그림자 숲거미 — 야간에만 스폰되고 낮이 되면 소멸한다(m3 spec 7-1 야간 전용).
@export var shadow_forest_spider_night_spawn_root_path: NodePath
@export var outlaw_pack_spawn_root_path: NodePath
@export var highwayman_pack_spawn_root_path: NodePath
@export var poacher_spawn_root_path: NodePath
@export var imp_pack_spawn_root_path: NodePath
## 균열 포인트 — 마커당 포효 임프장(정예) 1마리 + 호위 일반 임프 2~3마리.
@export var imp_lord_camp_spawn_root_path: NodePath

var _rng := RandomNumberGenerator.new()
var _player: Node2D = null
var _night_only_monsters: Array[MonsterBase] = []


## 뿔토끼(마커당 1마리, 최대 3마리)는 온보딩 튜토리얼(eastern_frontier_starting_area.gd
## _start_tutorial)이 _ready() 직후 get_children()으로 즉시 필요로 하므로 동기 스폰을
## 유지한다. 몬스터 수가 많은 나머지 종은 마커(무리) 단위로 한 프레임씩 양보해, 시작 지역
## 진입 시 몬스터 9~13마리를 한 프레임에 동기 생성해 발생하던 스톨(tech-artist
## 프로파일링 — 진입 직후 ~1초간 FPS 1~4)을 완화한다.
func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null(player_path) as Node2D
	_spawn_rabbits()
	await _spawn_ring_packs(WOLF_SCENE, wolf_pack_spawn_root_path, WOLF_PACK_SIZE, "dogpack")
	await _spawn_solo_markers(SLIME_SCENE, slime_spawn_root_path)
	await _spawn_solo_markers(FOREST_SPIDER_SCENE, forest_spider_spawn_root_path)
	await _spawn_ring_packs(
		OUTLAW_SCENE, outlaw_pack_spawn_root_path, OUTLAW_PACK_SIZE, "outlawpack"
	)
	await _spawn_ring_packs(
		HIGHWAYMAN_SCENE, highwayman_pack_spawn_root_path, HIGHWAYMAN_PACK_SIZE, "highwaymanpack"
	)
	await _spawn_ring_packs(
		POACHER_SCENE, poacher_spawn_root_path, POACHER_PACK_SIZE, "poacherpack"
	)
	await _spawn_ring_packs(IMP_SCENE, imp_pack_spawn_root_path, IMP_PACK_SIZE, "imppack")
	await _spawn_imp_lord_camps()
	_init_night_only_spawns()


func _spawn_rabbits() -> void:
	for marker in _spawn_markers(rabbit_spawn_root_path):
		_spawn_monster(RABBIT_SCENE, marker.global_position)


## 마커당 1마리(솔로 또는 개별 급습). 마커 하나를 스폰할 때마다 한 프레임을 양보한다.
func _spawn_solo_markers(scene: PackedScene, root_path: NodePath) -> void:
	for marker in _spawn_markers(root_path):
		_spawn_monster(scene, marker.global_position)
		await get_tree().process_frame


## 마커당 무리 1개(동일 pack_id). 무리 하나를 다 스폰할 때마다 한 프레임을 양보한다.
func _spawn_ring_packs(
	scene: PackedScene, root_path: NodePath, size_range: Vector2i, pack_prefix: String
) -> void:
	for marker in _spawn_markers(root_path):
		var pack_id := "%s_%s" % [pack_prefix, marker.name]
		var pack_size := _rng.randi_range(size_range.x, size_range.y)
		_spawn_ring(scene, marker.global_position, pack_size, pack_id)
		await get_tree().process_frame


## 균열 포인트 — 임프장(정예)을 마커 중심에, 호위 일반 임프를 그 주변 원 둘레에 스폰하고
## 같은 pack_id로 묶는다(m3 spec 7-4 지휘관 셋업 — 포효 버프 대상 아군이 반드시 동반).
func _spawn_imp_lord_camps() -> void:
	for marker in _spawn_markers(imp_lord_camp_spawn_root_path):
		var pack_id := "implordcamp_%s" % marker.name
		_spawn_monster(IMP_LORD_SCENE, marker.global_position, pack_id)
		var escorts := _rng.randi_range(IMP_LORD_ESCORT_SIZE.x, IMP_LORD_ESCORT_SIZE.y)
		_spawn_ring(IMP_SCENE, marker.global_position, escorts, pack_id)
		await get_tree().process_frame


## 무리원을 중심 주변 원 둘레에 균등 배치(각도 = 360°/무리 크기)한 뒤 각도만 소폭 흔든다.
func _spawn_ring(scene: PackedScene, center: Vector2, count: int, pack_id: String) -> void:
	if count <= 0:
		return
	var base_angle := _rng.randf_range(0.0, TAU)
	for i in range(count):
		var jitter := deg_to_rad(_rng.randf_range(-PACK_ANGLE_JITTER_DEG, PACK_ANGLE_JITTER_DEG))
		var angle := base_angle + (TAU / count) * i + jitter
		var offset := Vector2.RIGHT.rotated(angle) * PACK_SCATTER_RADIUS_TILES * TILE_SIZE_PX
		_spawn_monster(scene, center + offset, pack_id)


# --- 야간 전용 스폰 (그림자 숲거미 — m3 spec 7-1) ---


func _init_night_only_spawns() -> void:
	GameClock.night_started.connect(_on_night_started)
	GameClock.day_started.connect(_on_day_started)
	if not GameClock.is_day:
		_spawn_night_only_monsters()


func _on_night_started(_day_number: int) -> void:
	_spawn_night_only_monsters()


func _on_day_started(_day_number: int) -> void:
	_despawn_night_only_monsters()


## 낮/밤 신호가 중복으로 와도 개체가 누적되지 않도록, 스폰 전에 항상 이전 야간 개체를 정리한다.
func _spawn_night_only_monsters() -> void:
	_despawn_night_only_monsters()
	for marker in _spawn_markers(shadow_forest_spider_night_spawn_root_path):
		var monster := _spawn_monster(SHADOW_FOREST_SPIDER_SCENE, marker.global_position)
		if monster:
			_night_only_monsters.append(monster)


## queue_free()는 died 시그널을 발신하지 않으므로 낮 소멸에 드랍·경험치가 붙지 않는다(의도).
func _despawn_night_only_monsters() -> void:
	for monster in _night_only_monsters:
		if is_instance_valid(monster):
			monster.queue_free()
	_night_only_monsters.clear()


# --- 공용 ---


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
## pack_id도 같은 이유로 add_child 전에 넣어야 한다 — 각 몬스터의 _ready()가 그 값으로
## 무리 어그로 그룹(add_to_group)에 등록하기 때문이다.
func _spawn_monster(
	scene: PackedScene, spawn_position: Vector2, pack_id: String = ""
) -> MonsterBase:
	var monster := scene.instantiate() as MonsterBase
	if monster == null:
		return null
	monster.global_position = spawn_position
	monster.target = _player
	if not pack_id.is_empty() and "pack_id" in monster:
		monster.set("pack_id", pack_id)
	add_child(monster)
	monster_spawned.emit(monster)
	return monster
