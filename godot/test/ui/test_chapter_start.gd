extends GutTest


func test_chapter_preparation_is_separate_from_real_saves() -> void:
	var bootstrap = load("res://scripts/world/game_bootstrap.gd").new()
	assert_true(bootstrap.has_method("start_options"), "시작 화면은 기본 저장과 준비 상태를 구분한다")
	if bootstrap.has_method("start_options"):
		var options: Array = bootstrap.start_options()
		assert_eq(options.size(), 4)
		assert_eq(options[0].directory, "user://saves")
		for index in range(1, 4):
			assert_eq(options[index].directory, "user://product_chapter_preview")
			assert_eq(options[index].chapter, index)
	bootstrap.free()


func test_preparation_does_not_turn_third_chapter_into_completed_content() -> void:
	var bootstrap = load("res://scripts/world/game_bootstrap.gd").new()
	assert_true(bootstrap.has_method("preparation"))
	if bootstrap.has_method("preparation"):
		var catalog = load("res://scripts/chapter_two_closure/closure_catalog.gd").new()
		var data: Dictionary = bootstrap.preparation(catalog, 3)
		assert_eq(data.quests.size(), 13)
		assert_eq(data.exp, 42828)
		assert_true(data.quests.has("MQ-02-06"))
		assert_false(data.quests.has("MQ-03-01"))
		assert_eq(bootstrap.preparation(catalog, 2).quests.size(), 5)
		assert_eq(bootstrap.preparation(catalog, 1).quests.size(), 0)
	bootstrap.free()
