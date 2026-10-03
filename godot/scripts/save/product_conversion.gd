extends RefCounted
# gdlint: disable=max-returns
## 제품 V7은 영지/여행 상태를 추가한다. V6 개정2 원본 규칙은 별도 동결한다.
const Frozen = preload("res://scripts/save/frozen_v6/conversion.gd")
const Economy = preload("res://scripts/economy/economy_save_candidate.gd")
const Content = preload("res://scripts/content/game_content.gd")
const Catalog = preload("res://scripts/content/game_catalog.gd")
const Territory = preload("res://scripts/territory/territory_model.gd")
const Travel = preload("res://scripts/territory/territory_travel.gd")
var legacy = Frozen.new()
var expanded = Economy.new()
var model = legacy.model


func _init() -> void:
	expanded.expanded.quest_catalog = Catalog.new(expanded.expanded.registry)
	expanded.expanded.regions = Content


func validate(data: Dictionary, account: Dictionary) -> String:
	var version: Variant = data.get("character_save_version")
	if version != 7:
		return legacy.validate(data, account)
	var revision: Variant = data.get("content_revision")
	if not expanded.expanded.integer(revision, 1, Content.CURRENT_REVISION):
		return "unsupported_content"
	if not data.get("progress") is Dictionary:
		return "progress_fields"
	if not data.progress.get("quests") is Dictionary:
		return "quest_fields"
	if not data.progress.get("territory") is Dictionary:
		return "territory_fields"
	if not data.progress.get("travel") is Dictionary:
		return "travel_fields"
	# 새 구조를 먼저 검증한다. 아래 공통 구조 검사는 이미 검증한 두 영역만 제외한다.
	var error: String = Territory.validate(
		data.progress.get("territory"), data.progress.quests
	)
	if error != "":
		return error
	error = Travel.validate(data.progress.get("travel"))
	if error != "":
		return error
	var copy := data.duplicate(true)
	copy.erase("content_revision")
	copy.character_save_version = 5
	copy.progress.territory = {}
	copy.progress.erase("travel")
	error = expanded.validate(copy, account)
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
	if data.character_save_version == 7:
		return {"ok": true, "code": "ok", "data": data.duplicate(true)}
	# 원본 V1~V6는 새 지역/영지 구조를 추가하기 전에 동결된 규칙을 통과해야 한다.
	var result: Dictionary = legacy.upgrade(data, account)
	if not result.ok:
		return result
	result.data.character_save_version = 7
	result.data.content_revision = Content.CURRENT_REVISION
	result.data.progress.territory = Territory.initial(
		result.data.progress.quests
	)
	result.data.progress.travel = Travel.initial(
		result.data.progress.quests, result.data.world.map_id
	)
	error = validate(result.data, account)
	return result if error == "" else {"ok": false, "code": error, "data": {}}
