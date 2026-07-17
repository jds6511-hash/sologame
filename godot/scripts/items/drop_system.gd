## 몬스터 드랍 판정 시스템 (IT-2) — economy-foundation.md 1-1장(골드 공식)·2-5장(드랍률
## 표)을 그대로 구현한다.
##
## monster_base.gd·scenes/monsters/*(다른 에이전트가 병렬 수정 중)는 손대지 않고,
## MonsterBase.died 시그널을 구독하는 독립 노드로 구현했다 — register_monster()로
## 몬스터 인스턴스와 드랍 테이블을 등록하면 내부에서 시그널을 연결한다.
##
## 씬 배선 방법(결과 보고에도 동일하게 기록):
##   1. 레벨/월드 씬에 이 스크립트를 붙인 Node("DropSystem")를 하나 두고
##      rate_config(DropRateConfig)·world_item_scene(WorldItem.tscn)을 할당한다.
##   2. 몬스터 스폰 지점(레벨 씬 또는 스포너 스크립트)에서 몬스터 인스턴스 생성 직후
##      `drop_system.register_monster(monster, rabbit_drop_table)`처럼 종별 DropTableData를
##      골라 등록한다(뿔토끼=data/drops/rabbit_drop_table.tres 등).
##   3. 골드는 world 오브젝트를 만들지 않고 즉시 지급한다는 가정으로 gold_dropped 시그널만
##      내보낸다 — 플레이어 쪽에서 `drop_system.gold_dropped.connect(inventory.add_gold)`로
##      연결하면 된다(인벤토리 쪽 add_gold(amount:int)는 IT-3 InventoryComponent 참고).
##
## 테스트 용이성을 위해 확률 판정·슬롯 롤·아이템 티어 해석은 전부 정적 순수 함수로 뺐다
## (DamageCalculator의 rng 주입 관행과 동일한 방향 — combat.md 6장 CB-3 스타일 참고).
class_name DropSystem
extends Node

signal gold_dropped(amount: int, world_position: Vector2)
signal item_dropped(item: ItemData, quantity: int, world_position: Vector2)

@export var rate_config: DropRateConfig
@export var world_item_scene: PackedScene  ## scenes/items/world_item.tscn

var _item_cache: Array[ItemData] = []


func _ready() -> void:
	_item_cache = _load_all_items()


## 몬스터 스폰 시 호출 — died 시그널을 이 시스템의 판정 함수에 연결한다.
func register_monster(monster: MonsterBase, drop_table: DropTableData) -> void:
	monster.died.connect(_on_monster_died.bind(monster, drop_table))


func _on_monster_died(monster: MonsterBase, drop_table: DropTableData) -> void:
	var pos: Vector2 = monster.global_position
	var hit_grade: String = monster.last_hit_grade
	_drop_gold(drop_table, pos)
	_drop_material(drop_table, hit_grade, pos)
	_drop_potion(drop_table, pos)
	_drop_equipment(drop_table, pos)


# --- 골드 (economy-foundation.md 1-1장) ---


## g(L) = round(2 x L^1.5), 정예 x6 / 보스 x40(반복 처치 x0.5).
static func calc_gold(
	level: int,
	tier: DropTableData.MonsterTier,
	rate_config: DropRateConfig,
	is_repeat_boss: bool = false
) -> int:
	var base := roundi(2.0 * pow(float(level), 1.5))
	match tier:
		DropTableData.MonsterTier.ELITE:
			base = roundi(base * rate_config.gold_multiplier_elite)
		DropTableData.MonsterTier.BOSS:
			base = roundi(base * rate_config.gold_multiplier_boss)
			if is_repeat_boss:
				base = roundi(base * rate_config.gold_multiplier_boss_repeat)
	return base


func _drop_gold(drop_table: DropTableData, pos: Vector2) -> void:
	var amount := calc_gold(drop_table.monster_level, drop_table.tier, rate_config)
	gold_dropped.emit(amount, pos)


# --- 판정 확률 조회 (등급 공통 정책, 2-5장 표) ---


static func material_chance(rate_config: DropRateConfig, tier: DropTableData.MonsterTier) -> float:
	match tier:
		DropTableData.MonsterTier.ELITE:
			return rate_config.material_chance_elite
		DropTableData.MonsterTier.BOSS:
			return rate_config.material_chance_boss
		_:
			return rate_config.material_chance_normal


static func material_count(rate_config: DropRateConfig, tier: DropTableData.MonsterTier) -> int:
	match tier:
		DropTableData.MonsterTier.ELITE:
			return rate_config.material_count_elite
		DropTableData.MonsterTier.BOSS:
			return rate_config.material_count_boss
		_:
			return rate_config.material_count_normal


static func potion_chance(rate_config: DropRateConfig, tier: DropTableData.MonsterTier) -> float:
	match tier:
		DropTableData.MonsterTier.ELITE:
			return rate_config.potion_chance_elite
		DropTableData.MonsterTier.BOSS:
			return rate_config.potion_chance_boss
		_:
			return rate_config.potion_chance_normal


