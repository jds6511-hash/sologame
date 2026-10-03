extends GutTest
const Safety = preload("res://scripts/save/save_safety.gd")


class EncounterStub:
	extends Node
	var active := true


func test_active_encounter_blocks_save_even_without_nearby_enemies() -> void:
	var world := Node.new()
	var encounter := EncounterStub.new()
	encounter.name = "EncounterController"
	world.add_child(encounter)
	assert_eq(Safety.blocked_reason(world), "encounter_active")
	encounter.active = false
	assert_eq(Safety.blocked_reason(world), "unsupported_world")
	world.free()


func test_ninth_preparation_is_available_and_separate() -> void:
	var bootstrap = load("res://scripts/world/game_bootstrap.gd").new()
	var options: Array = bootstrap.start_options()
	assert_eq(options.size(), 10)
	if options.size() == 10:
		assert_eq(options[9].directory, "user://product_chapter_preview")
		assert_eq(bootstrap.start_region(9), "jaetgol")
	bootstrap.free()
