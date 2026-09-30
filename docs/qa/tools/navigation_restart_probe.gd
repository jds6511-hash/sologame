## QA 경로 회귀 전용 fixture. 정상 완주 증거와 분리하며 저장하지 않는다.
extends "res://../docs/qa/tools/yeoulmok_onboarding_probe.gd"


func _initialize() -> void:
	_test_navigation.call_deferred()


func _test_navigation() -> void:
	world = _instantiate_onboarding_world()
	world.set_meta("save_directory", "user://navigation_restart_probe")
	root.add_child(world)
	current_scene = world
	await _refresh_world()
	player.position = Vector2(157, 504)
	await physics_frame
	var path := _route(Vector2(200, 504))
	_check(not path.is_empty() and path[0].x > player.position.x, "재탐색 첫 점이 뒤로 돌아가지 않음")
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 32)
	shape.shape = rectangle
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = Vector2(164, 495)
	await physics_frame
	var corner := PackedVector2Array([Vector2(152, 504), Vector2(168, 504)])
	_check(_forward_route(corner) == corner, "다음 점으로의 실제 충돌이 있으면 첫 점 보존")
	var long_path := PackedVector2Array([player.position + Vector2(1104, 0)])
	_check(_walk_tick_budget(long_path, long_path[0]) > 2400, "1104px 긴 구간은 거리 비례 한도")
	_check(_walk_tick_budget(path, Vector2(200, 504)) == 2400, "짧은 구간 기존 최소 한도 유지")
	var huge := PackedVector2Array([Vector2(100000, 0)])
	_check(_walk_tick_budget(huge, huge[0]) == 10800, "구간 한도 무제한 연장 방지")
	world.free()
	root.get_node("BgmManager").reset()
	print("NAVIGATION_RESTART_FAIL" if failed else "NAVIGATION_RESTART_PASS")
	quit(1 if failed else 0)
