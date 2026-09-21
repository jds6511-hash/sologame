# gdlint: disable=max-returns
extends RefCounted

const Registry = preload("res://scripts/save/save_content_registry.gd")
const MAX_INT := 2147483647
var registry = Registry.new()


func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (
		(value is int or value is float)
		and is_finite(value)
		and value >= minimum
		and value <= maximum
	)


func integer(value: Variant, minimum: int = 0, maximum: int = MAX_INT) -> bool:
	return number(value, minimum, maximum) and value == floor(value)


func identifier(value: Variant) -> bool:
	if not value is String or value.length() != 32:
		return false
	for ch in value:
		if not ch in "0123456789abcdef":
			return false
	return true


func fields(data: Variant, names: Array) -> bool:
	if not data is Dictionary:
		return false
	return data.size() == names.size() and data.has_all(names)


func transfer_error(data: Dictionary) -> String:
	if not data.has_all(["pending_transfer", "applied_transfer_ids"]):
		return "missing_transfer_fields"
	if data.pending_transfer != null or data.applied_transfer_ids != []:
		return "pending_transfer"
	return ""


func account_error(data: Dictionary) -> String:
	var transfer := transfer_error(data)
	if not transfer.is_empty():
		return transfer
	if not fields(
		data,
		[
			"account_id",
			"account_save_version",
			"clear_count",
			"discoveries",
			"achievements",
			"cosmetics",
			"seen_content",
			"tutorial_completed",
			"legacy",
			"storage",
			"pending_transfer",
			"applied_transfer_ids"
		]
	):
		return "account_fields"
	if not identifier(data.account_id) or data.account_save_version != 1:
		return "account_identity"
	if (
		not data.tutorial_completed is bool
		or not integer(data.clear_count)
		or data.clear_count != 0
	):
		return "account_progress"
	# 후속 마일스톤 콘텐츠를 조용히 버리지 않도록 M4에서는 빈 예약 영역만 수용한다.
	for key in ["discoveries", "achievements", "cosmetics", "seen_content", "storage"]:
		if data[key] != []:
			return "reserved_account_content"
	if data.legacy != {}:
		return "reserved_account_content"
	return ""


func character_error(data: Dictionary, account: Dictionary) -> String:
	var error := account_error(account)
	if not error.is_empty():
		return error
	error = transfer_error(data)
	if not error.is_empty():
		return error
	if not fields(
		data,
		[
			"character_id",
			"character_save_version",
			"account_id",
			"name",
			"play_seconds",
			"player",
			"inventory",
			"world",
			"progress",
			"tutorial",
			"pending_transfer",
			"applied_transfer_ids"
		]
	):
		return "character_fields"
	if not identifier(data.character_id) or data.character_save_version != 1:
		return "character_identity"
	if data.account_id != account.account_id:
		return "account_mismatch"
	if not data.name is String or data.name.is_empty() or data.name.length() > 40:
		return "character_name"
	if not number(data.play_seconds, 0, MAX_INT):
		return "play_seconds"
	for result in [
		player_error(data.player), inventory_error(data.inventory), world_error(data.world)
	]:
		if not result.is_empty():
			return result
	if not fields(data.tutorial, ["tutorial_done", "hint_heal_done"]):
		return "tutorial_fields"
	for value in data.tutorial.values():
		if not value is bool:
			return "tutorial_value"
	if not fields(
		data.progress,
		["quests", "reputation", "territory", "story_flags", "first_death_waiver_used"]
	):
		return "progress_fields"
	if (
		data.progress.quests != {}
		or data.progress.territory != {}
		or data.progress.story_flags != {}
	):
		return "reserved_progress"
	if not integer(data.progress.reputation) or data.progress.reputation != 0:
		return "reputation"
	if not data.progress.first_death_waiver_used is bool:
		return "death_waiver"
	return ""


