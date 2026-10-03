extends GutTest

const Product = preload("res://scripts/world/game_product.gd")
const View = preload("res://scripts/quests/quest_journal_view.gd")
var world: Node
var controller: QuestController
var journal: QuestJournal
var _token := 1000


func before_each() -> void:
	world = Product.instantiate_world("gransia")
	world.set_meta("save_directory", "user://product_verify")
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	controller = world.get_node("QuestController")
	journal = controller.journal
	var states := {}
	for id in journal.catalog.ordered_ids():
		if id.begins_with("MQ-"):
			states[id] = {
				"state": "completed",
				"counts": Array(journal.catalog.definitions[id].objective_counts)
			}
	assert_eq(journal.restore_state(states), "")


func after_each() -> void:
	get_tree().paused = false
	BgmManager.reset()
	GameClock.reset()


func make_ready(id: String) -> void:
	assert_eq(journal.accept(id), "")
	var quest: QuestData = journal.catalog.definitions[id]
	for index in quest.objective_counts.size():
		for count in quest.objective_counts[index]:
			_token += 1
			journal.record_event(
				quest.objective_kinds[index],
				quest.objective_targets[index],
				quest.objective_sources[index],
				_token
			)


func test_all_22_side_rewards_use_normal_completion_once() -> void:
	var count := 0
	var inventory = world.get_node("Player/Inventory")
	for id in journal.catalog.ordered_ids():
		if not journal.catalog.allows_field_report(id):
			continue
		count += 1
		assert_eq(controller.report_from_journal(id), "quest_not_ready")
		make_ready(id)
		var before: int = inventory.gold
		assert_eq(controller.report_from_journal(id), "")
		assert_eq(inventory.gold, before + journal.catalog.definitions[id].reward_gold)
		assert_eq(journal.export_state()[id].state, "completed")
		assert_eq(controller.report_from_journal(id), "quest_not_ready")
		assert_eq(inventory.gold, before + journal.catalog.definitions[id].reward_gold)
		var restored := QuestJournal.new(journal.catalog)
		assert_eq(restored.restore_state(journal.export_state()), "")
	assert_eq(count, 35)


func test_main_unknown_and_death_cannot_claim() -> void:
	assert_eq(controller.report_from_journal("MQ-04-01"), "field_report_unavailable")
	assert_eq(controller.report_from_journal("SQ-unknown"), "field_report_unavailable")
	make_ready("SQ-CH04-001")
	world.get_node("Player/PlayerStats").current_hp = 0.0
	var before := journal.export_state()
	assert_eq(controller.report_from_journal("SQ-CH04-001"), "player_dead")
	assert_eq(journal.export_state(), before)


func test_journal_button_claims_and_duplicate_click_does_nothing() -> void:
	make_ready("SQ-CH04-001")
	make_ready("SQ-CH04-002")
	var tab = world.get_node("IntegratedMenu/Tabs/JournalTab")
	tab.set_filter("ready")
	tab.select_quest("SQ-CH04-001")
	assert_true(tab._report_button.visible)
	assert_string_contains(
		View.detail(journal.catalog, journal.export_state(), "SQ-CH04-001").next_action, "돌아가지 않아도"
	)
	tab._report_button.pressed.emit()
	assert_eq(journal.export_state()["SQ-CH04-001"].state, "completed")
	var gold: int = world.get_node("Player/Inventory").gold
	tab._report_button.pressed.emit()
	assert_eq(world.get_node("Player/Inventory").gold, gold)
	assert_eq(journal.export_state()["SQ-CH04-002"].state, "ready", "두 번째 클릭이 다음 의뢰까지 제출하지 않음")
