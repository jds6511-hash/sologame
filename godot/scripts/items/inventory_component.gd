## 인벤토리 최소 기능 컴포넌트 (IT-3) — 줍기·장착·버리기 + 골드.
##
## economy-foundation.md 3장(8슬롯 구조)·growth.md 3장을 따른다. 8슬롯 = 무기 1 + 방어구
## 4부위 + 반지 2 + 목걸이 1. 반지는 슬롯 종류가 1개뿐이라 equipped_rings 배열(2칸)로
## 따로 관리한다(ItemData.EquipSlot 주석과 동일한 설계).
##
## PlayerStatsComponent(커밋 374a8a0)·PlayerAttackResolver(CB-3)와의 연동은 CombatantStats
## 리소스 공유로 이뤄진다 — scenes/player/player.tscn을 보면 AttackResolver.attacker_stats와
## PlayerStats.stats가 이미 같은 CombatantStats 리소스(예: warrior_lv1_combatant_stats.tres)를
## 가리킨다. 이 컴포넌트의 combat_stats에도 "같은" 리소스를 할당하면, 장착 시 공격력/방어력/
## 최대 HP/최대 MP를 그 리소스에 직접 반영해 전투 계산·HP·MP 컴포넌트 양쪽에 즉시 퍼진다.
## player_stats_component.gd·player_attack_resolver.gd 등 다른 에이전트 파일은 전혀 건드리지
## 않았다 — 씬 배선(플레이어에 "Inventory" 자식 노드 추가) 방법은 결과 보고에 기록했다.
##
## 포션 사용은 combat.md 5-4장(CB-5)이 이미 구현한 PlayerStatsComponent.use_potion()의 짝이다
## — 그 스크립트 주석이 "인벤토리 수량 차감은 IT-3 몫"이라 명시한 지점을 use_potion()으로
## 채운다.
class_name InventoryComponent
extends Node

signal item_added(item: ItemData, quantity: int)
signal item_removed(item: ItemData, quantity: int)
signal equipped(slot: ItemData.EquipSlot, item: ItemData, ring_index: int)
signal unequipped(slot: ItemData.EquipSlot, item: ItemData, ring_index: int)
signal gold_changed(amount: int)
signal inventory_full  ## UI 안내용 — 가방이 가득 차 줍기 실패했을 때

const RING_COUNT := 2

## 장착 스탯을 반영할 대상. player.tscn의 CombatantStats(예: id="6" 리소스)와 공유해야
## 장착 효과가 실제 전투에 반영된다(상단 클래스 주석 참고).
@export var combat_stats: CombatantStats

## 가방 칸 수 — ux-foundation.md 8장이 "인벤토리 탭 상세(칸 수 등)"를 M2 이후 상세 설계로
## 미뤄둔 상태라, 확정 수치가 없어 임시값이다. **기획 필요**: ui-dev/systems-designer가
## 실제 칸 수를 정하면 이 기본값을 갱신할 것.
@export var bag_capacity: int = 30

var gold: int = 0
var equipped_items: Dictionary = {}  ## ItemData.EquipSlot(int, RING 제외) -> ItemData
var equipped_rings: Array = [null, null]  ## 반지 전용 2슬롯
var bag: Array = []  ## [{item: ItemData, quantity: int}, ...]

var _base_attack_power: float = 0.0
var _base_defense: float = 0.0
var _base_max_hp: float = 0.0
var _base_max_mp: float = 0.0


func _ready() -> void:
	if combat_stats:
		_base_attack_power = combat_stats.attack_power
		_base_defense = combat_stats.defense
		_base_max_hp = combat_stats.max_hp
		_base_max_mp = combat_stats.max_mp


# --- 줍기 ---


func pickup(item: ItemData, quantity: int = 1) -> bool:
	if item == null or quantity <= 0:
		return false
	if not add_to_bag(item, quantity):
		return false
	item_added.emit(item, quantity)
	return true


## WorldItem(scripts/items/world_item.gd)이 F 입력 시 호출하는 진입점.
func pickup_world_item(world_item: WorldItem) -> bool:
	if world_item == null or world_item.item_data == null:
		return false
	if not pickup(world_item.item_data, world_item.quantity):
		return false
	world_item.queue_free()
	return true


func add_to_bag(item: ItemData, quantity: int) -> bool:
	if item == null or quantity <= 0:
		return false
	var entry: Dictionary = _find_bag_entry(item.item_id)
	if not entry.is_empty():
		entry.quantity += quantity
		return true
	if bag.size() >= bag_capacity:
		inventory_full.emit()
		return false
	bag.append({"item": item, "quantity": quantity})
	return true


