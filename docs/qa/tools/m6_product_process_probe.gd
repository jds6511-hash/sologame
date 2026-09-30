## 파일 이관 전용 fixture. 실제 사용자 저장과 정상 완주 증거를 사용하지 않는다.
extends SceneTree

const PRODUCT_PATH := "res://scripts/economy/economy_product.gd"
const LegacyStore = preload("res://scripts/save/save_file_store.gd")
const ROOT := "user://m6_product_process"
var failed := false
var finished := false
var world: Node


func _initialize() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	failed = failed or not value
	print(label, ": ", value)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "seed", "migrate", "verify", "preview"]:
		quit(2)
		return
	match args[0]:
		"cleanup":
			if DirAccess.dir_exists_absolute(ROOT):
				for file in DirAccess.get_files_at(ROOT):
					_check(DirAccess.remove_absolute(ROOT.path_join(file)) == OK, "전용 fixture 정리")
			finished = true
		"seed":
			_seed()
		"migrate":
			await _migrate()
		"verify":
			await _verify()
		"preview":
			await _preview()
	_check(finished, "단계 마지막 검사 도달")
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("M6_PRODUCT_PROCESS_FAIL" if failed else "M6_PRODUCT_PROCESS_PASS")
	quit(1 if failed else 0)


func _attach(next: Node) -> void:
	world = next
	world.set_meta("save_directory", ROOT)
	root.add_child(world)
	current_scene = world
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_check(world.get_meta("save_boot_error", "") == "", "세션 초기화")


func _seed() -> void:
	_attach(load("res://scenes/world/novera_gate.tscn").instantiate())
	var session = world.get_node("SaveSession")
	var actor = world.get_node("Player")
	var progression = actor.get_node("PlayerProgression")
	while progression.current_level < 10:
		progression.add_exp(progression.exp_to_next())
	_check(actor.get_node("PlayerJobTransition").perform_transition(&"warrior"), "V4 전사 fixture")
	var journal = world.get_node("QuestController").journal
	var quests := {}
	for id in journal.catalog.ordered_ids():
		quests[id] = {
			"state": "completed", "counts": Array(journal.catalog.definitions[id].objective_counts)
		}
	_check(journal.restore_state(quests) == "", "V4 완료 의뢰 fixture")
	actor.get_node("Inventory").add_gold(1234)
	actor.get_node("Inventory").add_to_bag(session.codec.registry.items["POT-HP-1"], 3)
	var data: Dictionary = session.codec.capture(actor, session.account.account_id)
	_check(data.character_save_version == 4, "구버전 원본 생성")
	_check(session.store.write_save("account", 0, session.account).ok, "V4 계정 기록")
	_check(session.store.write_save("character", 1, data).ok, "V4 캐릭터 기록")
	_write("source_hash.txt", FileAccess.get_sha256(ROOT.path_join("character_01.json")))
	finished = true


func _load_product() -> void:
	_attach(load(PRODUCT_PATH).instantiate_world())
	_check(world.get_node("SaveSession").load_slot(1).ok, "제품 불러오기 API")
	await process_frame
	await process_frame
	world = current_scene
	world.process_mode = Node.PROCESS_MODE_DISABLED


