extends GutTest

const JOURNAL_PATH := "res://scripts/quests/quest_journal.gd"
const CONTROLLER_PATH := "res://scripts/quests/quest_controller.gd"
const Catalog = preload("res://scripts/quests/quest_catalog.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
var journal: RefCounted
var controller: Node
var player: Node


func before_each() -> void:
	if not ResourceLoader.exists(JOURNAL_PATH) or not ResourceLoader.exists(CONTROLLER_PATH):
		return
	journal = load(JOURNAL_PATH).new(Catalog.new())
	player = PLAYER.instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	controller = load(CONTROLLER_PATH).new()
	add_child_autofree(controller)
	controller.setup(player, journal)
	journal.accept("MQ-01-01")


func _available() -> bool:
	assert_not_null(journal, "QuestJournal and QuestController must exist")
	return journal != null


func _first_ready() -> void:
	journal.record_event("REACH", "yeoulmok_receptionist", "", 0)
	journal.record_event("TALK", "yeoulmok_receptionist", "", 0)


func _second_ready() -> void:
	_first_ready()
	assert_eq(controller.report("MQ-01-01", "yeoulmok_receptionist"), "")
	assert_eq(journal.accept("MQ-01-02"), "")
	journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 100)
	journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 101)


func test_order_explicit_claim_and_no_repeated_rewards() -> void:
	if not _available():
		return
	journal.record_event("TALK", "yeoulmok_receptionist", "", 0)
	assert_eq(journal.export_state()["MQ-01-01"].counts, [0, 0])
	journal.record_event("REACH", "yeoulmok_receptionist", "", 0)
	assert_eq(journal.export_state()["MQ-01-01"].counts, [1, 0])
	_first_ready()
	assert_eq(player.get_node("Inventory").gold, 0)
	assert_eq(controller.report("MQ-01-01", "wrong_npc"), "wrong_npc")
	assert_eq(controller.report("MQ-01-01", "yeoulmok_receptionist"), "")
	assert_eq(player.get_node("Inventory").gold, 20)
	assert_eq(controller.report("MQ-01-01", "yeoulmok_receptionist"), "quest_not_ready")
	assert_eq(player.get_node("Inventory").gold, 20)
	assert_false(journal.export_state().has("MQ-01-02"))


func test_no_retroactive_kills_wrong_source_or_duplicate_token() -> void:
	if not _available():
		return
	journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 1)
	_first_ready()
	controller.report("MQ-01-01", "yeoulmok_receptionist")
	journal.accept("MQ-01-02")
	journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 1)
	journal.record_event("KILL", "horned_rabbit", "other", 2)
	journal.record_event("KILL", "wolf", "yeoulmok_rabbit_habitat", 3)
	assert_eq(journal.export_state()["MQ-01-02"].counts, [0])
	journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 4)
	journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 4)
	assert_eq(journal.export_state()["MQ-01-02"].counts, [1])


func test_full_bag_is_atomic_but_existing_stack_accepts_reward() -> void:
	if not _available():
		return
	_second_ready()
	var inventory = player.get_node("Inventory")
	var progression = player.get_node("PlayerProgression")
	inventory.bag_capacity = 0
	var before := [inventory.gold, progression.current_level, progression.current_exp]
	assert_eq(controller.report("MQ-01-02", "yeoulmok_receptionist"), "inventory_full")
	assert_eq([inventory.gold, progression.current_level, progression.current_exp], before)
	assert_eq(journal.export_state()["MQ-01-02"].state, "ready")
	inventory.bag_capacity = 1
	inventory.add_to_bag(controller.registry.items["POT-HP-1"], 1)
	assert_eq(controller.report("MQ-01-02", "yeoulmok_receptionist"), "")
	assert_eq(inventory.get_bag_quantity("POT-HP-1"), 3)
	assert_eq(inventory.gold, 120)
	var earned: int = progression.current_exp
	for level in range(1, progression.current_level):
		earned += progression.level_curve.req(level)
	assert_eq(earned, 400, "75 + 325 quest EXP without kill rewards")


func test_reward_reentry_is_blocked_until_all_state_is_committed() -> void:
	if not _available():
		return
	_second_ready()
	var results := []
	player.get_node("Inventory").gold_changed.connect(
		func(_gold):
			results.append(controller.is_reward_busy())
			results.append(controller.report("MQ-01-02", "yeoulmok_receptionist"))
	)
	assert_eq(controller.report("MQ-01-02", "yeoulmok_receptionist"), "")
	assert_eq(results, [true, "reward_busy"])
	assert_eq(journal.export_state()["MQ-01-02"].state, "completed")
	assert_false(controller.is_reward_busy())


func test_restore_is_validated_copied_and_definitions_unchanged() -> void:
	if not _available():
		return
	_second_ready()
	var state: Dictionary = journal.export_state()
	var other = load(JOURNAL_PATH).new(journal.catalog)
	assert_eq(other.restore_state(state), "")
	state["MQ-01-02"].counts[0] = -1
	assert_eq(other.export_state()["MQ-01-02"].counts, [2])
	assert_ne(other.restore_state(state), "")
	controller.report("MQ-01-02", "yeoulmok_receptionist")
	assert_eq(other.export_state()["MQ-01-02"].state, "ready")
	assert_eq(journal.catalog.definitions["MQ-01-02"].objective_counts, [2])
	assert_eq(journal.catalog.definitions["MQ-01-02"].reward_item_count, 2)


func test_json_restore_counts_continue_and_reward_overflow_is_atomic() -> void:
	if not _available():
		return
	_second_ready()
	var state: Dictionary = JSON.parse_string(JSON.stringify(journal.export_state()))
	state["MQ-01-02"] = {"state": "active", "counts": [1.0]}
	assert_eq(journal.restore_state(state), "")
	journal.record_event("KILL", "horned_rabbit", "yeoulmok_rabbit_habitat", 500)
	assert_eq(journal.export_state()["MQ-01-02"].state, "ready")
	var inventory = player.get_node("Inventory")
	inventory.gold = 2147483647
	assert_eq(controller.report("MQ-01-02", "yeoulmok_receptionist"), "reward_overflow")
	assert_eq(inventory.get_bag_quantity("POT-HP-1"), 0)
	assert_eq(journal.export_state()["MQ-01-02"].state, "ready")
