extends GutTest
const Product = preload("res://scripts/world/game_product.gd")
const Content = preload("res://scripts/content/game_content.gd")
const Territory = preload("res://scripts/territory/territory_model.gd")
const Save = preload("res://scripts/save/product_save.gd")
var world: Node
var controller: QuestController
var actor: Node2D


func before_each() -> void:
	world = Product.instantiate_world("brantel")
	world.set_meta("save_directory", "user://product_verify")
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	actor = world.get_node("Player")
	controller = world.get_node("QuestController")
	var states := {}
	for id in controller.journal.catalog.ordered_ids():
		if id == "MQ-08-04":
			break
		if id.begins_with("TR-"):
			continue
		states[id] = {
			"state": "completed",
			"counts": Array(controller.journal.catalog.definitions[id].objective_counts)
		}
	assert_eq(controller.journal.restore_state(states), "")
	assert_true(controller.journal.catalog.definitions.has("MQ-08-04"))
	if not controller.journal.catalog.definitions.has("MQ-08-04"):
		return
	assert_eq(controller.accept("MQ-08-04"), "")
	var quest: QuestData = controller.journal.catalog.definitions["MQ-08-04"]
	var token := 1
	for index in quest.objective_counts.size():
		for count in quest.objective_counts[index]:
			token += 1
			controller.journal.record_event(
				quest.objective_kinds[index], quest.objective_targets[index],
				quest.objective_sources[index], token
			)
	actor.position = Content.NPCS.brantel_herald[1] + Vector2(0, 20)
	Territory.advance(world.get_meta("territory_state"), 1234)


func after_each() -> void:
	BgmManager.reset()
	GameClock.reset()
	get_tree().paused = false


func test_ceremony_rejects_distance_death_and_bad_state_without_rewards() -> void:
	var inventory = actor.get_node("Inventory")
	var before: int = inventory.gold
	actor.position += Vector2(100, 0)
	assert_eq(controller.report("MQ-08-04", "brantel_herald"), "ceremony_onsite")
	actor.position = Content.NPCS.brantel_herald[1] + Vector2(0, 20)
	actor.get_node("PlayerStats").current_hp = 0.0
	assert_eq(controller.report("MQ-08-04", "brantel_herald"), "player_unavailable")
	actor.get_node("PlayerStats").current_hp = 1.0
	world.get_meta("territory_state").treasury = -1
	assert_eq(controller.report("MQ-08-04", "brantel_herald"), "territory_counter")
	assert_eq(inventory.gold, before)
	assert_eq(controller.journal.export_state()["MQ-08-04"].state, "ready")


func test_grant_reward_and_save_are_consistent_and_repeated_report_is_rejected() -> void:
	var before: Dictionary = world.get_meta("territory_state").duplicate(true)
	var gold: int = actor.get_node("Inventory").gold
	assert_eq(controller.report("MQ-08-04", "brantel_herald"), "")
	var state: Dictionary = world.get_meta("territory_state")
	assert_eq(state.representative, "jaetgol")
	assert_eq(state.holdings.yeoulmok, before.holdings.yeoulmok)
	assert_eq(state.order, before.order)
	assert_eq(state.day_ms, before.day_ms)
	assert_eq(actor.get_node("Inventory").gold, gold + 55000)
	assert_eq(controller.report("MQ-08-04", "brantel_herald"), "quest_not_ready")
	assert_eq(actor.get_node("Inventory").gold, gold + 55000)
	var codec = Save.Codec.new()
	var account: Dictionary = world.get_node("SaveSession").account
	var snapshot: Dictionary = codec.capture(actor, account.account_id)
	assert_eq(codec.schema.character_error(snapshot, account), "")
	snapshot.content_revision = 6
	assert_eq(codec.schema.character_error(snapshot, account), "unsupported_content")
	snapshot.content_revision = 7
	snapshot.progress.quests.erase("MQ-08-04")
	assert_ne(codec.schema.character_error(snapshot, account), "")