func _migrate() -> void:
	await _load_product()
	var session = world.get_node("SaveSession")
	var source_hash := FileAccess.get_file_as_string(ROOT.path_join("source_hash.txt"))
	_check(session.migration_pending and session.loaded_source_version == 4, "V4 메모리 이관 대기")
	_check(session.character.character_save_version == 5, "V5 메모리 이관")
	session.advance(181)
	_check(
		FileAccess.get_sha256(ROOT.path_join("character_01.json")) == source_hash,
		"로드·자동저장 대기 동안 원본 불변"
	)
	world.process_mode = Node.PROCESS_MODE_INHERIT
	await create_timer(5.1).timeout
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var saved: Dictionary = session.save_slot(1)
	print("명시 저장 코드: ", saved.code)
	_check(saved.ok, "명시 저장으로 V5 확정")
	_check(not session.migration_pending, "명시 저장 후 이관 대기 해제")
	_check(
		FileAccess.get_sha256(ROOT.path_join("character_01.json.bak")) == source_hash, "V4 원본 백업 보존"
	)
	_check(
		LegacyStore.new(ROOT).read_save("character", 1).code == "unsupported_version",
		"V4 독자가 V5 파일 거부"
	)
	_write("expected.json", JSON.stringify(session.character))
	var digest := FileAccess.get_sha256(ROOT.path_join("character_01.json"))
	for destination in ["eastern_frontier_start", "novera_gate"]:
		session = world.get_node("SaveSession")
		world.get_node("Player").position = session._departure(destination)
		_check(session.travel(destination).ok, "준비 좌표에서 제품 지역 교체 " + destination)
		await process_frame
		await process_frame
		world = current_scene
		world.process_mode = Node.PROCESS_MODE_DISABLED
		_check(world.get_node("SaveSession").codec.character_version() == 5, "교체 후 V5 유지")
		_check(world.get_node("SaveSession").store.root == ROOT, "교체 후 경로 유지")
	_check(world.has_node("Merchant"), "노베라 보급상 연결")
	_check(world.get_node("SaveSession").new_character().ok, "제품 새 캐릭터")
	await process_frame
	await process_frame
	world = current_scene
	world.process_mode = Node.PROCESS_MODE_DISABLED
	_check(world.get_node("SaveSession").codec.character_version() == 5, "새 캐릭터 V5 유지")
	_check(
		FileAccess.get_sha256(ROOT.path_join("character_01.json")) == digest, "여행·새 캐릭터 기존 슬롯 불변"
	)
	finished = true


func _verify() -> void:
	await _load_product()
	var session = world.get_node("SaveSession")
	var expected = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("expected.json")))
	_check(JSON.parse_string(JSON.stringify(session.character)) == expected, "별도 프로세스 전체 캐릭터 복원")
	_check(not session.migration_pending and session.loaded_source_version == 5, "V5 재입력 이관 없음")
	var captured: Dictionary = session.codec.capture(
		world.get_node("Player"), session.account.account_id, session.character
	)
	# JSON은 숫자를 float로 읽는다. 양쪽을 같은 파일 표현으로 비교한다.
	_check(
		JSON.parse_string(JSON.stringify(captured.inventory)) == session.character.inventory,
		"장비·가방·overflow 복제 없음"
	)
	for version in [6, 7]:
		var forged: Dictionary = session.character.duplicate(true)
		forged.character_save_version = version
		_check(
			not session.codec.prepare_loaded(forged, session.account).ok,
			"미채택 버전 거부 " + str(version)
		)
	finished = true


func _write(file: String, text: String) -> void:
	var output := FileAccess.open(ROOT.path_join(file), FileAccess.WRITE)
	_check(output != null, "증거 기록 " + file)
	if output != null:
		output.store_string(text)


func _preview() -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "미리보기 렌더 필요")
		return
	root.size = Vector2i(1920, 1080)
	_attach(load(PRODUCT_PATH).instantiate_world("novera_gate"))
	# 화면 확인만을 위한 위치 준비. 실제 도보/의뢰 증거가 아니다.
	world.get_node("Player").position = Vector2(184, 440)
	var panel = world.get_node("EconomyPanel")
	for mode in ["bag", "gear", "shop"]:
		_check(panel.open(mode), "제품 화면 열기 " + mode)
		await process_frame
		await RenderingServer.frame_post_draw
		_check(
			(
				root.get_texture().get_image().save_png(
					"res://../docs/qa/screenshots/m6-product-%s.png" % mode
				)
				== OK
			),
			"제품 화면 기록 " + mode
		)
		panel.close()
	finished = true
