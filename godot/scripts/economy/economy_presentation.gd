## 표시 전용. 저장 ID·가격·착용 판정은 모델에서 읽는다.
extends RefCounted

const KINDS := ["무기", "방어구", "장신구", "회복약", "특수 무기", "재료"]
const STATS := ["옵션 없음", "공격력", "방어력", "치명타 확률", "최대 HP", "최대 MP", "공격 속도"]


static func item_name(item: ItemData) -> String:
	var name := item.item_name
	var suffix := name.get_slice(" ", name.get_slice_count(" ") - 1)
	if suffix.is_valid_int():
		name = name.trim_suffix(" " + suffix)
	return name


static func effect(item: ItemData) -> String:
	if item.heal_amount > 0:
		return "HP %d 회복" % item.heal_amount
	if item.main_stat_type == ItemData.MainStatType.NONE:
		return KINDS[item.item_type]
	return "%s +%.2f%s" % [STATS[item.main_stat_type], item.main_stat_value,
		"%" if item.main_stat_type in [3, 4, 6] else ""]


static func condition(item: ItemData) -> String:
	var family := ""
	if item.item_id.begins_with("WPN-GS"):
		family = "전사·검투사 · "
	elif item.item_id.begins_with("WPN-BW"):
		family = "궁수 · "
	elif item.item_id.begins_with("WPN-SW"):
		family = "모험가 · "
	return "%s요구 Lv%d · %s등급" % [family, item.level_limit, ["C", "B", "A", "S"][item.grade]]


static func icon(item: ItemData) -> Texture2D:
	var exact := "res://assets/icons/items/" + item.item_id.to_lower().replace("-", "_") + ".png"
	if ResourceLoader.exists(exact):
		return load(exact)
	return null


static func comparison(runtime: Node, id: String, slot: String) -> String:
	var state: Dictionary = runtime.state()
	var old: String = state.equipment[slot]
	var text := "현재: " + ("없음" if old == "" else item_name(runtime.model.items[old]))
	var error: String = runtime.model.equip_error(id, slot, runtime.level(), runtime.job_id())
	if not error.is_empty():
		return text + "\n현재 착용 불가 · 조건을 확인하세요"
	var item: ItemData = runtime.model.items[id]
	text += "\n상품 주 옵션: " + effect(item)
	if old != "":
		text += "\n현재 주 옵션: " + effect(runtime.model.items[old])
	if item.move_speed_bonus != 0:
		text += "\n상품 이동 속도 +%.2f" % item.move_speed_bonus
	var next: Dictionary = state.equipment.duplicate()
	next[slot] = id
	var before: CombatantStats = runtime.model.stats(runtime.level(), runtime.job_id(), state.equipment)
	var after: CombatantStats = runtime.model.stats(runtime.level(), runtime.job_id(), next)
	for key in ["attack_power", "defense", "max_hp", "max_mp"]:
		var title: String = {"attack_power": "공격력", "defense": "방어력", "max_hp": "최대 HP", "max_mp": "최대 MP"}[key]
		text += "\n%s %.1f → %.1f (%+.1f)" % [title, before.get(key), after.get(key), after.get(key) - before.get(key)]
	return text