static func potion_count(rate_config: DropRateConfig, tier: DropTableData.MonsterTier) -> int:
	match tier:
		DropTableData.MonsterTier.ELITE:
			return rate_config.potion_count_elite
		DropTableData.MonsterTier.BOSS:
			return rate_config.potion_count_boss
		_:
			return rate_config.potion_count_normal


static func equip_chance(
	rate_config: DropRateConfig, tier: DropTableData.MonsterTier, grade: ItemData.ItemGrade
) -> float:
	## 보스는 "확정 1개를 B/A/S로 배분"하는 별도 규칙(equip_boss_chance_*)을 쓰므로
	## 여기서는 0을 돌려준다 — 호출자가 tier==BOSS면 이 함수 대신 roll_boss_equipment_grade를
	## 쓴다(_drop_equipment 참고).
	if tier == DropTableData.MonsterTier.BOSS:
		return 0.0
	var is_elite := tier == DropTableData.MonsterTier.ELITE
	match grade:
		ItemData.ItemGrade.C:
			return (
				rate_config.equip_c_chance_elite if is_elite else rate_config.equip_c_chance_normal
			)
		ItemData.ItemGrade.B:
			return (
				rate_config.equip_b_chance_elite if is_elite else rate_config.equip_b_chance_normal
			)
		ItemData.ItemGrade.A:
			return (
				rate_config.equip_a_chance_elite if is_elite else rate_config.equip_a_chance_normal
			)
		ItemData.ItemGrade.S:
			return (
				rate_config.equip_s_chance_elite if is_elite else rate_config.equip_s_chance_normal
			)
		_:
			return 0.0


# --- 판정 성립 여부 (순수 함수 — roll_01/roll_weight는 외부 주입, 결정적 테스트 가능) ---


## night_multiplier: G2-4 야간 아이템 드랍률 배율(combat.md 2-3장 ×1.15, 골드 제외·보스
## 제외 — 호출자가 tier==BOSS면 항상 1.0을 넘겨야 한다). 기본값 1.0이라 기존 호출부(주간
## 판정·순수 함수 테스트)는 수정 없이 그대로 동작한다.
static func should_drop_material(
	rate_config: DropRateConfig,
	tier: DropTableData.MonsterTier,
	core_break_guarantee: bool,
	hit_grade: String,
	roll_01: float,
	night_multiplier: float = 1.0
) -> bool:
	if core_break_guarantee and hit_grade == "강":
		return true
	return roll_01 < minf(material_chance(rate_config, tier) * night_multiplier, 1.0)


static func should_drop_potion(
	rate_config: DropRateConfig,
	tier: DropTableData.MonsterTier,
	roll_01: float,
	night_multiplier: float = 1.0
) -> bool:
	return roll_01 < minf(potion_chance(rate_config, tier) * night_multiplier, 1.0)


static func should_drop_equipment_grade(
	rate_config: DropRateConfig,
	tier: DropTableData.MonsterTier,
	grade: ItemData.ItemGrade,
	roll_01: float,
	night_multiplier: float = 1.0
) -> bool:
	return roll_01 < minf(equip_chance(rate_config, tier, grade) * night_multiplier, 1.0)


## 보스 확정 드랍 1개의 등급을 B/A/S 중에서 배분한다 (2-5장: 70/25/5%). roll_01은 [0,1).
static func roll_boss_equipment_grade(
	rate_config: DropRateConfig, roll_01: float
) -> ItemData.ItemGrade:
	if roll_01 < rate_config.equip_boss_chance_b:
		return ItemData.ItemGrade.B
	if roll_01 < rate_config.equip_boss_chance_b + rate_config.equip_boss_chance_a:
		return ItemData.ItemGrade.A
	return ItemData.ItemGrade.S


## 슬롯 가중치 총합 (weight_roll의 상한 계산용).
static func total_slot_weight(rate_config: DropRateConfig) -> float:
	return (
		rate_config.slot_weight_weapon
		+ rate_config.slot_weight_armor_body
		+ rate_config.slot_weight_armor_leg
		+ rate_config.slot_weight_armor_head
		+ rate_config.slot_weight_armor_foot
		+ rate_config.slot_weight_ring
		+ rate_config.slot_weight_necklace
	)


## 드랍 장비의 슬롯을 가중 무작위로 고른다. weight_roll은 [0, total_slot_weight) 범위값.
static func roll_equipment_slot(
	rate_config: DropRateConfig, weight_roll: float
) -> ItemData.EquipSlot:
	var acc := 0.0
	acc += rate_config.slot_weight_weapon
	if weight_roll < acc:
		return ItemData.EquipSlot.WEAPON
	acc += rate_config.slot_weight_armor_body
	if weight_roll < acc:
		return ItemData.EquipSlot.ARMOR_BODY
	acc += rate_config.slot_weight_armor_leg
	if weight_roll < acc:
		return ItemData.EquipSlot.ARMOR_LEG
	acc += rate_config.slot_weight_armor_head
	if weight_roll < acc:
		return ItemData.EquipSlot.ARMOR_HEAD
	acc += rate_config.slot_weight_armor_foot
	if weight_roll < acc:
		return ItemData.EquipSlot.ARMOR_FOOT
	acc += rate_config.slot_weight_ring
	if weight_roll < acc:
		return ItemData.EquipSlot.RING
	return ItemData.EquipSlot.NECKLACE


