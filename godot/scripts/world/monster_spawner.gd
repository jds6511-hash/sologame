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
##
## 재스폰 규칙 (D-3 — Phase D가 "재스폰이 없어 Lv10 도달 불가"로 지적한 G3-1 차단 요인 해소):
## **마커(무리) 단위 재스폰 = 전멸 쿨다운 + 플레이어 거리 게이트.**
## - 단위는 **개체가 아니라 마커**다. 마커의 모든 개체가 죽으면(= 무리 전멸) 쿨다운이 시작되고,
##   만료 시 그 마커의 무리를 규격대로 다시 스폰한다(무리 크기는 재추첨). 개체 단위로 1마리씩
##   리필하면 ① 임프장 균열 포인트가 "호위만 재생"·"임프장만 재생"으로 spec 7-4 지휘관 셋업을
##   깨고 ② 마커를 떠나지 않고 제자리에서 무한 사냥이 성립한다.
## - 쿨다운: 일반 마커 `NORMAL_RESPAWN_SEC`, 정예(임프장 균열 포인트) `ELITE_RESPAWN_SEC`.
##   정예의 긴 쿨다운은 EXP 효율 상 정예 캠핑이 일반 사냥보다 불리해지게 만드는 억제 장치다
##   (`docs\design\levels\m3-respawn-spec.md` 4장 실측).
## - 거리 게이트: 그 마커 서식종의 **인지 범위 + 1타일** 안에 플레이어가 있으면 재스폰을
##   미룬다. 눈앞에서 갑자기 나타나 즉시 어그로가 붙는 상황을 막기 위한 것이며, 쿨다운은 이미
##   만료 상태로 남으므로 플레이어가 벗어나는 즉시(다음 틱) 재스폰된다 — 취소가 아니라 지연이다.
## - 성능: M2에서 진입 시 동기 스폰 스톨(FPS 1~4)이 있었으므로, 재스폰도 `RESPAWN_TICK_SEC`
##   주기로만 판정하고 **한 틱에 마커 1개까지만** 스폰한다(`MAX_RESPAWNS_PER_TICK`).
##   여러 마커의 쿨다운이 동시에 만료돼도 초당 1마커로 자동 분산된다.
## - 야간 전용 종(그림자 숲거미)은 이 슬롯 체계에 **넣지 않는다** — GameClock 낮/밤 신호가
##   스폰·소멸을 전담하고, 낮 소멸은 `died`를 발신하지 않아 쿨다운 트리거와 무관하다.
## - 재스폰도 `_spawn_monster()`를 거치므로 `monster_spawned`가 발신되고, 월드 루트가 그 시그널로
##   `DropSystem`·`PlayerProgression`에 재등록한다(드랍·처치 EXP 유지).
class_name MonsterSpawner
extends Node2D

## 몬스터 1마리가 씬 트리에 추가될 때마다(스폰 시점과 무관하게) 발생한다. 스폰이 여러
## 프레임에 걸쳐 분산되고 야간 전용 종은 밤이 될 때마다 새로 스폰되므로, 부모 노드가
## 스폰된 몬스터를 빠짐없이 받으려면 get_children() 일괄 조회 대신 이 시그널을 구독해야 한다.
signal monster_spawned(monster: MonsterBase)

## 마커 종류별 스폰·재스폰 방식.
enum SpawnKind { SOLO, RING_PACK, IMP_LORD_CAMP }

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

## 재스폰 파라미터 — 근거는 `docs\design\levels\m3-respawn-spec.md` 2·3·4장.
const RESPAWN_TICK_SEC := 1.0  ## 판정 주기. 쿨다운이 30초 단위라 1초 해상도로 충분하다.
const NORMAL_RESPAWN_SEC := 30.0  ## 일반 마커 — 배치 밀도상 공급이 플레이어 사냥 속도를 넘는다
const ELITE_RESPAWN_SEC := 180.0  ## 정예 캠프 — 정예 캠핑 효율을 일반 사냥 아래로 떨어뜨린다
const RESPAWN_GATE_MARGIN_TILES := 1.0  ## 거리 게이트 = 서식종 인지 범위 + 이 여유
const MAX_RESPAWNS_PER_TICK := 1  ## 한 틱에 스폰할 마커 수 상한 (스폰 스톨 방지)

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
var _respawn_slots: Array = []
var _respawn_tick_accum := 0.0


