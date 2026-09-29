## 격리 시제품의 월드 교체·실제 이동·저장·별도 프로세스 복원 통합 검증.
## 선행 MQ01~04 완료는 fixture다. 그 의뢰들을 실제 플레이했다고 주장하지 않는다.
# gdlint: disable=max-returns
extends "res://../docs/qa/tools/yeoulmok_walk_probe.gd"

const DIRECTORY := "user://yeoulmok_journey_probe"
const LIFECYCLE = preload("res://scripts/tools/yeoulmok_pilot_session.gd")
var finished := false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "depart", "return", "reload"]:
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(DIRECTORY):
			for file in DirAccess.get_files_at(DIRECTORY):
				_check(DirAccess.remove_absolute(DIRECTORY.path_join(file)) == OK, "fixture 삭제")
		finished = true
	else:
		await _phase(args[0])
	_check(finished, "여행 단계 끝까지 실행")
	_release()
	paused = false
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	print("YEOULMOK_JOURNEY_FAIL" if failed else "YEOULMOK_JOURNEY_PASS")
	quit(1 if failed else 0)


func _phase(phase: String) -> void:
	if phase == "depart" and FileAccess.file_exists(DIRECTORY.path_join("character_02.json")):
		_check(false, "기존 fixture 존재: cleanup 먼저 실행")
		return
	root.size = Vector2i(1920, 1080)
	var lifecycle := LIFECYCLE.new()
	lifecycle.save_directory = DIRECTORY
	root.add_child(lifecycle)
	var foreign := Node2D.new()
	foreign.scene_file_path = LIFECYCLE.START_SCENE
	foreign.set_meta("save_directory", "user://다른_저장_경로")
	root.add_child(foreign)
	_check(not foreign.has_node("ArtPilot"), "다른 저장 경로 월드 미적용")
	foreign.free()
	world = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", DIRECTORY)
	root.add_child(world)
	current_scene = world
	await _refresh_world()
	_check(world.has_node("ArtPilot/NativeSurface"), "최초 키트 설치")
	lifecycle.attach(world)
	_check(world.find_children("ArtPilot", "", false, false).size() == 1, "중복 설치 없음")
	var session = world.get_node("SaveSession")
	if phase != "depart":
		var loaded: Dictionary = session.load_slot(1)
		_check(loaded.ok, "이전 프로세스 저장 로드")
		if not loaded.ok:
			return
		await _refresh_world()
		session = world.get_node("SaveSession")
	if phase == "depart":
		if not await _walk(Vector2(152, 520)):
			return
		var journal = world.get_node("QuestController").journal
		var fixture := {}
		for id in ["MQ-01-01", "MQ-01-02", "MQ-01-03", "MQ-01-04"]:
			fixture[id] = {
				"state": "completed",
				"counts": journal.catalog.definitions[id].objective_counts.duplicate()
			}
		_check(journal.restore_state(fixture) == "", "선행 의뢰 fixture")
		_check(journal.accept("MQ-01-05") == "", "MQ05 수락")
		if not await _save(2):
			return
		_write("slot2.sha", FileAccess.get_sha256(DIRECTORY.path_join("character_02.json")))
		for point in [Vector2(200, 520), Vector2(200, 456), Vector2(248, 456)]:
			if not await _walk(point):
				return
		await _dialogue("yeoulmok_gatewarden", "journey-depart")
		_check(completed_dialogues == 1, "관문 대화 검사 완료")
		_check(world.get_node("WorldInteraction").interact(), "보고 대화 재개")
		world.get_node("QuestDialog").choose("report", "MQ-01-05")
		await _refresh_world()
		_check(world.map_id == "novera_gate", "보고 후 노베라 이동")
		if world.map_id != "novera_gate":
			return
		_check(not world.has_node("ArtPilot"), "다른 지역에 여울목 아트 미적용")
		if not await _save(1):
			return
	elif phase == "return":
		_check(world.map_id == "novera_gate", "노베라 저장 복원")
		_check(not world.has_node("ArtPilot"), "노베라 로드 아트 격리")
		# 복원 직후의 제품 전투 정적 5초를 실제 시간으로 기다린다.
		await create_timer(5.1).timeout
		await _dialogue("novera_gatewarden", "journey-novera")
		_check(completed_dialogues == 1, "노베라 대화 검사 완료")
		_check(world.get_node("WorldInteraction").interact(), "귀환 대화 재개")
		world.get_node("QuestDialog").choose("travel", "MQ-01-05")
		await _refresh_world()
		_check(world.map_id == "eastern_frontier_start", "여울목 귀환")
		if world.map_id != "eastern_frontier_start":
			return
		_check(world.has_node("ArtPilot/NativeSurface"), "귀환 키트 유지")
		for point in [Vector2(200, 456), Vector2(200, 520), Vector2(152, 520)]:
			if not await _walk(point):
				return
		if not await _save(1):
			return
		_write("position.json", JSON.stringify([player.position.x, player.position.y]))
	else:
		var expected = JSON.parse_string(
			FileAccess.get_file_as_string(DIRECTORY.path_join("position.json"))
		)
		_check(expected is Array and expected.size() == 2, "이동 위치 fixture")
		if not expected is Array or expected.size() != 2:
			return
		_check(
			player.position.distance_to(Vector2(expected[0], expected[1])) < 0.001,
			"이동 후 위치 프로세스 복원"
		)
		_check(world.has_node("ArtPilot/NativeSurface"), "재실행 로드 키트 유지")
		_check(world.get_node("QuestController").journal.reputation() == 100, "공훈 복원")
		_check(player.get_node("Inventory").gold == 560, "보상 중복 없음")
		var digest := FileAccess.get_sha256(DIRECTORY.path_join("character_01.json"))
		_check(session.new_character().ok, "새 캐릭터")
		await _refresh_world()
		_check(world.has_node("ArtPilot/NativeSurface"), "새 캐릭터 키트 유지")
		_check(
			FileAccess.get_sha256(DIRECTORY.path_join("character_01.json")) == digest,
			"새 캐릭터 기존 슬롯 불변"
		)
	_check(
		(
			FileAccess.get_sha256(DIRECTORY.path_join("character_02.json"))
			== FileAccess.get_file_as_string(DIRECTORY.path_join("slot2.sha"))
		),
		"별도 슬롯 불변"
	)
	_check(world.get_node("SaveSession").store.root == DIRECTORY, "저장 격리 유지")
	finished = true


func _refresh_world() -> void:
	await process_frame
	world = current_scene
	player = world.get_node("Player")
	await physics_frame
	await process_frame


func _save(slot: int) -> bool:
	for attempt in range(20):
		var result: Dictionary = world.get_node("SaveSession").save_slot(slot)
		if result.ok:
			print("안전 조건 충족 저장: ", slot, " 위치 ", player.position)
			return true
		print("저장 대기: ", result.code)
		await create_timer(1.0).timeout
	_check(false, "안전 조건 저장 시간 초과")
	return false


func _write(name: String, text: String) -> void:
	var file := FileAccess.open(DIRECTORY.path_join(name), FileAccess.WRITE)
	_check(file != null, "fixture 기록")
	if file != null:
		file.store_string(text)
