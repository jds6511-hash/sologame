## 디렉터 상점 체험 전용 준비 fixture. 정상 의뢰 완주 증거가 아니다.
extends SceneTree

const SAVE_ROOT := "user://m6_candidate_shop_play"


func _initialize() -> void:
	start.call_deferred()


func start() -> void:
	var world = load("res://scripts/economy/economy_environment.gd").instantiate_world(
		"novera_gate"
	)
	world.set_meta("save_directory", SAVE_ROOT)
	root.add_child(world)
	current_scene = world
	var session = world.get_node("SaveSession")
	if not session.account_error.is_empty():
		push_error("상점 테스트 계정 확인 실패: " + session.account_error)
		quit(1)
		return
	var player = world.get_node("Player")
	var journal = player.get_meta("quest_journal")
	var quests := {}
	for id in journal.catalog.definitions:
		quests[id] = {
			"state": "completed",
			"counts": journal.catalog.definitions[id].objective_counts.duplicate()
		}
	if journal.restore_state(quests) != "":
		push_error("상점 테스트 의뢰 준비 실패")
		quit(1)
		return
	world.get_node("Hud/DebugLevelKeys").grant_levels(9)
	player.get_node("Inventory").add_gold(10000)
	player.position = Vector2(184, 456)
	for child in world.get_node("EconomyPanel").get_children():
		if child is Label:
			child.text = (
				"상점 바로 테스트 · Lv10 / 10,000골드\n[B] 가방 · [V] 전직 · [F6] 별도 저장"
				+ "\n재실행은 새 준비 상태, 저장 진행은 F6 불러오기"
			)
	for tick in range(8):
		await physics_frame
	# 실제 F 액션을 통해 근접 선택·상점·pause 중재를 연다.
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	if not world.get_node("EconomyPanel").panel.visible:
		push_error("상점 테스트 거래창 열기 실패")
		quit(1)
		return
	if player.get_node("Inventory").gold != 10000 or session.store.root != SAVE_ROOT:
		push_error("상점 테스트 자금/저장 격리 확인 실패")
		quit(1)
		return
	print("M6_SHOP_READY: 노베라 거래창 / Lv10 / 10000골드 / 별도 저장")