## 마커 1개 = 재스폰 슬롯 1개. 슬롯은 자기 마커에서 스폰할 무리 규격과 현재 생존 개체를 들고
## 있고, 생존 개체가 0이 되면 쿨다운을 걸었다가 만료 시 같은 규격으로 다시 스폰한다.
class RespawnSlot:
	extends RefCounted

	var kind: int = MonsterSpawner.SpawnKind.SOLO
	var scene: PackedScene = null
	var spawn_position := Vector2.ZERO
	var marker_name := ""
	var pack_size_range := Vector2i.ONE
	var pack_prefix := ""
	var delay_sec := MonsterSpawner.NORMAL_RESPAWN_SEC
	## 재스폰 최소 거리(타일) = 이 마커에 스폰된 종의 인지 범위 최대값 + 여유. 첫 스폰 때 정해진다.
	var gate_tiles := 0.0
	var alive: Array[MonsterBase] = []
	var awaiting_respawn := false
	var remaining_sec := 0.0


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
		_populate_slot(_add_slot(SpawnKind.SOLO, RABBIT_SCENE, marker))


## 마커당 1마리(솔로 또는 개별 급습). 마커 하나를 스폰할 때마다 한 프레임을 양보한다.
func _spawn_solo_markers(scene: PackedScene, root_path: NodePath) -> void:
	for marker in _spawn_markers(root_path):
		_populate_slot(_add_slot(SpawnKind.SOLO, scene, marker))
		await get_tree().process_frame


## 마커당 무리 1개(동일 pack_id). 무리 하나를 다 스폰할 때마다 한 프레임을 양보한다.
func _spawn_ring_packs(
	scene: PackedScene, root_path: NodePath, size_range: Vector2i, pack_prefix: String
) -> void:
	for marker in _spawn_markers(root_path):
		var slot := _add_slot(SpawnKind.RING_PACK, scene, marker)
		slot.pack_size_range = size_range
		slot.pack_prefix = pack_prefix
		_populate_slot(slot)
		await get_tree().process_frame


## 균열 포인트 — 임프장(정예)을 마커 중심에, 호위 일반 임프를 그 주변 원 둘레에 스폰하고
## 같은 pack_id로 묶는다(m3 spec 7-4 지휘관 셋업 — 포효 버프 대상 아군이 반드시 동반).
## 재스폰도 캠프 단위이므로 임프장 없이 호위만 남거나 그 반대가 되는 상태는 생기지 않는다.
func _spawn_imp_lord_camps() -> void:
	for marker in _spawn_markers(imp_lord_camp_spawn_root_path):
		var slot := _add_slot(SpawnKind.IMP_LORD_CAMP, IMP_LORD_SCENE, marker)
		slot.delay_sec = ELITE_RESPAWN_SEC
		_populate_slot(slot)
		await get_tree().process_frame


## 무리원을 중심 주변 원 둘레에 균등 배치(각도 = 360°/무리 크기)한 뒤 각도만 소폭 흔든다.
func _spawn_ring(
	scene: PackedScene, center: Vector2, count: int, pack_id: String
) -> Array[MonsterBase]:
	var spawned: Array[MonsterBase] = []
	if count <= 0:
		return spawned
	var base_angle := _rng.randf_range(0.0, TAU)
	for i in range(count):
		var jitter := deg_to_rad(_rng.randf_range(-PACK_ANGLE_JITTER_DEG, PACK_ANGLE_JITTER_DEG))
		var angle := base_angle + (TAU / count) * i + jitter
		var offset := Vector2.RIGHT.rotated(angle) * PACK_SCATTER_RADIUS_TILES * TILE_SIZE_PX
		var monster := _spawn_monster(scene, center + offset, pack_id)
		if monster != null:
			spawned.append(monster)
	return spawned


# --- 재스폰 (D-3 — 헤더 "재스폰 규칙" 참고) ---


func _add_slot(kind: SpawnKind, scene: PackedScene, marker: Marker2D) -> RespawnSlot:
	var slot := RespawnSlot.new()
	slot.kind = kind
	slot.scene = scene
	slot.spawn_position = marker.global_position
	slot.marker_name = marker.name
	_respawn_slots.append(slot)
	return slot


