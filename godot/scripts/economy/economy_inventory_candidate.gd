extends InventoryComponent


func equip(item: ItemData, ring_index: int = 0) -> bool:
	if item == null or not get_parent().has_meta("economy_candidate"):
		return false
	var runtime = get_parent().get_meta("economy_candidate")
	for slot in runtime.model.registry.slots:
		if runtime.model.registry.slots[slot] == item.equip_slot:
			if item.equip_slot == ItemData.EquipSlot.RING:
				if ring_index not in [0, 1]:
					return false
				slot = "ring_1" if ring_index == 0 else "ring_2"
			return runtime.act("equip", item.item_id, slot) == ""
	return false


func unequip(slot: ItemData.EquipSlot, ring_index: int = 0) -> ItemData:
	var item := get_equipped(slot, ring_index)
	if item == null or not get_parent().has_meta("economy_candidate"):
		return null
	var runtime = get_parent().get_meta("economy_candidate")
	for key in runtime.model.registry.slots:
		if runtime.model.registry.slots[key] == slot:
			if slot == ItemData.EquipSlot.RING:
				if ring_index not in [0, 1]:
					return null
				key = "ring_1" if ring_index == 0 else "ring_2"
			return item if runtime.act("unequip", "", key) == "" else null
	return null
