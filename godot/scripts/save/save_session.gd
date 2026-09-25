# gdlint: disable=max-returns
extends Node

signal status_changed(message: String)

const Store = preload("res://scripts/save/save_file_store.gd")
const Codec = preload("res://scripts/save/character_save_codec.gd")
const Safety = preload("res://scripts/save/save_safety.gd")
const WORLD_PATH := "res://scenes/world/eastern_frontier_starting_area.tscn"
const AUTO_SECONDS := 180.0
var codec = Codec.new()
var store: RefCounted
var account: Dictionary = {}
var character: Dictionary = {}
var active_slot := 0
var world: Node
var account_error := ""
var last_message := "슬롯을 선택해 저장하세요. 자동 저장은 첫 저장 후 시작됩니다."
var _auto_elapsed := 0.0
var _play_seconds := 0.0


func setup(owner_world: Node) -> String:
	world = owner_world
	store = Store.new(world.get_meta("save_directory", "user://saves"))
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
			var error: String = codec.restore_into(world.get_node("Player"), character, account)
			if not error.is_empty():
				return error
			var tutorial = world.get_node("TutorialController")
			tutorial.tutorial_done = character.tutorial.tutorial_done
			tutorial.hint_heal_done = character.tutorial.hint_heal_done
			_play_seconds = float(character.play_seconds)
		last_message = boot.get("message", "불러오기 완료")
	return ""


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
	if active_slot == 0:
		return
	_auto_elapsed += delta
	if _auto_elapsed < AUTO_SECONDS or not Safety.blocked_reason(world).is_empty():
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
		return _failure(reason)
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
		active_slot = slot
		_auto_elapsed = 0.0
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
	var ground = world.get_node("Ground")
	var position := Vector2(result.data.world.position[0], result.data.world.position[1])
	if not ground.get_used_rect().has_point(ground.local_to_map(position)):
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
	var player = world.get_node("Player")
	return (
		player.is_input_locked
		or player.get_node("PlayerStats").is_dead()
		or player.get_node("PlayerDeathSequence").is_active()
	)


func _replace_world(
	saved_account: Dictionary, data: Dictionary, slot: int, message: String
) -> Dictionary:
	var tree := get_tree()
	var paused := tree.paused
	var old_day: int = GameClock.day_number
	var old_time: float = GameClock._elapsed_real_sec_in_day
	tree.paused = true
	var next_world: Node = load(WORLD_PATH).instantiate()
	next_world.set_meta("save_directory", store.root)
	next_world.set_meta(
		"save_boot", {"account": saved_account, "character": data, "slot": slot, "message": message}
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


func _report(message: String) -> void:
	last_message = message
	status_changed.emit(message)


func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}


func _account_failure(result: Dictionary) -> Dictionary:
	var failure := result.duplicate(true)
	failure.code = "account_" + result.code
	failure.file_kind = "account"
	return failure
