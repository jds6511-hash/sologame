## M2 최종 통합 — 시작 지역 씬에 HUD(UI-1)·통합 메뉴(UI-2)·DropSystem(IT-2)을 배선한다.
##
## MonsterSpawner(MP-4)는 자신의 _ready()에서 몬스터를 스폰한다. Godot은 자식 노드의
## _ready()를 부모보다 먼저 호출하므로, 이 루트 스크립트의 _ready() 시점에는 뿔토끼처럼
## 동기 스폰되는 몬스터는 이미 존재한다 — 그 몬스터들은 get_children()으로 조회해
## DropSystem에 등록한다. 다만 들개 마수·균열 점액은 진입 스톨 완화를 위해 스폰이 이후
## 프레임으로 분산되므로(monster_spawner.gd), 그 몬스터들은 monster_spawned 시그널을
## 구독해 늦게라도 등록한다(_register_monster로 두 경로가 로직을 공유하며, 시점이 겹치지
## 않아 이중 등록되지 않는다).
##
## 골드는 world_item.gd 문서 그대로 "즉시 지급" 정책을 따른다 — DropSystem.gold_dropped를
## Player/Inventory(InventoryComponent).add_gold에 직접 연결한다. item_dropped는 실제
## 월드 아이템(WorldItem, F 상호작용) 스폰을 DropSystem이 이미 처리하므로 별도 연결이
## 필요 없다.
class_name EasternFrontierStartingArea
extends Node2D

const RABBIT_DROP_TABLE: DropTableData = preload("res://data/drops/rabbit_drop_table.tres")
const WOLF_DROP_TABLE: DropTableData = preload("res://data/drops/wolf_drop_table.tres")
const SLIME_DROP_TABLE: DropTableData = preload("res://data/drops/rift_slime_drop_table.tres")

## 주야간 CanvasModulate 색조 — `docs\art\STYLE_GUIDE.md` 5-1장 확정값 그대로(EDG32 팔레트
## 내 색상). CanvasModulate는 같은 캔버스의 Node2D 하위 트리에만 적용되고 Hud/IntegratedMenu/
## OnboardingHintBar(전부 CanvasLayer)는 별도 레이어라 영향받지 않는다.
const DAY_COLOR := Color("ffffff")
const NIGHT_COLOR := Color("6d7ab5")
## 전환 페이드 길이(현실 초). STYLE_GUIDE 5-1의 "게임 시간 1시간 분량 선형 보간"(황혼·새벽
## 중간색 경유)은 M2 범위 밖 — 이번에는 낮/밤 대표색 사이를 수 초간 직선 보간하는 단순
## 페이드만 구현한다(G2-4 요구 "전환 페이드(수 초)").
const DAY_NIGHT_FADE_SEC := 3.0

@onready var _player: PlayerController = $Player
@onready var _inventory: InventoryComponent = $Player/Inventory
@onready var _progression: PlayerProgression = $Player/PlayerProgression
@onready var _drop_system: DropSystem = $DropSystem
@onready var _monster_spawner: MonsterSpawner = $MonsterSpawner
@onready var _hud: Hud = $Hud
@onready var _onboarding_hint_bar: OnboardingHintBar = $OnboardingHintBar
@onready var _tutorial: TutorialController = $TutorialController
@onready var _day_night_modulate: CanvasModulate = $DayNightModulate


func _ready() -> void:
	_hud.bind_player(_player, _player.get_node("PlayerStats"))
	print("[통합] HUD 바인딩 완료")
	_drop_system.gold_dropped.connect(_inventory.add_gold)
	_monster_spawner.monster_spawned.connect(_on_monster_spawned)
	_register_spawned_monsters()
	_start_tutorial()
	_init_day_night_modulate()


# --- 주야간 시각 연출 (G2-4) ---


func _init_day_night_modulate() -> void:
	_day_night_modulate.color = DAY_COLOR if GameClock.is_day else NIGHT_COLOR
	GameClock.night_started.connect(_on_night_started)
	GameClock.day_started.connect(_on_day_started)


func _on_night_started(_day_number: int) -> void:
	print("[G2-4] 밤 시작 (%d일차) — 야간 몬스터 강화 x1.2·드랍률 x1.15 적용" % _day_number)
	_fade_day_night_modulate(NIGHT_COLOR)


func _on_day_started(_day_number: int) -> void:
	print("[G2-4] 낮 시작 (%d일차) — 야간 배율 해제" % _day_number)
	_fade_day_night_modulate(DAY_COLOR)


func _fade_day_night_modulate(target_color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(_day_night_modulate, "color", target_color, DAY_NIGHT_FADE_SEC)


## 온보딩 튜토리얼(UI-4) 배선 — MonsterSpawner가 이미 스폰해 둔 뿔토끼만 골라 넘긴다.
func _start_tutorial() -> void:
	var rabbits: Array[RabbitMonster] = []
	for monster in _monster_spawner.get_children():
		if monster is RabbitMonster:
			rabbits.append(monster)
	_tutorial.start(
		_player,
		_player.get_node("PlayerStats"),
		_inventory,
		_drop_system,
		_hud,
		_onboarding_hint_bar,
		rabbits
	)


## MonsterSpawner가 _ready() 시점까지 동기 스폰해 둔 몬스터(뿔토끼)를 종류별 드랍
## 테이블로 DropSystem에 등록한다. 들개 마수·균열 점액은 스폰이 이후 프레임으로 분산돼
## 이 시점에는 아직 자식으로 없을 수 있으므로 _on_monster_spawned(시그널)가 등록한다 —
## 시점이 겹치지 않아 이중 등록되지 않는다.
func _register_spawned_monsters() -> void:
	for monster in _monster_spawner.get_children():
		_register_monster(monster)


## MonsterSpawner.monster_spawned 시그널 핸들러 — 스폰이 프레임 분산된 이후에 추가되는
## 몬스터(들개 마수·균열 점액)를 놓치지 않고 DropSystem에 등록한다.
func _on_monster_spawned(monster: MonsterBase) -> void:
	_register_monster(monster)


func _register_monster(monster: Node) -> void:
	var drop_table := _drop_table_for(monster)
	if drop_table == null:
		return
	_drop_system.register_monster(monster, drop_table)
	## 처치 경험치 지급(B-1) — 드랍과 동일하게 몬스터 레벨·등급을 DropTableData에서 재사용한다.
	_progression.register_monster(monster, drop_table)
	print("[통합] 몬스터 등록: %s" % monster.name)


func _drop_table_for(monster: Node) -> DropTableData:
	if monster is RabbitMonster:
		return RABBIT_DROP_TABLE
	if monster is WolfMonster:
		return WOLF_DROP_TABLE
	if monster is RiftSlimeMonster:
		return SLIME_DROP_TABLE
	return null
