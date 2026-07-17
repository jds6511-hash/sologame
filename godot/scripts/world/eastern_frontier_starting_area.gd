## M2 최종 통합 — 시작 지역 씬에 HUD(UI-1)·통합 메뉴(UI-2)·DropSystem(IT-2)을 배선한다.
##
## MonsterSpawner(MP-4)는 자신의 _ready()에서 몬스터를 스폰한다. Godot은 자식 노드의
## _ready()를 부모보다 먼저 호출하므로, 이 루트 스크립트의 _ready() 시점에는 이미
## MonsterSpawner 아래에 몬스터가 모두 존재한다 — monster_spawner.gd를 건드리지 않고
## get_children()으로 조회해 DropSystem에 등록한다.
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

@onready var _player: PlayerController = $Player
@onready var _inventory: InventoryComponent = $Player/Inventory
@onready var _drop_system: DropSystem = $DropSystem
@onready var _monster_spawner: MonsterSpawner = $MonsterSpawner
@onready var _hud: Hud = $Hud


func _ready() -> void:
	_hud.bind_player(_player, _player.get_node("PlayerStats"))
	print("[통합] HUD 바인딩 완료")
	_drop_system.gold_dropped.connect(_inventory.add_gold)
	_register_spawned_monsters()


## MonsterSpawner가 스폰해 둔 몬스터들을 종류별 드랍 테이블로 DropSystem에 등록한다.
func _register_spawned_monsters() -> void:
	for monster in _monster_spawner.get_children():
		var drop_table := _drop_table_for(monster)
		if drop_table == null:
			continue
		_drop_system.register_monster(monster, drop_table)
		print("[통합] 몬스터 등록: %s" % monster.name)


func _drop_table_for(monster: Node) -> DropTableData:
	if monster is RabbitMonster:
		return RABBIT_DROP_TABLE
	if monster is WolfMonster:
		return WOLF_DROP_TABLE
	if monster is RiftSlimeMonster:
		return SLIME_DROP_TABLE
	return null
