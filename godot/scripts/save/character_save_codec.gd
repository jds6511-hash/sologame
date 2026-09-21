# gdlint: disable=max-returns
extends RefCounted

const Schema = preload("res://scripts/save/save_schema.gd")
var schema = Schema.new()
var registry = schema.registry


func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func new_account() -> Dictionary:
	return {
		"account_id": new_id(),
		"account_save_version": 1,
		"clear_count": 0,
		"discoveries": [],
		"achievements": [],
		"cosmetics": [],
		"seen_content": [],
		"tutorial_completed": false,
		"legacy": {},
		"storage": {},
		"pending_transfer": null,
		"applied_transfer_ids": []
	}


## 계정 연결 검증까지 포함한 파일 검증기. 호출자가 계정을 바꾸면 다시 연결해야 한다.
func bind_store(store: RefCounted, account: Dictionary) -> String:
	var error: String = schema.account_error(account)
	if not error.is_empty():
		return error
	var snapshot := account.duplicate(true)
	store.validators["account"] = schema.account_error
	store.validators["character"] = func(data: Dictionary) -> String:
		return schema.character_error(data, snapshot)
	return ""


## carry에는 해당 캐릭터의 검증된 세션 메타데이터만 전달한다. 다른 캐릭터와 공유하지 않는다.
func capture(player: Node2D, account_id: String, carry: Dictionary = {}) -> Dictionary:
	var progression = player.get_node("PlayerProgression")
	var points = player.get_node("PlayerSkillPoints")
	var stats = player.get_node("PlayerStats")
	var inventory = player.get_node("Inventory")
	var levels := {}
	var costs := {}
	for name in points._skill_levels:
		var id: String = registry.skill_id(name)
		levels[id] = points._skill_levels[name]
		costs[id] = points._skill_costs.get(name, 0)
	var bag := []
	for entry in inventory.bag:
		bag.append({"item_id": entry.item.item_id, "quantity": entry.quantity})
	var equipment := {}
	for slot in registry.slots:
		var item = inventory.get_equipped(registry.slots[slot], 1 if slot == "ring_2" else 0)
		equipment[slot] = "" if item == null else item.item_id
	var world: Dictionary = (
		carry
		. get(
			"world",
			{
				"map_id": registry.MAP_ID,
				"day_number": GameClock.day_number,
				"elapsed_real_sec_in_day": GameClock._elapsed_real_sec_in_day,
				"flags": {},
				"discovered_regions": []
			}
		)
		. duplicate(true)
	)
	world.position = [player.position.x, player.position.y]
	world.day_number = GameClock.day_number
	world.elapsed_real_sec_in_day = GameClock._elapsed_real_sec_in_day
	return {
		"character_id": carry.get("character_id", new_id()),
		"character_save_version": 1,
		"account_id": account_id,
		"name": carry.get("name", "모험가"),
		"play_seconds": carry.get("play_seconds", 0.0),
		"player":
		{
			"level": progression.current_level,
			"exp": progression.current_exp,
			"job_id": String(player.get_node("PlayerJobTransition").current_job_id),
			"hp": stats.current_hp,
			"mp": stats.current_mp,
			"skill_points": points.available_points,
			"spent_points": points.spent_points,
			"skill_levels": levels,
			"skill_costs": costs
		},
		"inventory": {"gold": inventory.gold, "bag": bag, "equipment": equipment},
		"world": world,
		"progress":
		(
			carry
			. get(
				"progress",
				{
					"quests": {},
					"reputation": 0,
					"territory": {},
					"story_flags": {},
					"first_death_waiver_used": false
				}
			)
			. duplicate(true)
		),
		"tutorial":
		carry.get("tutorial", {"tutorial_done": false, "hint_heal_done": false}).duplicate(true),
		"pending_transfer": null,
		"applied_transfer_ids": []
	}


## 신규 player.tscn + Inventory, _ready 완료 뒤 동기 호출. 기존 플레이어 덮어쓰기는 거부한다.
func restore_into(player: Node2D, data: Dictionary, account: Dictionary) -> String:
	var error: String = schema.character_error(data, account)
	if not error.is_empty():
		return error
	for name in [
		"PlayerProgression",
		"PlayerSkillPoints",
		"PlayerJobTransition",
		"PlayerStatGrowth",
		"PlayerStats",
		"Inventory"
	]:
		if not player.has_node(name) or not player.get_node(name).is_node_ready():
			return "target_not_ready"
	var progression = player.get_node("PlayerProgression")
	var transition = player.get_node("PlayerJobTransition")
	var points = player.get_node("PlayerSkillPoints")
	var inventory = player.get_node("Inventory")
	if (
		player.has_meta("save_restored")
		or progression.current_level != 1
		or progression.current_exp != 0
	):
		return "target_not_fresh"
	if transition.current_job_id != &"adventurer" or points.earned_points() != 0:
		return "target_not_fresh"
	if (
		inventory.gold != 0
		or not inventory.bag.is_empty()
		or not inventory._all_equipped_items().is_empty()
	):
		return "target_not_fresh"
	if inventory.combat_stats != null:
		return "unsupported_equipment_stat_binding"
	if data.inventory.bag.size() > inventory.bag_capacity:
		return "target_bag_capacity"
	if data.player.job_id != "adventurer" and transition._find_job(data.player.job_id) == null:
		return "target_job_unavailable"
	# 모든 데이터/대상 검사 이후에만 변경한다. 레벨업·전직 보상을 발생시키지 않는다.
	progression.current_level = int(data.player.level)
	progression.current_exp = int(data.player.exp)
	transition.restore_saved_job(StringName(data.player.job_id))
	if progression.current_level > 1:
		player.get_node("PlayerStatGrowth").recompute_stats(progression.current_level)
	var levels := {}
	var costs := {}
	for id in data.player.skill_levels:
		var name := StringName(registry.skills[id].skill_name)
		levels[name] = int(data.player.skill_levels[id])
		costs[name] = int(data.player.skill_costs[id])
	points.restore_saved_points(
		int(data.player.skill_points), int(data.player.spent_points), levels, costs
	)
	for entry in data.inventory.bag:
		inventory.bag.append(
			{"item": registry.items[entry.item_id], "quantity": int(entry.quantity)}
		)
	for slot in registry.slots:
		var id: String = data.inventory.equipment[slot]
		if id.is_empty():
			continue
		if slot in ["ring_1", "ring_2"]:
			inventory.equipped_rings[1 if slot == "ring_2" else 0] = registry.items[id]
		else:
			inventory.equipped_items[registry.slots[slot]] = registry.items[id]
	inventory.gold = int(data.inventory.gold)
	var stats = player.get_node("PlayerStats")
	stats.current_hp = float(data.player.hp)
	stats.current_mp = float(data.player.mp)
	player.position = Vector2(data.world.position[0], data.world.position[1])
	player.set_meta("save_restored", true)
	GameClock.restore_saved_time(
		int(data.world.day_number), float(data.world.elapsed_real_sec_in_day)
	)
	progression.exp_changed.emit(progression.current_exp, progression.exp_to_next())
	points.points_changed.emit(points.available_points, points.spent_points)
	stats.hp_changed.emit(stats.current_hp, stats.stats.max_hp)
	stats.mp_changed.emit(stats.current_mp, stats.stats.max_mp)
	inventory.gold_changed.emit(inventory.gold)
	transition.job_changed.emit(transition.current_job_id)
	return ""
