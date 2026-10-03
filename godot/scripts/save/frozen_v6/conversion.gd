extends RefCounted
## 제품 V6는 콘텐츠 개정을 분리한다. 같은 번호의 옛 QA 후보는 호환하지 않는다.
const Frozen = preload("res://scripts/economy/economy_save_candidate.gd")
const Content = preload("res://scripts/save/frozen_v6/content.gd")
const Catalog = preload("res://scripts/save/frozen_v6/catalog.gd")
var legacy = Frozen.new()
var expanded = Frozen.new()
var model = legacy.model


func _init() -> void:
	expanded.expanded.quest_catalog = Catalog.new(expanded.expanded.registry)
	expanded.expanded.regions = Content


func validate(data: Dictionary, account: Dictionary) -> String:
	var version: Variant = data.get("character_save_version")
	if version != 6:
		return legacy.validate(data, account)
	var revision: Variant = data.get("content_revision")
	if not expanded.expanded.integer(revision, 1, Content.CURRENT_REVISION):
		return "unsupported_content"
	var copy := data.duplicate(true)
	copy.erase("content_revision")
	copy.character_save_version = 5
	var error: String = expanded.validate(copy, account)
	if error != "":
		return error
	var required: String = Content.REGION_REQUIREMENTS.get(data.world.map_id, "")
	if required != "" and data.progress.quests.get(required, {}).get("state") != "completed":
		return "region_locked"
	for id in data.progress.quests:
		if expanded.expanded.quest_catalog.eligibility_error(id, data.progress.quests) != "":
			return "reputation_required"
	return ""


func upgrade(data: Dictionary, account: Dictionary) -> Dictionary:
	var error := validate(data, account)
	if error != "":
		return {"ok": false, "code": error, "data": {}}
	if data.character_save_version == 6:
		return {"ok": true, "code": "ok", "data": data.duplicate(true)}
	# 원본 V1~V5는 통합 목록으로 해석하기 전에 동결된 원본 규칙을 통과해야 한다.
	var result: Dictionary = legacy.upgrade(data, account)
	if not result.ok:
		return result
	result.data.character_save_version = 6
	result.data.content_revision = Content.CURRENT_REVISION
	error = validate(result.data, account)
	return result if error == "" else {"ok": false, "code": error, "data": {}}
