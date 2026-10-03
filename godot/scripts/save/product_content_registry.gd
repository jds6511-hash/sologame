extends "res://scripts/save/save_content_registry.gd"
## 제품 전용 확장. 구버전 검증기는 확장하지 않은 기본 목록을 계속 사용한다.
const SHARPSHOOTER = preload("res://data/jobs/job_def_sharpshooter.tres")
const NEW_ITEM = preload("res://data/items/wpn_bw_40_b.tres")
const NEW_SKILLS := {
	"sharpshooter_precision_burst":
	preload("res://data/player/skills/sharpshooter/skill_slot4_precision_burst.tres"),
	"sharpshooter_retreat_shot":
	preload("res://data/player/skills/sharpshooter/skill_slotq_retreat_shot.tres"),
	"sharpshooter_breathing":
	preload("res://data/player/skills/sharpshooter/skill_slote_breathing.tres"),
	"sharpshooter_focus_pierce":
	preload("res://data/player/skills/sharpshooter/skill_ultimate_focus_pierce.tres"),
}


func _init() -> void:
	super._init()
	jobs["sharpshooter"] = SHARPSHOOTER
	skills = skills.duplicate()
	skills.merge(NEW_SKILLS)
	items[NEW_ITEM.item_id] = NEW_ITEM


func transition_level(job_id: String, rules: RefCounted) -> int:
	if job_id == "sharpshooter":
		return SHARPSHOOTER.transition_level()
	return super.transition_level(job_id, rules)


func revision_error(data: Dictionary, revision: int) -> String:
	if revision >= 6:
		return ""
	var player: Variant = data.get("player", {})
	if player is Dictionary:
		if player.get("job_id") == "sharpshooter":
			return "unsupported_content"
		for field in ["skill_levels", "skill_costs"]:
			var entries: Variant = player.get(field, {})
			if entries is Dictionary:
				for id in entries:
					if NEW_SKILLS.has(id):
						return "unsupported_content"
	var inventory: Variant = data.get("inventory", {})
	if inventory is Dictionary:
		for field in ["bag", "overflow"]:
			var entries: Variant = inventory.get(field, [])
			if entries is Array:
				for entry in entries:
					if entry is Dictionary and entry.get("item_id") == NEW_ITEM.item_id:
						return "unsupported_content"
		var equipment: Variant = inventory.get("equipment", {})
		if equipment is Dictionary and NEW_ITEM.item_id in equipment.values():
			return "unsupported_content"
	return ""
