# gdlint: disable=max-returns
extends Node

signal status_changed(message: String)
signal auto_wait_changed(reason: String)

const Store = preload("res://scripts/save/save_file_store.gd")
const Codec = preload("res://scripts/save/character_save_codec.gd")
const Safety = preload("res://scripts/save/save_safety.gd")
const WORLD_PATH := "res://scenes/world/eastern_frontier_starting_area.tscn"
const Regions = preload("res://scripts/world/region_registry.gd")
const AUTO_SECONDS := 180.0
var codec = Codec.new()
var store: RefCounted
var account: Dictionary = {}
var character: Dictionary = {}
var active_slot := 0
var migration_pending := false
var loaded_source_version := 0
var world: Node
var account_error := ""
var last_message := "슬롯을 선택해 저장하세요. 자동 저장은 첫 저장 후 시작됩니다."
var auto_wait_reason := ""
var _auto_elapsed := 0.0
var _play_seconds := 0.0
var _destination := Regions.START


func setup(owner_world: Node) -> String:
	world = owner_world
	store = _create_store(world.get_meta("save_directory", "user://saves"))
	store.validators["account"] = codec.schema.account_error
	var result: Dictionary = store.read_save("account")
	if result.ok:
		account = result.data
		if result.recovered:
			last_message = "계정 백업을 사용 중입니다. 저장 전에 슬롯을 확인하세요."
	elif result.code == "missing" and _no_existing_saves():
		account = codec.new_account()
	else:
		account_error = "account_" + result.code
		last_message = "계정 저장을 열 수 없습니다: " + result.code
		return account_error
	codec.bind_store(store, account)
	var boot: Dictionary = world.get_meta("save_boot", {})
	if not boot.is_empty():
		# 새 캐릭터도 계정 ID를 유지한다. 디스크 계정과 다른 스냅샷은 수용하지 않는다.
		if boot.account.account_id != account.account_id:
			return "account_mismatch"
		character = boot.character.duplicate(true)
		active_slot = boot.slot
		if not character.is_empty():
			var source_version: Variant = character.get("character_save_version")
			var prepared: Dictionary = codec.prepare_loaded(character, account)
			if not prepared.ok:
				return prepared.code
			loaded_source_version = int(source_version)
			migration_pending = loaded_source_version < codec.character_version()
			character = prepared.data
			var error: String = codec.restore_into(world.get_node("Player"), character, account)
			if not error.is_empty():
				return error
			var tutorial = world.get_node("TutorialController")
			tutorial.tutorial_done = character.tutorial.tutorial_done
			tutorial.hint_heal_done = character.tutorial.hint_heal_done
			_play_seconds = float(character.play_seconds)
		last_message = boot.get("message", "불러오기 완료")
		var carry: Dictionary = boot.get("session_carry", {})
		migration_pending = carry.get("migration_pending", migration_pending)
		loaded_source_version = carry.get("loaded_source_version", loaded_source_version)
		_auto_elapsed = carry.get("auto_elapsed", 0.0)
		if migration_pending:
			last_message += "\n이전 버전 저장을 불러왔습니다. 확인 후 수동 저장이 필요합니다."
	return ""


func _create_store(directory: String) -> RefCounted:
	return Store.new(directory)


func _instantiate_world() -> Node:
	return load(Regions.SCENES[_destination]).instantiate()


func _no_existing_saves() -> bool:
	if not DirAccess.dir_exists_absolute(store.root):
		return true
	for file in DirAccess.get_files_at(store.root):
		if (
			(file.begins_with("account.json.") or file.begins_with("character_"))
			and ".preserved." in file
		):
			return false
	if FileAccess.file_exists(store.root.path_join("account.json.bak")):
		return false
	for slot in range(1, 11):
		var path: String = store.root.path_join("character_%02d.json" % slot)
		if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
			return false
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if get_tree().paused or not account_error.is_empty():
		return
	_play_seconds += delta
	if active_slot == 0 or migration_pending:
		return
	_auto_elapsed += delta
	if _auto_elapsed < AUTO_SECONDS:
		return
	var reason: String = Safety.blocked_reason(world)
	_set_auto_wait(reason)
	if not reason.is_empty():
		return
	_auto_elapsed = 0.0
	var existing: Dictionary = store.read_save("character", active_slot)
	var disk_account: Dictionary = store.read_save("account")
	if not existing.ok or not disk_account.ok:
		_report("자동 저장 중단: 계정 또는 활성 슬롯을 읽을 수 없습니다.")
		return
	if existing.recovered or disk_account.recovered:
		_report("자동 저장 중단: 백업 복구 상태입니다. 확인 후 수동 저장이 필요합니다.")
		return
	if existing.data.character_id != character.character_id:
		_report("자동 저장 중단: 슬롯의 캐릭터가 바뀌었습니다.")
		return
	var result := save_slot(active_slot)
	_report("자동 저장 완료 · 슬롯 %d" % active_slot if result.ok else "자동 저장 실패: " + result.code)


