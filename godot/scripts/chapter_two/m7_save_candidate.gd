extends RefCounted
## 원본 V1~V5는 기존 규칙으로 검사한 뒤에만 V6로 변환한다.
const Economy = preload("res://scripts/economy/economy_save_candidate.gd")
const CatalogM7 = preload("res://scripts/chapter_two/m7_catalog.gd")
const RegionsM7 = preload("res://scripts/chapter_two/m7_regions.gd")
var legacy = Economy.new()
var expanded = Economy.new()
var model = legacy.model


func _init() -> void:
	expanded.expanded.quest_catalog = CatalogM7.new(expanded.expanded.registry)
	expanded.expanded.regions = RegionsM7


func validate(data: Dictionary, account: Dictionary) -> String:
	if data.get("character_save_version") != 6:
		return legacy.validate(data, account)
	var copy := data.duplicate(true)
	copy.character_save_version = 5
	var error: String = expanded.validate(copy, account)
	if error != "":
		return error
	if data.world.map_id in ["novera_commons", "novera_outskirts"]:
		if data.progress.quests.get("MQ-01-05", {}).get("state") != "completed":
			return "region_locked"
	return ""


func upgrade(data: Dictionary, account: Dictionary) -> Dictionary:
	var error := validate(data, account)
	if error != "":
		return {"ok": false, "code": error, "data": {}}
	if data.character_save_version == 6:
		return {"ok": true, "code": "ok", "data": data.duplicate(true)}
	var result: Dictionary = legacy.upgrade(data, account)
	if not result.ok:
		return result
	result.data.character_save_version = 6
	error = validate(result.data, account)
	return result if error == "" else {"ok": false, "code": error, "data": {}}
