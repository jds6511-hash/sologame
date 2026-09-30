extends RefCounted
## V1~V6 원본을 동결된 검증기로 확인한 뒤에만 격리 V7로 변환한다.
const Legacy = preload("res://scripts/chapter_two/m7_save_candidate.gd")
const Economy = preload("res://scripts/economy/economy_save_candidate.gd")
const CatalogClosure = preload("res://scripts/chapter_two_closure/closure_catalog.gd")
const RegionsClosure = preload("res://scripts/chapter_two_closure/closure_regions.gd")
var legacy = Legacy.new()
var expanded = Economy.new()
var model = legacy.model


func _init() -> void:
	expanded.expanded.quest_catalog = CatalogClosure.new(expanded.expanded.registry)
	expanded.expanded.regions = RegionsClosure


func validate(data: Dictionary, account: Dictionary) -> String:
	if data.get("character_save_version") != 7:
		return legacy.validate(data, account)
	var copy := data.duplicate(true)
	copy.character_save_version = 5
	var error: String = expanded.validate(copy, account)
	if error != "":
		return error
	if data.world.map_id in ["novera_commons", "novera_outskirts"]:
		if data.progress.quests.get("MQ-01-05", {}).get("state") != "completed":
			return "region_locked"
	if data.world.map_id == "novera_rift":
		if data.progress.quests.get("MQ-02-04", {}).get("state") != "completed":
			return "region_locked"
	return ""


func upgrade(data: Dictionary, account: Dictionary) -> Dictionary:
	var error := validate(data, account)
	if error != "":
		return {"ok": false, "code": error, "data": {}}
	if data.character_save_version == 7:
		return {"ok": true, "code": "ok", "data": data.duplicate(true)}
	var result: Dictionary = legacy.upgrade(data, account)
	if not result.ok:
		return result
	result.data.character_save_version = 7
	error = validate(result.data, account)
	return result if error == "" else {"ok": false, "code": error, "data": {}}
