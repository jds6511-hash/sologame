## QA 도구 자체의 실패 감시 검사. 정상 완주와 분리된 명시적 결함 주입이다.
extends "res://../docs/qa/tools/yeoulmok_onboarding_probe.gd"


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["walk", "hunt", "reload", "death"]:
		quit(2)
		return
	var kind: String = args[0]
	if kind == "death":
		world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
		world.set_meta("save_directory", SAVE_ROOT)
		root.add_child(world)
		current_scene = world
		await _refresh_world()
		# 대기 중 실제 사망/부활을 유발한다. 정상 완주 probe에서는 사용하지 않는다.
		player.get_node("PlayerStats").take_damage(100000.0)
		await create_timer(5.1).timeout
		var detected: bool = failed and not player.get_node("PlayerStats").is_dead()
		print("ONBOARDING_DEATH_GUARD: ", detected)
		if not detected:
			quit(1)
			return
	else:
		_check(false, "음성 검사 이전 실패 주입")
		navigation_disabled = kind == "walk"
		defense_enabled = false
		await _play({"walk": "walk_blocked", "hunt": "blocked", "reload": "reload"}[kind])
	_release()
	paused = false
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	print("ONBOARDING_GUARD_PROBE_DONE")
	quit(0)
