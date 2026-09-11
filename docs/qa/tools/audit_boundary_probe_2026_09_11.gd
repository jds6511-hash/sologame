## 2026-09-11 감사용 재현 도구. 게임 구현을 변경하지 않는다.
## 저장소 루트에서 Godot --headless --path godot --script 절대경로 로 실행한다.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _item(id: String) -> ItemData:
	var item := ItemData.new()
	item.item_id = id
	item.equip_slot = ItemData.EquipSlot.WEAPON
	return item


func _run() -> void:
	var original := _item("감사-기존무기")
	var replacement := _item("감사-교체무기")
	var inventory_script = load("res://scripts/items/inventory_component.gd")
	var inventory = inventory_script.new()
	root.add_child(inventory)
	inventory.bag_capacity = 1
	inventory.pickup(original)
	inventory.equip(original)
	inventory.pickup(replacement)
	inventory.unequip(ItemData.EquipSlot.WEAPON)
	var lost_on_unequip: bool = (
		inventory.get_bag_quantity(original.item_id) == 0
		and inventory.get_equipped(ItemData.EquipSlot.WEAPON) == null
	)
	print("감사 재현 — 가방 포화 해제 시 기존 무기 유실: ", lost_on_unequip)
	inventory.free()

	inventory = inventory_script.new()
	root.add_child(inventory)
	inventory.bag_capacity = 1
	inventory.pickup(original)
	inventory.equip(original)
	inventory.pickup(replacement, 2)
	var swap_ok: bool = inventory.equip(replacement)
	var lost_on_swap: bool = (
		swap_ok
		and inventory.get_bag_quantity(original.item_id) == 0
		and inventory.get_equipped(ItemData.EquipSlot.WEAPON) == replacement
	)
	print("감사 재현 — 가방 포화 중첩 무기 교체 시 기존 무기 유실: ", lost_on_swap)
	var before: int = inventory.get_bag_quantity(replacement.item_id)
	inventory.drop_item(replacement.item_id, -2)
	var negative_drop_added: bool = inventory.get_bag_quantity(replacement.item_id) == before + 2
	print("감사 재현 — 음수 버리기 수량으로 보유량 증가: ", negative_drop_added)
	inventory.free()

	var player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var empty_bag = inventory_script.new()
	empty_bag.name = "Inventory"
	player.add_child(empty_bag)
	var stats = player.get_node("PlayerStats")
	stats.current_hp = 10.0
	# 입력 함수가 호출하는 동일 회복 API를 확인한다. 키 이벤트 재현은 아니다.
	stats.use_potion()
	var free_potion: bool = stats.current_hp > 10.0 and empty_bag.bag.is_empty()
	print("감사 재현 — 포션 입력이 호출하는 회복 API는 빈 가방에서도 회복: ", free_potion)
	var progression = player.get_node("PlayerProgression")
	var transition = player.get_node("PlayerJobTransition")
	var points = player.get_node("PlayerSkillPoints")
	while progression.current_level < 10:
		progression.add_exp(progression.exp_to_next())
	var warrior_ok: bool = transition.perform_transition(&"warrior")
	var upgrade_ok: bool = points.try_upgrade_skill(&"분쇄 베기", false)
	while progression.current_level < 40:
		progression.add_exp(progression.exp_to_next())
	var spent_before: int = points.spent_points
	var gladiator_ok: bool = transition.perform_transition(&"gladiator")
	var stranded_upgrade: bool = (
		warrior_ok
		and upgrade_ok
		and gladiator_ok
		and player.skill_slot_4.skill_name == "검투 선풍"
		and points.get_skill_level(&"분쇄 베기") == 2
		and points.get_skill_level(&"검투 선풍") == 1
		and points.spent_points == spent_before
	)
	print("감사 재현 — 2차 전직 교체 스킬에 강화 미승계·소비 포인트 잔존: ", stranded_upgrade)
	player.free()

	var clock_node := root.get_node("GameClock")
	clock_node.reset()
	var events: Array[String] = []
	clock_node.day_started.connect(func(_day: int): events.append("낮"))
	clock_node.night_started.connect(func(_day: int): events.append("밤"))
	clock_node.advance_time(clock_node.time_data.real_seconds_per_game_day)
	var missed_boundary: bool = clock_node.day_number == 2 and events.is_empty()
	print("감사 재현 — 하루 일괄 경과 후 낮/밤 경계 이벤트 누락: ", missed_boundary)
	print("감사 주의 — 이 출력은 결함 재현이며 게임 통과 판정이 아니다.")
	var reproduced: bool = (
		lost_on_unequip
		and lost_on_swap
		and negative_drop_added
		and free_potion
		and stranded_upgrade
		and missed_boundary
	)
	quit(0 if reproduced else 1)
