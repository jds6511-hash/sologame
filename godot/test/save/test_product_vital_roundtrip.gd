extends GutTest


func test_full_vitals_survive_json_without_exceeding_original_value() -> void:
	var world = load("res://scripts/world/game_product.gd").instantiate_world()
	world.set_meta("save_directory", "user://product_verify")
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player = world.get_node("Player")
	player.get_node("PlayerProgression").add_exp(79291)
	var stats = player.get_node("PlayerStats")
	stats.current_hp = stats.stats.max_hp
	stats.current_mp = stats.stats.max_mp
	var session = world.get_node("SaveSession")
	var captured: Dictionary = session.codec.capture(player, session.account.account_id)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(captured, "", true, true))
	assert_lte(parsed.player.hp, stats.current_hp)
	assert_lte(parsed.player.mp, stats.current_mp)
	assert_almost_eq(parsed.player.hp, stats.current_hp, 0.000000001)
	assert_eq(session.codec.schema.character_error(parsed, session.account), "")
	world.free()
	BgmManager.reset()
	await get_tree().process_frame