## 슬롯의 무리를 규격대로 스폰한다(첫 스폰·재스폰 공용). 무리 크기·산개 각도·pack_id는
## 매번 새로 만들어지므로 재스폰할 때마다 구성이 조금씩 달라진다.
func _populate_slot(slot: RespawnSlot) -> void:
	var spawned: Array[MonsterBase] = []
	match slot.kind:
		SpawnKind.SOLO:
			var solo := _spawn_monster(slot.scene, slot.spawn_position)
			if solo != null:
				spawned.append(solo)
		SpawnKind.RING_PACK:
			var pack_size := _rng.randi_range(slot.pack_size_range.x, slot.pack_size_range.y)
			spawned = _spawn_ring(
				slot.scene,
				slot.spawn_position,
				pack_size,
				"%s_%s" % [slot.pack_prefix, slot.marker_name]
			)
		SpawnKind.IMP_LORD_CAMP:
			var camp_id := "implordcamp_%s" % slot.marker_name
			var lord := _spawn_monster(IMP_LORD_SCENE, slot.spawn_position, camp_id)
			if lord != null:
				spawned.append(lord)
			var escorts := _rng.randi_range(IMP_LORD_ESCORT_SIZE.x, IMP_LORD_ESCORT_SIZE.y)
			spawned.append_array(_spawn_ring(IMP_SCENE, slot.spawn_position, escorts, camp_id))
	slot.alive = spawned
	slot.awaiting_respawn = false
	slot.remaining_sec = 0.0
	for monster in spawned:
		monster.died.connect(_on_slot_monster_died.bind(slot, monster))
		if monster.stats != null:
			slot.gate_tiles = maxf(
				slot.gate_tiles, monster.stats.perception_range_tiles + RESPAWN_GATE_MARGIN_TILES
			)
	if spawned.is_empty():
		_arm_slot(slot)


## 무리 전멸 시점에만 쿨다운을 건다 — 개체가 1마리라도 남아 있으면 재스폰하지 않는다.
func _on_slot_monster_died(slot: RespawnSlot, monster: MonsterBase) -> void:
	slot.alive.erase(monster)
	if slot.alive.is_empty():
		_arm_slot(slot)


func _arm_slot(slot: RespawnSlot) -> void:
	if slot.awaiting_respawn:
		return
	slot.awaiting_respawn = true
	slot.remaining_sec = slot.delay_sec


## died를 거치지 않고 사라진 개체(씬 해제 등)를 생존 목록에서 제거한다.
func _prune_slot(slot: RespawnSlot) -> void:
	var index := slot.alive.size() - 1
	while index >= 0:
		if not is_instance_valid(slot.alive[index]):
			slot.alive.remove_at(index)
		index -= 1
	if slot.alive.is_empty():
		_arm_slot(slot)


## 플레이어가 서식종 인지 범위 + 여유 안에 있으면 false — 재스폰을 다음 틱으로 미룬다.
## 쿨다운은 이미 만료 상태로 남으므로 벗어나는 즉시 재스폰된다(취소가 아니라 지연).
func _respawn_gate_clear(slot: RespawnSlot) -> bool:
	if slot.gate_tiles <= 0.0 or not is_instance_valid(_player):
		return true
	var gap_tiles := _player.global_position.distance_to(slot.spawn_position) / TILE_SIZE_PX
	return gap_tiles > slot.gate_tiles


func _process(delta: float) -> void:
	if _respawn_slots.is_empty():
		return
	_respawn_tick_accum += delta
	if _respawn_tick_accum < RESPAWN_TICK_SEC:
		return
	_respawn_tick_accum = 0.0
	advance_respawn_tick(RESPAWN_TICK_SEC)


## 재스폰 판정 1회. `_process`가 RESPAWN_TICK_SEC 주기로 호출하며, 테스트는 실시간을 기다리지
## 않고 이 함수를 직접 호출해 시간 경과를 주입한다.
## 한 호출에서 스폰하는 마커는 MAX_RESPAWNS_PER_TICK개까지다 — 쿨다운이 동시에 만료돼도
## 스폰이 초당 1마커로 분산돼 M2의 진입 스톨 같은 프레임 낙하가 생기지 않는다.
func advance_respawn_tick(elapsed_sec: float) -> void:
	var spawned_markers := 0
	for entry in _respawn_slots:
		var slot: RespawnSlot = entry
		_prune_slot(slot)
		if not slot.awaiting_respawn:
			continue
		slot.remaining_sec -= elapsed_sec
		if slot.remaining_sec > 0.0:
			continue
		if spawned_markers >= MAX_RESPAWNS_PER_TICK or not _respawn_gate_clear(slot):
			continue
		_populate_slot(slot)
		spawned_markers += 1


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