func save_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > 10:
		return _failure("invalid_slot")
	if not account_error.is_empty():
		return _failure(account_error)
	var reason: String = Safety.blocked_reason(world)
	if not reason.is_empty():
		var failure := _failure(reason)
		if reason == "enemy_nearby":
			failure["blocker"] = Safety.nearby_enemy_details(world)
		return failure
	# 외부에서 계정 파일이 바뀐 경우 기존 상태로 덮어쓰지 않는다.
	var disk: Dictionary = store.read_save("account")
	if disk.ok:
		if disk.data.account_id != account.account_id:
			return _failure("account_mismatch")
		account = disk.data
	elif disk.code != "missing" or not _no_existing_saves():
		return _account_failure(disk)
	var tutorial = world.get_node("TutorialController")
	var snapshot: Dictionary = codec.capture(
		world.get_node("Player"), account.account_id, character
	)
	snapshot.play_seconds = _play_seconds
	snapshot.tutorial = {
		"tutorial_done": tutorial.tutorial_done, "hint_heal_done": tutorial.hint_heal_done
	}
	var error: String = codec.schema.character_error(snapshot, account)
	if not error.is_empty():
		return _failure(error)
	account.tutorial_completed = account.tutorial_completed or tutorial.tutorial_done
	codec.bind_store(store, account)
	var result: Dictionary = store.write_save("account", 0, account)
	if not result.ok:
		return result
	result = store.write_save("character", slot, snapshot)
	if result.ok:
		character = snapshot
		migration_pending = false
		active_slot = slot
		_auto_elapsed = 0.0
		_set_auto_wait("")
		_report("저장 완료 · 슬롯 %d" % slot)
	return result


func load_slot(slot: int) -> Dictionary:
	if _change_blocked():
		return _failure("death_sequence")
	var disk: Dictionary = store.read_save("account")
	if not disk.ok:
		return _account_failure(disk)
	codec.bind_store(store, disk.data)
	var result: Dictionary = store.read_save("character", slot)
	if not result.ok:
		return result
	var position := Vector2(result.data.world.position[0], result.data.world.position[1])
	if not Regions.contains(result.data.world.map_id, position):
		return _failure("position_outside_map")
	var recovered: bool = disk.recovered or result.recovered
	return _replace_world(
		disk.data,
		result.data,
		slot,
		"백업 복구로 불러왔습니다. 필드와 미회수 드롭은 초기화됩니다." if recovered else "불러오기 완료 · 필드와 미회수 드롭은 초기화됩니다."
	)


func new_character() -> Dictionary:
	if _change_blocked() or not account_error.is_empty():
		return _failure("session_blocked")
	# 계정이 아직 없으면 생성부터 확정한다. 기존 계정은 검증 후 그대로 유지한다.
	var disk: Dictionary = store.read_save("account")
	if disk.ok:
		return _replace_world(disk.data, {}, 0, "새 모험가입니다. 저장할 슬롯을 선택하세요.")
	if disk.code != "missing" or not _no_existing_saves():
		return _account_failure(disk)
	var result: Dictionary = store.write_save("account", 0, account)
	if not result.ok:
		return result
	return _replace_world(account, {}, 0, "새 모험가입니다. 저장할 슬롯을 선택하세요.")


func _change_blocked() -> bool:
	var quests := world.get_node_or_null("QuestController") as QuestController
	if quests != null and quests.is_reward_busy():
		return true
	var player = world.get_node("Player")
	return (
		player.is_input_locked
		or player.get_node("PlayerStats").is_dead()
		or player.get_node("PlayerDeathSequence").is_active()
	)


