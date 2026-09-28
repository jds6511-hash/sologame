extends GutTest

const WORLD = preload("res://scenes/world/eastern_frontier_starting_area.tscn")
const NPC := "yeoulmok_receptionist"
var world: Node
var player: PlayerController
var quests: QuestController
var site: Node2D
var selector: Node


func before_each() -> void:
	world = WORLD.instantiate()
	world.set_meta("save_directory", "user://m5_fourth_test_%d" % Time.get_ticks_usec())
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	player = world.get_node("Player")
	quests = world.get_node("QuestController")
	site = world.get_node("RiftInvestigation")
	selector = world.get_node("WorldInteraction")
	selector.process_mode = Node.PROCESS_MODE_DISABLED
	assert_eq(quests.journal.restore_state(_previous()), "")
	assert_eq(quests.journal.accept("MQ-01-04"), "")


func after_each() -> void:
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()
	var directory: String = world.get_meta("save_directory")
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(file))
		DirAccess.remove_absolute(directory)


func _previous() -> Dictionary:
	return {
		"MQ-01-01": {"state": "completed", "counts": [1, 1]},
		"MQ-01-02": {"state": "completed", "counts": [2]},
		"MQ-01-03": {"state": "completed", "counts": [2]}
	}


func _arrive() -> void:
	player.global_position = site.reach_position
	selector.refresh()
	assert_eq(quests.journal.export_state()["MQ-01-04"].counts, [1, 0])


func test_investigation_markers_outside_initial_slime_perception() -> void:
	var spawns = world.get_node("Markers/MonsterSpawns_균열점액")
	var stats = load("res://data/monsters/slime_stats.tres")
	var radius: float = stats.tiles_to_px(stats.perception_range_tiles)
	for marker in spawns.get_children():
		assert_gt(site.reach_position.distance_to(marker.global_position), radius + 32.0)
		assert_gt(site.global_position.distance_to(marker.global_position), radius + 40.0)
	assert_gte(site.reach_position.distance_to(Vector2(152, 440)), 15.0 * 16.0)


func test_interaction_follows_definition_instead_of_fixed_count_layout() -> void:
	var definition = quests.journal.catalog.definitions["MQ-01-04"].duplicate(true)
	definition.objective_counts[0] = 2
	quests.journal.catalog.definitions["MQ-01-04"] = definition
	player.global_position = site.reach_position
	site.update_target()
	assert_false(site.can_interact())
	site.update_target()
	assert_true(site.can_interact(), "REACH 2회 정의에서도 다음 조사 목표를 조회")


func test_actual_world_arrival_input_report_and_duplicate_reward() -> void:
	_arrive()
	assert_same(selector.selected, site)
	assert_true(player.get_meta("world_interaction_available"))
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	selector._unhandled_input(event)
	assert_eq(quests.journal.export_state()["MQ-01-04"].counts, [1, 1])
	assert_false(selector.interact())
	var inv = player.get_node("Inventory")
	var progression = player.get_node("PlayerProgression")
	watch_signals(progression)
	assert_eq(quests.report("MQ-01-04", "wrong"), "wrong_npc")
	var gold: int = inv.gold
	assert_eq(quests.report("MQ-01-04", NPC), "")
	assert_eq(inv.gold, gold + 300)
	assert_eq(progression.current_level, 4)
	assert_eq(progression.current_exp, 489)  # 1040 - (25 + 140 + 386)
	assert_eq(quests.report("MQ-01-04", NPC), "quest_not_ready")
	assert_eq(inv.gold, gold + 300)


func test_action_lock_distance_pause_and_dead_guards() -> void:
	_arrive()
	player.is_dashing = true
	assert_false(selector.interact())
	player.is_dashing = false
	player.attack_state = PlayerController.AttackState.ACTIVE
	assert_false(selector.interact())
	player.attack_state = PlayerController.AttackState.NONE
	player.global_position = site.global_position + Vector2(41, 0)
	assert_false(selector.interact())
	player.global_position = site.reach_position
	get_tree().paused = true
	selector.refresh()
	assert_false(player.get_meta("world_interaction_available"))
	get_tree().paused = false
	player.get_node("PlayerStats").current_hp = 0
	assert_false(selector.interact())


func test_npc_priority_prompt_ownership_and_item_poll_guard() -> void:
	_arrive()
	var npc = world.get_node("QuestReceptionist")
	npc.global_position = player.global_position + Vector2(0, 8)
	selector.refresh()
	assert_same(selector.selected, npc)
	var hud = world.get_node("Hud")
	assert_same(hud._interaction_owner, selector)
	hud.hide_interaction_prompt()  # 튜토리얼은 조사 소유 프롬프트를 지우지 못한다.
	assert_same(hud._interaction_owner, selector)
	npc.global_position += Vector2(500, 0)
	selector.refresh()
	assert_same(selector.selected, site)
	var item := WorldItem.new()
	add_child_autofree(item)
	item._nearby_inventory = player.get_node("Inventory")
	assert_false(item._pickup_available())
	assert_true(selector.interact())
	assert_false(player.get_meta("world_interaction_available"))
	assert_false(item._pickup_available(), "조사 완료 프레임의 폴링 줍기 억제")
	await wait_process_frames(3)
	assert_true(item._pickup_available())


func test_deleted_target_clears_selection_and_prompt() -> void:
	_arrive()
	site.queue_free()
	selector.refresh()
	assert_null(selector.selected)
	assert_false(player.get_meta("world_interaction_available"))
	assert_null(world.get_node("Hud")._interaction_owner)


func test_wall_blocks_reach_and_investigation() -> void:
	player.global_position = site.reach_position + Vector2(0, -24)
	var wall := StaticBody2D.new()
	wall.process_mode = Node.PROCESS_MODE_ALWAYS
	wall.position = site.reach_position + Vector2(0, -12)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(80, 4)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	await wait_physics_frames(2)
	selector.refresh()
	assert_eq(quests.journal.export_state()["MQ-01-04"].counts, [0, 0])
	quests.journal.record_event("REACH", "yeoulmok_old_rift_entrance", site.SOURCE, 0)
	assert_false(selector.interact())