func get_bag_quantity(item_id: String) -> int:
	var entry := _find_bag_entry(item_id)
	return entry.quantity if not entry.is_empty() else 0


# --- 골드 ---


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)


## 사망 패널티(M3 D3-2) 등 "대가 없이 잃는" 골드 차감. spend_gold와 달리 보유액이 부족해도
## 실패하지 않고 남은 만큼만 잃으며, 실제로 잃은 액수를 돌려준다(골드는 음수가 되지 않는다).
## 상실액 산정(비율·상한)은 호출자 몫이다 — 사망 규격은 PlayerDeathRules에 있다.
func lose_gold(amount: int) -> int:
	if amount <= 0 or gold <= 0:
		return 0
	var lost := mini(amount, gold)
	gold -= lost
	gold_changed.emit(gold)
	return lost


func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# --- 장착/해제 (growth.md 3장 8슬롯, 스탯 반영) ---


## 가방에 있는 아이템을 장착한다. 성공하려면 가방에 해당 아이템이 1개 이상 있어야 한다
## (드랍 → 줍기 → 장착 순서를 강제). ring_index는 item.equip_slot == RING일 때만 쓰인다.
func equip(item: ItemData, ring_index: int = 0) -> bool:
	if item == null or item.equip_slot == ItemData.EquipSlot.NONE:
		return false
	var previous := get_equipped(item.equip_slot, ring_index)
	var quantity := get_bag_quantity(item.item_id)
	if quantity <= 0:
		return false
	# 교체품 한 개를 꺼낸 뒤 기존 장비를 넣을 칸이 생기는지 먼저 검사한다.
	if (
		previous
		and get_bag_quantity(previous.item_id) == 0
		and quantity > 1
		and bag.size() >= bag_capacity
	):
		inventory_full.emit()
		return false
	if not _remove_from_bag(item.item_id, 1):
		return false
	_swap_equipped(item, ring_index)
	if previous:
		add_to_bag(previous, 1)
	_recompute_equipment_stats()
	equipped.emit(item.equip_slot, item, ring_index)
	return true


func unequip(slot: ItemData.EquipSlot, ring_index: int = 0) -> ItemData:
	var removed := get_equipped(slot, ring_index)
	if removed == null or not add_to_bag(removed, 1):
		return null
	if slot == ItemData.EquipSlot.RING:
		ring_index = clampi(ring_index, 0, RING_COUNT - 1)
		equipped_rings[ring_index] = null
	else:
		equipped_items.erase(slot)
	_recompute_equipment_stats()
	unequipped.emit(slot, removed, ring_index)
	return removed


func get_equipped(slot: ItemData.EquipSlot, ring_index: int = 0) -> ItemData:
	if slot == ItemData.EquipSlot.RING:
		return equipped_rings[clampi(ring_index, 0, RING_COUNT - 1)]
	return equipped_items.get(slot)


func _swap_equipped(item: ItemData, ring_index: int) -> ItemData:
	if item.equip_slot == ItemData.EquipSlot.RING:
		ring_index = clampi(ring_index, 0, RING_COUNT - 1)
		var previous: ItemData = equipped_rings[ring_index]
		equipped_rings[ring_index] = item
		return previous
	var previous: ItemData = equipped_items.get(item.equip_slot)
	equipped_items[item.equip_slot] = item
	return previous


## 장착 중인 아이템들의 주 옵션을 합산해 combat_stats(공유 CombatantStats)에 반영한다.
## 목걸이의 MAX_HP 값은 economy-foundation.md 3-3장 "데이터 저장 규칙"에 따라 절댓값이
## 아니라 증가율(%)이므로 base_max_hp에 곱한다 — 무기/방어구의 ATTACK_POWER/DEFENSE는
## 절댓값 가산이다.
func _recompute_equipment_stats() -> void:
	if combat_stats == null:
		return
	var bonus_attack := 0.0
	var bonus_defense := 0.0
	var bonus_max_hp_percent := 0.0
	var bonus_max_mp := 0.0
	for item in _all_equipped_items():
		match item.main_stat_type:
			ItemData.MainStatType.ATTACK_POWER:
				bonus_attack += item.main_stat_value
			ItemData.MainStatType.DEFENSE:
				bonus_defense += item.main_stat_value
			ItemData.MainStatType.MAX_HP:
				bonus_max_hp_percent += item.main_stat_value
			ItemData.MainStatType.MAX_MP:
				bonus_max_mp += item.main_stat_value
			_:
				pass
	combat_stats.attack_power = _base_attack_power + bonus_attack
	combat_stats.defense = _base_defense + bonus_defense
	combat_stats.max_hp = _base_max_hp * (1.0 + bonus_max_hp_percent / 100.0)
	combat_stats.max_mp = _base_max_mp + bonus_max_mp