func _replace_world(
	saved_account: Dictionary,
	data: Dictionary,
	slot: int,
	message: String,
	session_carry: Dictionary = {}
) -> Dictionary:
	var tree := get_tree()
	var paused := tree.paused
	var arbiter := UiPauseArbiter.for_world(world)
	var previous_owner := arbiter.suspend()
	var old_day: int = GameClock.day_number
	var old_time: float = GameClock._elapsed_real_sec_in_day
	tree.paused = true
	_destination = Regions.START if data.is_empty() else data.world.map_id
	var next_world: Node = _instantiate_world()
	next_world.set_meta("save_directory", store.root)
	next_world.set_meta(
		"save_boot",
		{
			"account": saved_account,
			"character": data,
			"slot": slot,
			"message": message,
			"session_carry": session_carry
		}
	)
	# 자식 스포너 _ready 전에 시각을 설정해 밤 배치가 처음부터 일치하게 한다.
	GameClock.prepare_scene_time(
		1 if data.is_empty() else int(data.world.day_number),
		0.0 if data.is_empty() else float(data.world.elapsed_real_sec_in_day)
	)
	world.get_parent().add_child(next_world)
	var error: String = next_world.get_meta("save_boot_error", "")
	if not error.is_empty():
		next_world.free()
		GameClock.prepare_scene_time(old_day, old_time)
		if is_instance_valid(previous_owner):
			tree.paused = false
			arbiter.acquire(previous_owner)
		else:
			tree.paused = paused
		return _failure(error)
	if tree.current_scene == world:
		tree.current_scene = next_world
	world.get_node("SaveMenu").close_menu()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.hide()
	world.queue_free()
	tree.paused = false
	return {"ok": true, "code": "ok"}


func travel(destination: String) -> Dictionary:
	if not account_error.is_empty():
		return _failure(account_error)
	if not Regions.SCENES.has(destination) or destination == world.map_id:
		return _failure("unknown_map")
	var journal: QuestJournal = world.get_node("QuestController").journal
	if journal.export_state().get("MQ-01-05", {}).get("state") != "completed":
		return _failure("region_locked")
	if _change_blocked() or get_tree().paused:
		return _failure("session_blocked")
	var player = world.get_node("Player")
	if player.position.distance_to(Regions.GATES[world.map_id]) > 40.0:
		return _failure("gate_distance")
	var reason: String = player.get_node("PlayerStats").save_block_reason(5.0)
	if reason.is_empty():
		reason = player.save_block_reason()
	if not reason.is_empty():
		return _failure(reason)
	var snapshot: Dictionary = codec.capture(player, account.account_id, character)
	snapshot.play_seconds = _play_seconds
	var tutorial = world.get_node("TutorialController")
	snapshot.tutorial = {
		"tutorial_done": tutorial.tutorial_done, "hint_heal_done": tutorial.hint_heal_done
	}
	snapshot.world.map_id = destination
	var arrival: Vector2 = Regions.ARRIVALS[destination]
	snapshot.world.position = [arrival.x, arrival.y]
	var error: String = codec.schema.character_error(snapshot, account)
	if not error.is_empty():
		return _failure(error)
	var disk: Dictionary = store.read_save("account")
	if disk.ok:
		if disk.data.account_id != account.account_id:
			return _failure("account_mismatch")
	elif disk.code == "missing" and _no_existing_saves():
		var written: Dictionary = store.write_save("account", 0, account)
		if not written.ok:
			return written
	else:
		return _account_failure(disk)
	return _replace_world(
		account,
		snapshot,
		active_slot,
		"지역 이동 완료 · 저장은 별도입니다.",
		{
			"migration_pending": migration_pending,
			"loaded_source_version": loaded_source_version,
			"auto_elapsed": _auto_elapsed
		}
	)


func _report(message: String) -> void:
	last_message = message
	status_changed.emit(message)


func _set_auto_wait(reason: String) -> void:
	if auto_wait_reason == reason:
		return
	auto_wait_reason = reason
	auto_wait_changed.emit(reason)


func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}


func _account_failure(result: Dictionary) -> Dictionary:
	var failure := result.duplicate(true)
	failure.code = "account_" + result.code
	failure.file_kind = "account"
	return failure
