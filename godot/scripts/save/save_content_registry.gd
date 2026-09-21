extends RefCounted

const Manifest = preload("res://scripts/save/save_content_manifest.gd")
const JOBS := {
	"warrior": preload("res://data/jobs/job_def_warrior.tres"),
	"archer": preload("res://data/jobs/job_def_archer.tres"),
	"gladiator": preload("res://data/jobs/job_def_gladiator.tres"),
}
const ADVENTURER = preload("res://data/progression/job_growth_adventurer.tres")
const FORMULA = preload("res://data/progression/stat_growth_formula.tres")
const CURVE = preload("res://data/progression/level_curve.tres")
const RULE = preload("res://data/progression/skill_point_rule.tres")
const TIME = preload("res://data/world/game_time_data.tres")
const MAP_ID := "eastern_frontier_start"
var items: Dictionary = {}
var skills: Dictionary = Manifest.SKILLS
var slots := {
	"weapon": ItemData.EquipSlot.WEAPON,
	"body": ItemData.EquipSlot.ARMOR_BODY,
	"legs": ItemData.EquipSlot.ARMOR_LEG,
	"head": ItemData.EquipSlot.ARMOR_HEAD,
	"feet": ItemData.EquipSlot.ARMOR_FOOT,
	"ring_1": ItemData.EquipSlot.RING,
	"ring_2": ItemData.EquipSlot.RING,
	"necklace": ItemData.EquipSlot.NECKLACE,
}


func _init() -> void:
	for item in Manifest.ITEMS:
		assert(not items.has(item.item_id), "Duplicate item ID")
		items[item.item_id] = item


func skill_id(runtime_name: StringName) -> String:
	for id in skills:
		if skills[id].skill_name == String(runtime_name):
			return id
	return ""


func loadout(job_id: String) -> Array:
	if job_id == "adventurer":
		return [skills.skill_slot1_strike, skills.skill_slot2_sprint, skills.skill_slot3_first_aid]
	return JOBS[job_id].skill_loadout().values()


func tier(job_id: String) -> int:
	if job_id == "adventurer":
		return 0
	return 2 if not JOBS[job_id].required_job_id.is_empty() else 1


func max_stats(level: int, job_id: String) -> CombatantStats:
	var result := CombatantStats.new()
	var growth: JobGrowthData = ADVENTURER if job_id == "adventurer" else JOBS[job_id].growth
	StatGrowthCalculator.apply(result, level, growth, FORMULA)
	return result
