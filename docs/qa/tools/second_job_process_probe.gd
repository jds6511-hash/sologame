## 별도 프로세스 2차 직업 복원 검사. 레벨·선행/시련 완료·집중은 준비 fixture다.
## 전직/스킬 투자/저장/불러오기는 제품 API를 사용하며 시련 입력 완주 증거는 아니다.
extends SceneTree

const DIRECTORY := "user://product_verify"
const PRODUCT = preload("res://scripts/world/game_product.gd")
const CONTENT = preload("res://scripts/content/game_content.gd")
const SNAPSHOT_FILE := "second-job-snapshot.json"
var world: Node
var failed := false
var finished := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(1))
	_run.call_deferred()


func check(value: bool, label: String) -> void:
	print(label, ": ", value)
	failed = failed or not value


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["cleanup", "seed", "reload"]:
		quit(2)
		return
	if args[0] == "cleanup":
		if DirAccess.dir_exists_absolute(DIRECTORY):
			for file in DirAccess.get_files_at(DIRECTORY):
				check(DirAccess.remove_absolute(DIRECTORY.path_join(file)) == OK, "격리 파일 정리")
		finished = true
	else:
		world = PRODUCT.instantiate_world("novera_commons")
		world.set_meta("save_directory", DIRECTORY)
		root.add_child(world)
		current_scene = world
		world.get_node("Player").set_physics_process(false)
		await process_frame
		if args[0] == "seed":
			await seed_slots()
		else:
			await reload_slots()
	check(finished, "두 직업 최종 검사 도달")
	if is_instance_valid(current_scene):
		current_scene.free()
	root.get_node("BgmManager").reset()
	await process_frame
	print("SECOND_JOB_PROCESS_FAIL" if failed else "SECOND_JOB_PROCESS_PASS")
	quit(1 if failed else 0)


func refresh() -> void:
	await process_frame
	for child in root.get_children():
		if child.has_node("SaveSession") and not child.is_queued_for_deletion():
			world = child
			current_scene = world
			world.get_node("Player").set_physics_process(false)
	await process_frame
	check(world.get_node("SaveSession").store.root == DIRECTORY, "월드 교체 뒤 QA 저장 격리")


func prepare(first_job: StringName, trial: String) -> void:
	var player: PlayerController = world.get_node("Player")
	var progression: PlayerProgression = player.get_node("PlayerProgression")
	while progression.current_level < 40:
		progression.add_exp(progression.level_curve.req(progression.current_level) - progression.current_exp)
	var journal: QuestJournal = world.get_node("QuestController").journal
	var states := {}
	for id in journal.catalog.ordered_ids():
		if CONTENT.QUEST_REVISIONS[id] < 6 or id in ["MQ-07-01", trial]:
			states[id] = {"state": "completed", "counts": Array(journal.catalog.definitions[id].objective_counts)}
	check(journal.restore_state(states) == "", "이전 장·첫 보고·계열 시련 완료 fixture")
	check(player.get_node("PlayerJobTransition").perform_transition(first_job), "제품 1차 전직 " + String(first_job))


func seed_slots() -> void:
	var expected := {}
	for slot in [1, 2]:
		if slot == 2:
			check(world.get_node("SaveSession").new_character().ok, "두 번째 새 캐릭터")
			await refresh()
		var archer: bool = slot == 2
		var job: StringName = &"sharpshooter" if archer else &"gladiator"
		prepare(&"archer" if archer else &"warrior", "TR-ARC-02" if archer else "TR-WAR-02")
		var player: PlayerController = world.get_node("Player")
		var transition: PlayerJobTransition = player.get_node("PlayerJobTransition")
		check(transition.perform_transition(job), "제품 2차 전직 " + String(job))
		check(not transition.perform_transition(job), "중복 전직 거부")
		var skill := StringName(player.skill_slot_4.skill_name)
		check(player.get_node("PlayerSkillPoints").try_upgrade_skill(skill, false), "제품 전용 스킬 포인트 투자")
		var runtime: Node = player.get_meta("economy_candidate")
		check(runtime.state().equipment.weapon == ("WPN-BW-40-B" if archer else "WPN-GS-40-B"), "계열 Lv40 B 무기 지급")
		if archer:
			# 집중 모델 fixture: 비영구 값이 디스크 복원으로 유출되지 않는지만 확인.
			var cast: int = player._shots.focus.begin_cast(1)
			player._shots.focus.landed(cast, 0)
			player._shots.focus.end(cast, 0)
			check(player._shots.focus.value > 0, "저장 전 임시 집중 fixture")
		var saved: Dictionary = world.get_node("SaveSession").save_slot(slot)
		check(saved.ok, "슬롯 " + str(slot) + " 저장 / " + saved.code)
		expected[str(slot)] = snapshot()
	var file := FileAccess.open(DIRECTORY.path_join(SNAPSHOT_FILE), FileAccess.WRITE)
	if file == null:
		check(false, "스냅샷 파일 생성")
		return
	file.store_string(JSON.stringify(expected, "", false, true))
	file.close()
	finished = true


func reload_slots() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join(SNAPSHOT_FILE)))
	if not expected is Dictionary or not expected.has("1") or not expected.has("2"):
		check(false, "준비 스냅샷 존재")
		return
	for slot in [1, 2]:
		var loaded: Dictionary = world.get_node("SaveSession").load_slot(slot)
		check(loaded.ok, "별도 프로세스 슬롯 " + str(slot) + " 로드 / " + loaded.code)
		if not loaded.ok:
			return
		await refresh()
		check(expected[str(slot)] == JSON.parse_string(JSON.stringify(snapshot(), "", false, true)), "직업·SP 지출·장비·가방·의뢰 복원 동등")
		var player: PlayerController = world.get_node("Player")
		check(player._shots.focus.value == 0, "불러오기 집중 0")
		check(not player.get_node("PlayerJobTransition").perform_transition(&"gladiator" if slot == 1 else &"sharpshooter"), "로드 후 중복 지급 거부")
		check(expected[str(slot)] == JSON.parse_string(JSON.stringify(snapshot(), "", false, true)), "중복 전직 거부 뒤 장비·SP 불변")
	finished = true


func snapshot() -> Dictionary:
	var session: Node = world.get_node("SaveSession")
	var data: Dictionary = session.codec.capture(world.get_node("Player"), session.account.account_id)
	var player := {}
	for key in ["job_id", "level", "exp", "skill_points", "spent_points", "skill_levels", "skill_costs"]:
		player[key] = data.player[key]
	return {"player": player, "inventory": data.inventory, "quests": data.progress.quests}
