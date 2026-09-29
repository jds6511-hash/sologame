## 사람 플레이용 격리 실행기. fixture·시간 가속·자동 조작을 사용하지 않는다.
extends SceneTree

const LIFECYCLE = preload("res://scripts/tools/yeoulmok_pilot_session.gd")


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	root.size = Vector2i(1920, 1080)
	var lifecycle := LIFECYCLE.new()
	root.add_child(lifecycle)
	var world = load(LIFECYCLE.START_SCENE).instantiate()
	world.set_meta("save_directory", lifecycle.save_directory)
	root.add_child(world)
	current_scene = world
	if not world.has_node("ArtPilot/NativeSurface"):
		push_error("여울목 키트 설치 실패")
		quit(1)
		return
	print("YEOULMOK_PLAY_READY: 격리 저장, F6 불러오기/새 캐릭터/여울목 귀환 시 키트 유지")
