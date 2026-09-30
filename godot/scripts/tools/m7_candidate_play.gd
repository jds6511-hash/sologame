extends SceneTree


func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var quick := "--quick" in OS.get_cmdline_user_args()
	var region := "novera_gate" if quick else "eastern_frontier_start"
	var world = load("res://scripts/chapter_two/m7_environment.gd").instantiate_world(region)
	world.set_meta(
		"save_directory", "user://m7_candidate_quick_play" if quick else "user://m7_candidate_play"
	)
	root.add_child(world)
	if String(world.get_meta("save_boot_error", "")) != "":
		quit(1)
	else:
		if quick:
			var journal = world.get_node("QuestController").journal
			var preparation := {}
			for id in QuestCatalog.ORDER:
				preparation[id] = {
					"state": "completed",
					"counts": Array(journal.catalog.definitions[id].objective_counts)
				}
			journal.restore_state(preparation)
			world.get_node("Player/PlayerProgression").add_exp(3820)
			world.get_node("Player/Inventory").add_gold(560)
			world.get_node("SaveSession")._report(
				"M7 준비 상태 · 1장 완료/누적 EXP 3820/560골드. 저장한 진행은 F6에서 불러오세요."
			)
		print("M7_PLAY_READY")
