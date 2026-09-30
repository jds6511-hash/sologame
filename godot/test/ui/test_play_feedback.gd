extends GutTest

const WORLD = preload("res://scenes/world/eastern_frontier_starting_area.tscn")
var world: Node


func before_each() -> void:
	world = WORLD.instantiate()
	world.set_meta("save_directory", "user://play_feedback_test_%d" % Time.get_ticks_usec())
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	await wait_process_frames(8)


func after_each() -> void:
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()


func test_save_completion_is_temporary_bottom_toast() -> void:
	var menu = world.get_node("SaveMenu")
	menu._show_status("자동 저장 완료 · 슬롯 1")
	assert_false(menu.badge.text.contains("완료"))
	assert_true(menu.has_method("_process"))
	if not menu.has_method("_process"):
		return
	assert_true(menu.toast.visible)
	assert_gt(menu.toast.position.y, 800.0)
	menu._process(4.1)
	assert_false(menu.toast.visible)


func test_pickup_label_uses_world_scale() -> void:
	var drop = load("res://scenes/items/world_item.tscn").instantiate()
	add_child_autofree(drop)
	assert_lte(drop.get_node("PickupPrompt").get_theme_font_size("font_size"), 9)


func test_travel_can_ignore_walking_but_not_attack_or_cooldown() -> void:
	var player = world.get_node("Player")
	assert_true(player.has_method("travel_block_reason"))
	if not player.has_method("travel_block_reason"):
		return
	player.velocity = Vector2(50, 0)
	assert_eq(player.save_block_reason(), "moving")
	assert_eq(player.travel_block_reason(), "")
	player.attack_state = PlayerController.AttackState.STARTUP
	assert_eq(player.travel_block_reason(), "action_in_progress")
	player.attack_state = PlayerController.AttackState.NONE
	player._dash_recharge_timers.append(1.0)
	assert_eq(player.travel_block_reason(), "cooldown_or_buff")


func test_map_and_settings_are_available() -> void:
	var menu = world.get_node("IntegratedMenu")
	assert_true(menu.has_method("open_settings"))
	assert_true(menu.get_node("Tabs/MapTab").has_method("bind_world"))
	menu.open_settings()
	assert_eq(menu.get_node("Tabs").current_tab, 6)
	assert_true(menu.has_node("QuitConfirmation"))
	menu.get_node("QuitConfirmation").popup_centered()
	menu.close_menu()
	assert_false(menu.get_node("QuitConfirmation").visible)
	assert_false(get_tree().paused)


func test_archer_range_and_job_skill_labels() -> void:
	assert_gte(load("res://data/player/arrows/arrow_basic.tres").range_tiles, 8.0)
	var player = world.get_node("Player")
	world.get_node("Hud/DebugLevelKeys").grant_levels(9)
	player.get_node("PlayerJobTransition").perform_transition(&"archer")
	var bar = world.get_node("Hud/SkillSlotBar")
	assert_true(bar.get_node("Slot4").tooltip_text.contains(player.skill_slot_4.skill_name))
	assert_eq(
		bar.get_node("Slot4/Icon").texture.resource_path,
		"res://assets/icons/skills/skill_rapid_shot.png"
	)


func test_navigation_follows_objective_then_report_without_mutation() -> void:
	var navigation = load("res://scripts/quests/quest_navigation.gd")
	var journal = world.get_node("QuestController").journal
	var states := {}
	for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03"]:
		states[id] = {
			"state": "completed",
			"counts": journal.catalog.definitions[id].objective_counts.duplicate()
		}
	states["MQ-01-04"] = {"state": "active", "counts": [0, 0]}
	assert_eq(journal.restore_state(states), "")
	var targets: Array = navigation.targets(world)
	assert_eq(targets[0].position, world.get_node("RiftInvestigation").reach_position)
	assert_eq(journal.export_state(), states)
	states["MQ-01-04"] = {"state": "ready", "counts": [1, 1]}
	assert_eq(journal.restore_state(states), "")
	targets = navigation.targets(world)
	assert_eq(targets[0].position, world.get_node("QuestReceptionist").global_position)
	assert_true(targets[0].label.begins_with("보고"))