func _all_equipped_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for slot in equipped_items:
		if equipped_items[slot]:
			items.append(equipped_items[slot])
	for ring in equipped_rings:
		if ring:
			items.append(ring)
	return items


## 치명타 확률(반지)·공격 속도·이동 속도(신발) 보너스는 CombatantStats에 대응 필드가
## 없어(DamageCalculator·PlayerMovementData는 gameplay-dev 소관) 아직 자동 반영되지 않는다.
## 대신 합산치를 조회 인터페이스로 노출한다 — 결과 보고 "UI/향후 연동" 항목 참고.
func get_total_move_speed_bonus() -> float:
	var total := 0.0
	for item in _all_equipped_items():
		total += item.move_speed_bonus
	return total


func get_total_crit_chance_bonus_percent() -> float:
	var total := 0.0
	for item in _all_equipped_items():
		if item.main_stat_type == ItemData.MainStatType.CRIT_CHANCE:
			total += item.main_stat_value
	return total


func get_total_attack_speed_bonus_percent() -> float:
	var total := 0.0
	for item in _all_equipped_items():
		if item.main_stat_type == ItemData.MainStatType.ATTACK_SPEED:
			total += item.main_stat_value
	return total


# --- 버리기 ---


func drop_item(item_id: String, quantity: int = 1) -> ItemData:
	if quantity <= 0:
		return null
	var entry := _find_bag_entry(item_id)
	if entry.is_empty() or entry.quantity < quantity:
		return null
	var item: ItemData = entry.item
	entry.quantity -= quantity
	if entry.quantity <= 0:
		bag.erase(entry)
	item_removed.emit(item, quantity)
	return item


# --- 포션 (combat.md 5-4장 CB-5의 짝 — player_stats_component.gd "인벤토리 수량 차감은
# IT-3 몫" 지점) ---


## item_id 포션이 가방에 있는지 먼저 확인한 뒤 실제 사용 판정(쿨다운·보스전 캡)을
## player_stats에 위임한다. 성공한 경우에만 수량을 차감한다. 회복량은 아이템 데이터의
## 고정치(ItemData.heal_amount, economy-foundation.md 5-1장)를 넘겨 적용한다 — 티어별 고정치
## 덕분에 저레벨이 상급 포션으로 30% 규격을 넘겨 회복하는 구멍이 막힌다.
func use_potion(item_id: String, player_stats: PlayerStatsComponent) -> bool:
	var entry := _find_bag_entry(item_id)
	if (
		entry.is_empty()
		or entry.quantity <= 0
		or player_stats == null
		or not _is_usable_potion(entry.item)
	):
		return false
	if not player_stats.use_potion(entry.item.heal_amount):
		return false
	entry.quantity -= 1
	if entry.quantity <= 0:
		bag.erase(entry)
	item_removed.emit(entry.item, 1)
	return true


## 5번 퀵슬롯은 사용 가능한 하급 포션부터 소비한다. 같은 회복량이면 ID 순서로 고정한다.
func get_quickslot_potion() -> ItemData:
	var selected: ItemData = null
	for entry in bag:
		var item: ItemData = entry.item
		if entry.quantity <= 0 or not _is_usable_potion(item):
			continue
		if (
			selected == null
			or item.heal_amount < selected.heal_amount
			or (item.heal_amount == selected.heal_amount and item.item_id < selected.item_id)
		):
			selected = item
	return selected


func _is_usable_potion(item: ItemData) -> bool:
	var progression := get_node_or_null("../PlayerProgression") as PlayerProgression
	var level := progression.current_level if progression else 1
	return (
		item != null
		and item.item_type == ItemData.ItemType.POTION
		and item.heal_amount > 0.0
		and level >= item.level_limit
	)


func _remove_from_bag(item_id: String, quantity: int) -> bool:
	var entry := _find_bag_entry(item_id)
	if entry.is_empty() or entry.quantity < quantity:
		return false
	entry.quantity -= quantity
	if entry.quantity <= 0:
		bag.erase(entry)
	return true


func _find_bag_entry(item_id: String) -> Dictionary:
	for entry in bag:
		if entry.item.item_id == item_id:
			return entry
	return {}
