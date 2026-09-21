## 계정/캐릭터 파일의 무결성·버전·교체만 담당한다. 게임 상태 검증은 codec 책임이다.
class_name SaveFileStore
extends RefCounted
# 파일 검증의 조기 반환은 실패 원인을 보존하기 위한 의도적 구조다.
# gdlint: disable=max-returns

const VERSIONS := {"account": 1, "character": 1}
const MAX_BYTES := 4 * 1024 * 1024
var root: String
var validators: Dictionary = {}


func _init(directory: String = "user://saves") -> void:
	root = directory


func read_save(kind: String, slot: int = 0) -> Dictionary:
	var path := _path(kind, slot)
	if path.is_empty():
		return _failure("invalid_slot")
	var current := _read(path, kind)
	if current.ok or current.code == "unsupported_version":
		return current
	var backup := _read(path + ".bak", kind)
	if backup.ok:
		backup.recovered = true
		return backup
	if backup.code == "unsupported_version":
		return backup
	return current


func write_save(kind: String, slot: int, data: Dictionary) -> Dictionary:
	var path := _path(kind, slot)
	if path.is_empty():
		return _failure("invalid_slot")
	if validators.has(kind) and not validators[kind].call(data).is_empty():
		return _failure("invalid_data")
	# 상위 버전은 현재 세션의 데이터로 덮어쓰면 돌이킬 수 없으므로 명시 거부한다.
	if read_save(kind, slot).code == "unsupported_version":
		return _failure("unsupported_version")
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		return _failure("io_error")
	var payload := JSON.stringify(data)
	if payload.to_utf8_buffer().size() > MAX_BYTES:
		return _failure("too_large")
	var envelope := {
		"kind": kind,
		"version": VERSIONS[kind],
		"payload": payload,
		"checksum": payload.sha256_text()
	}
	var temp := path + ".tmp"
	var error := _write_text(temp, JSON.stringify(envelope))
	if error != OK or not _read(temp, kind).ok:
		return _failure("io_error")
	# 정상 주 파일만 백업한다. 손상 파일로 마지막 정상 백업을 오염시키지 않는다.
	if _read(path, kind).ok:
		error = _write_text(path + ".bak.tmp", FileAccess.get_file_as_string(path))
		if error != OK or not _read(path + ".bak.tmp", kind).ok:
			return _failure("io_error")
		if _replace_file(path + ".bak.tmp", path + ".bak") != OK:
			return _failure("io_error")
	if _replace_file(temp, path) != OK:
		return _failure("io_error")
	return {"ok": true, "code": "ok", "recovered": false}


func _path(kind: String, slot: int) -> String:
	if kind == "account" and slot == 0:
		return root.path_join("account.json")
	if kind == "character" and slot >= 1 and slot <= 10:
		return root.path_join("character_%02d.json" % slot)
	return ""


func _read(path: String, kind: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("missing")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("io_error")
	if file.get_length() > MAX_BYTES * 2:
		file.close()
		return _failure("too_large")
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return _failure("corrupt")
	var envelope: Dictionary = json.data
	if envelope.get("kind") != kind:
		return _failure("corrupt")
	var version: Variant = envelope.get("version")
	if not (version is int or version is float):
		return _failure("corrupt")
	if version != VERSIONS[kind]:
		return _failure("unsupported_version")
	var payload: Variant = envelope.get("payload")
	if not payload is String or envelope.get("checksum") != payload.sha256_text():
		return _failure("corrupt")
	if json.parse(payload) != OK or not json.data is Dictionary:
		return _failure("corrupt")
	if validators.has(kind) and not validators[kind].call(json.data).is_empty():
		return _failure("invalid_data")
	return {"ok": true, "code": "ok", "data": json.data, "recovered": false}


func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	return error


func _replace_file(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(source, destination)


func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code, "data": {}, "recovered": false}
