## 파일 계층 전용 프로세스 중단 검사. 실제 사용자 saves 디렉터리는 사용하지 않는다.
## -- seed / interrupt / verify / cleanup 순서로 각각 별도 프로세스에서 실행한다.
extends SceneTree

const Store = preload("res://scripts/save/save_file_store.gd")
const ROOT := "user://m4_process_probe"


class InterruptingStore:
	extends "res://scripts/save/save_file_store.gd"
	var remove_before_kill := false

	func _replace_file(source: String, destination: String) -> Error:
		if destination.ends_with(".json"):
			if remove_before_kill:
				DirAccess.remove_absolute(destination)
			OS.kill(OS.get_process_id())
			return ERR_BUSY
		return super._replace_file(source, destination)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var store = Store.new(ROOT)
	match args[0]:
		"seed":
			quit(0 if store.write_save("character", 1, {"gold": 10}).ok else 1)
		"interrupt", "interrupt_mid":
			var interrupted := InterruptingStore.new(ROOT)
			interrupted.remove_before_kill = args[0] == "interrupt_mid"
			interrupted.write_save("character", 1, {"gold": 99})
			quit(1)  # 정상 반환했다면 강제 중단 검증 실패다.
		"verify", "verify_mid":
			var result: Dictionary = store.read_save("character", 1)
			var valid: bool = result.ok and int(result.data.gold) == 10
			valid = valid and FileAccess.file_exists(ROOT.path_join("character_01.json.tmp"))
			valid = valid and FileAccess.file_exists(ROOT.path_join("character_01.json.bak"))
			if args[0] == "verify_mid":
				valid = valid and result.recovered
				valid = valid and not FileAccess.file_exists(ROOT.path_join("character_01.json"))
			print("M4_PROCESS_PRESERVATION_PASS" if valid else "M4_PROCESS_PRESERVATION_FAIL")
			quit(0 if valid else 1)
		"cleanup":
			for file in DirAccess.get_files_at(ROOT):
				DirAccess.remove_absolute(ROOT.path_join(file))
			DirAccess.remove_absolute(ROOT)
			quit(0)
		_:
			quit(2)
