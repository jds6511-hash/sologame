## 후보 거래→실착→파일 저장→별도 프로세스 복원. 준비용 골드/의뢰 fixture는 명시한다.
extends SceneTree

const DIR := "user://m6_candidate_process"
const ENV_PATH := "res://scripts/economy/economy_environment.gd"
var failed := false
var finished := false
var world: Node


func _initialize() -> void:
	if OS.get_cmdline_user_args() != PackedStringArray(["play"]):
		create_timer(60).timeout.connect(func(): quit(1))
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(label, ": ", value)
	failed = failed or not value


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "seed", "reload", "play"]:
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(DIR):
			for file in DirAccess.get_files_at(DIR):
				check(DirAccess.remove_absolute(DIR.path_join(file)) == OK, "격리 파일 정리")
		finished = true
	elif args[0] == "seed":
		await seed_save()
	elif args[0] == "reload":
		await reload_save()
	else:
		world = load(ENV_PATH).instantiate_world()
		world.set_meta("save_directory", "user://m6_candidate_play")
		root.add_child(world)
		current_scene = world
		print("M6_CANDIDATE_READY: B 가방 / 노베라 보급상 F 거래")
		return
	check(finished, "최종 검사 도달")
	if is_instance_valid(world):
		world.free()
	var bgm := root.get_node_or_null("BgmManager")
	if bgm != null:
		bgm.reset()
	await process_frame
	print("M6_CANDIDATE_FAIL" if failed else "M6_CANDIDATE_PASS")
	quit(1 if failed else 0)


func seed_save() -> void:
	var env = load(ENV_PATH)
	world = env.instantiate_world("novera_gate")
	world.set_meta("save_directory", DIR)
	root.add_child(world)
	current_scene = world
	var player = world.get_node("Player")
	var economy = player.get_meta("economy_candidate")
	# 이 probe는 경제 경로만 검사한다. MQ01~05 완료와 초기 자금은 준비 fixture다.
	var journal = player.get_meta("quest_journal")
	var quests := {}
	for id in journal.catalog.definitions:
		var counts := []
		for count in journal.catalog.definitions[id].objective_counts:
			counts.append(count)
		quests[id] = {"state": "completed", "counts": counts}
	check(journal.restore_state(quests) == "", "완료 의뢰 준비 fixture")
	player.get_node("Inventory").add_gold(1000)
	# 실제 컨트롤러 이동. 근접 이후 F가 상점 pause 중재로 연결된다.
	for tick in range(240):
		if player.position.x >= 184:
			break
		Input.action_press("move_right")
		await physics_frame
	Input.action_release("move_right")
	await create_timer(0.25).timeout
	check(player.position.distance_to(Vector2(216, 440)) <= 40, "상인 도보 접근")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	check(world.get_node("EconomyPanel").panel.visible and paused, "F 거래창 열기")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(
			(
				root.get_texture().get_image().save_png("res://../docs/qa/screenshots/m6-shop.png")
				== OK
			),
			"거래창 렌더 기록"
		)
	var before_cancel: Dictionary = economy.state()
	check(click_button("구매 300골드"), "포션 구매 선택")
	check(click_button("취소"), "구매 취소")
	check(economy.state() == before_cancel, "취소 시 경제 상태 불변")
	check(click_button("구매 300골드") and click_button("확정"), "포션 구매 확정 버튼")
	check(economy.model.quantity(economy.state().bag, "POT-HP-1") == 1, "포션 구매")
	check(economy.act("buy", "WPN-SW-01-C") == "", "무기 구매")
	var power: float = player.get_node("PlayerStats").stats.attack_power
	check(economy.act("unequip", "", "weapon") == "", "무장 해제")
	check(player.get_node("PlayerStats").stats.attack_power < power, "실제 공격 스탯 감소")
	check(economy.act("equip", "WPN-SW-01-C", "weapon") == "", "실착 복귀")
	check(economy.act("sell", "WPN-SW-01-C") == "", "여분 무기 판매")
	check(player.get_node("Inventory").gold == 592, "명시 구매 판매가 결과")
	world.get_node("EconomyPanel").close()
	await create_timer(6).timeout
	var session = world.get_node("SaveSession")
	var saved: Dictionary = session.save_slot(1)
	print("저장 결과 코드: ", saved.code)
	check(saved.ok, "실제 세션 V5 저장")
	var file := FileAccess.open(DIR.path_join("expected.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(economy.state()))
	file.close()
	finished = true


func click_button(text: String) -> bool:
	for button in world.get_node("EconomyPanel").rows.get_children():
		if button is Button and text in button.text and not button.disabled:
			button.pressed.emit()
			return true
	return false


func reload_save() -> void:
	world = load(ENV_PATH).instantiate_world()
	world.set_meta("save_directory", DIR)
	root.add_child(world)
	current_scene = world
	check(world.get_node("SaveSession").load_slot(1).ok, "별도 프로세스 로드")
	await process_frame
	world = current_scene
	var actual: Dictionary = world.get_node("Player").get_meta("economy_candidate").state()
	var expected: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(DIR.path_join("expected.json"))
	)
	check(JSON.parse_string(JSON.stringify(actual)) == expected, "가방 골드 장비 보관 복원")
	check(world.map_id == "novera_gate", "노베라 복원")
	var actor = world.get_node("Player")
	for tick in range(240):
		if actor.position.x <= 144:
			break
		Input.action_press("move_left")
		await physics_frame
	Input.action_release("move_left")
	await create_timer(5.2).timeout
	check(world.get_node("SaveSession").travel("eastern_frontier_start").ok, "여울목 귀환")
	await process_frame
	world = current_scene
	check(world.get_node("Player").get_meta("economy_candidate").state() == actual, "지역 왕복 장비 불변")
	finished = true