func player_error(data: Variant) -> String:
	if not fields(
		data,
		[
			"level",
			"exp",
			"job_id",
			"hp",
			"mp",
			"skill_points",
			"spent_points",
			"skill_levels",
			"skill_costs"
		]
	):
		return "player_fields"
	if not integer(data.level, 1, Registry.CURVE.max_level) or not integer(data.exp):
		return "level_exp"
	var limit: int = (
		1 if data.level == Registry.CURVE.max_level else Registry.CURVE.req(int(data.level))
	)
	if data.exp >= limit:
		return "exp_overflow"
	if (
		not data.job_id is String
		or (data.job_id != "adventurer" and not Registry.JOBS.has(data.job_id))
	):
		return "unknown_job"
	if data.job_id != "adventurer" and data.level < Registry.JOBS[data.job_id].transition_level():
		return "job_level"
	var stats := registry.max_stats(int(data.level), data.job_id)
	if not number(data.hp, 0.000001, stats.max_hp) or not number(data.mp, 0, stats.max_mp):
		return "vitals"
	return skills_error(data)


func skills_error(data: Dictionary) -> String:
	if not integer(data.skill_points) or not integer(data.spent_points):
		return "skill_points"
	if not data.skill_levels is Dictionary or not data.skill_costs is Dictionary:
		return "skill_maps"
	if data.skill_levels.size() != data.skill_costs.size():
		return "skill_cost_keys"
	var total := 0
	for id in data.skill_levels:
		if not registry.skills.has(id) or not data.skill_costs.has(id):
			return "unknown_skill"
		var skill = registry.skills[id]
		if not skill in registry.loadout(data.job_id):
			return "unavailable_skill"
		var ultimate: bool = (
			skill == Registry.JOBS[data.job_id].skill_ultimate
			if data.job_id != "adventurer"
			else false
		)
		if not integer(data.skill_levels[id], 2, Registry.RULE.max_skill_level(ultimate)):
			return "skill_level"
		if not integer(data.skill_costs[id], 1):
			return "skill_cost"
		var expected_cost := 0
		for step in range(1, int(data.skill_levels[id])):
			expected_cost += Registry.RULE.upgrade_cost(step, ultimate)
		if data.skill_costs[id] != expected_cost:
			return "skill_cost"
		# 검증만 한다. 복원/환급에는 저장된 실제 지출 장부를 그대로 사용한다.
		total += int(data.skill_costs[id])
	var earned: int = (int(data.level) - 1) * Registry.RULE.points_per_level
	earned += registry.tier(data.job_id) * Registry.RULE.points_per_transition
	if total != data.spent_points or total + data.skill_points != earned:
		return "skill_budget"
	return ""


func inventory_error(data: Variant) -> String:
	if not fields(data, ["gold", "bag", "equipment"]) or not integer(data.gold):
		return "inventory_fields"
	if not data.bag is Array or data.bag.size() > 30:
		return "bag_capacity"
	var seen := {}
	for entry in data.bag:
		if not fields(entry, ["item_id", "quantity"]):
			return "bag_entry"
		if not registry.items.has(entry.item_id) or seen.has(entry.item_id):
			return "bag_item_id"
		if not integer(entry.quantity, 1):
			return "bag_quantity"
		seen[entry.item_id] = true
	if not fields(data.equipment, registry.slots.keys()):
		return "equipment_slots"
	for slot in registry.slots:
		var id: Variant = data.equipment[slot]
		if id == "":
			continue
		if not registry.items.has(id) or registry.items[id].equip_slot != registry.slots[slot]:
			return "equipment_item"
	return ""


func world_error(data: Variant) -> String:
	if not fields(
		data,
		[
			"map_id",
			"position",
			"day_number",
			"elapsed_real_sec_in_day",
			"flags",
			"discovered_regions"
		]
	):
		return "world_fields"
	if data.map_id != Registry.MAP_ID:
		return "unknown_map"
	if not data.position is Array or data.position.size() != 2:
		return "position"
	for axis in data.position:
		if not number(axis, -MAX_INT, MAX_INT):
			return "position"
	if not integer(data.day_number, 1):
		return "day_number"
	if not number(data.elapsed_real_sec_in_day, 0, Registry.TIME.real_seconds_per_game_day):
		return "time"
	if data.elapsed_real_sec_in_day >= Registry.TIME.real_seconds_per_game_day:
		return "time"
	if data.flags != {} or data.discovered_regions != []:
		return "reserved_world_content"
	return ""
