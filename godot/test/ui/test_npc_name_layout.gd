extends GutTest


func test_long_names_remain_centered_and_prompt_stays_above() -> void:
	var npc = load("res://scenes/npc/quest_receptionist.tscn").instantiate()
	add_child_autofree(npc)
	var label: Label = npc.get_node("Name")
	for text in ["접수원", "여울목 관문지기", "노베라 통행 안내인", "아주 긴 이름을 가진 왕국의 순회 접수원"]:
		label.text = text
		await get_tree().process_frame
		assert_almost_eq(label.position.x + label.size.x / 2.0, 0.0, 0.01)
		assert_almost_eq(npc.interaction_prompt_position().x, npc.global_position.x, 0.01)
		assert_lte(npc.interaction_prompt_position().y, label.global_position.y)
