## 충돌 레이어 정리(디렉터 플레이 게이트 차단 버그 수정) 이후 시작 지역 씬이 오류 없이
## 로드·틱되는지 확인하는 헤드리스 스모크 테스트.
extends GutTest


func test_eastern_frontier_starting_area_loads_and_ticks_without_errors() -> void:
	var scene: PackedScene = load("res://scenes/world/eastern_frontier_starting_area.tscn")
	var area: Node2D = scene.instantiate()
	add_child_autofree(area)

	await wait_physics_frames(5)

	assert_true(is_instance_valid(area), "시작 지역 씬이 예외 없이 로드·틱되어야 한다")
