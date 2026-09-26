extends SceneTree
## 실제 입력 QA용: 저장 폴더만 분리하며 게임 상태·시간·입력을 조작하지 않는다.


class InputObserver:
	extends Node

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			print(
				(
					"MANUAL_INPUT key=%s physical=%s device=%s move_up=%s menu_skill=%s"
					% [
						event.keycode,
						event.physical_keycode,
						event.device,
						event.is_action_pressed("move_up"),
						event.is_action_pressed("menu_skill")
					]
				)
			)


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var world: Node = load("res://scenes/world/eastern_frontier_starting_area.tscn").instantiate()
	world.set_meta("save_directory", "user://m4_manual_play_2026_09_27")
	root.add_child(world)
	current_scene = world
	var observer := InputObserver.new()
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(observer)