## 몬스터 레벨 이하 최고 티어(economy-foundation.md 2-1장 "자기 레벨 이하의 최고 티어")·
## 등급·슬롯이 일치하는 아이템을 items에서 찾는다. 무기는 스마트 드랍 규칙(jobs.md 5-2장)에
## 따라 weapon_series_prefix로 시작하는 계열만 후보로 삼는다. 후보가 없으면 null —
## 이 경우 "드랍 판정은 통과했지만 실제 데이터가 없어 드랍되지 않음"을 뜻한다(기획/데이터
## 공백 가능성. 결과 보고 참고).
static func resolve_equipment_item(
	items: Array[ItemData],
	monster_level: int,
	grade: ItemData.ItemGrade,
	slot: ItemData.EquipSlot,
	weapon_series_prefix: String
) -> ItemData:
	var candidates: Array[ItemData] = []
	for it in items:
		if it.equip_slot != slot or it.grade != grade or it.level_limit > monster_level:
			continue
		if slot == ItemData.EquipSlot.WEAPON and not it.item_id.begins_with(weapon_series_prefix):
			continue
		candidates.append(it)
	if candidates.is_empty():
		return null
	var max_level := candidates[0].level_limit
	for it in candidates:
		max_level = maxi(max_level, it.level_limit)
	var final_pool: Array[ItemData] = []
	for it in candidates:
		if it.level_limit == max_level:
			final_pool.append(it)
	return final_pool[randi() % final_pool.size()]


# --- 실제 판정 (인스턴스 — 랜덤 굴림 + 스폰) ---


func _drop_material(drop_table: DropTableData, hit_grade: String, pos: Vector2) -> void:
	if drop_table.material_item_id == "":
		return
	var dropped := should_drop_material(
		rate_config,
		drop_table.tier,
		drop_table.core_break_guarantees_material,
		hit_grade,
		randf(),
		_night_drop_multiplier(drop_table.tier)
	)
	if not dropped:
		return
	var item := _find_item(drop_table.material_item_id)
	if item:
		_spawn_item(item, material_count(rate_config, drop_table.tier), pos)


func _drop_potion(drop_table: DropTableData, pos: Vector2) -> void:
	if drop_table.potion_item_id == "":
		return
	if not should_drop_potion(
		rate_config, drop_table.tier, randf(), _night_drop_multiplier(drop_table.tier)
	):
		return
	var item := _find_item(drop_table.potion_item_id)
	if item:
		_spawn_item(item, potion_count(rate_config, drop_table.tier), pos)


func _drop_equipment(drop_table: DropTableData, pos: Vector2) -> void:
	if drop_table.tier == DropTableData.MonsterTier.BOSS:
		var grade := roll_boss_equipment_grade(rate_config, randf())
		_drop_equipment_of_grade(drop_table.monster_level, grade, pos)
		return
	var night_multiplier := _night_drop_multiplier(drop_table.tier)
	for grade in [
		ItemData.ItemGrade.C, ItemData.ItemGrade.B, ItemData.ItemGrade.A, ItemData.ItemGrade.S
	]:
		if should_drop_equipment_grade(
			rate_config, drop_table.tier, grade, randf(), night_multiplier
		):
			_drop_equipment_of_grade(drop_table.monster_level, grade, pos)


## G2-4 야간 드랍률 배율 조회 — 골드는 이 함수를 거치지 않으므로(_drop_gold) ×1.0이
## 그대로 유지된다(combat.md 2-3장 "골드 드랍량 ×1.0"). 보스는 GameClock에 boss=true로
## 물어봐 항상 1.0을 받는다(보스 제외).
func _night_drop_multiplier(tier: DropTableData.MonsterTier) -> float:
	return GameClock.get_item_drop_rate_multiplier(tier == DropTableData.MonsterTier.BOSS)


func _drop_equipment_of_grade(monster_level: int, grade: ItemData.ItemGrade, pos: Vector2) -> void:
	var slot := roll_equipment_slot(rate_config, randf() * total_slot_weight(rate_config))
	var item := resolve_equipment_item(
		_item_cache, monster_level, grade, slot, rate_config.current_job_weapon_series_prefix
	)
	if item:
		_spawn_item(item, 1, pos)


func _find_item(item_id: String) -> ItemData:
	for it in _item_cache:
		if it.item_id == item_id:
			return it
	return null


func _spawn_item(item: ItemData, quantity: int, pos: Vector2) -> void:
	item_dropped.emit(item, quantity, pos)
	if world_item_scene == null or not is_inside_tree():
		return
	var instance: Node = world_item_scene.instantiate()
	instance.item_data = item
	instance.quantity = quantity
	get_parent().add_child(instance)
	if instance is Node2D:
		instance.global_position = pos


func _load_all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	var dir := DirAccess.open("res://data/items")
	if dir == null:
		return items
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load("res://data/items/%s" % file_name)
			if res is ItemData:
				items.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return items
