## 충돌 레이어 정리(디렉터 플레이 게이트 차단 버그 수정) 이후 시작 지역 씬이 오류 없이
## 로드·틱되는지 확인하는 헤드리스 스모크 테스트.
extends GutTest

const STARTING_AREA_SCENE := preload("res://scenes/world/eastern_frontier_starting_area.tscn")


func after_each() -> void:
	GameClock.reset()  ## G2-4: 오토로드는 테스트 전체에서 하나뿐이므로 다음 테스트로 새지 않게 한다.


func test_eastern_frontier_starting_area_loads_and_ticks_without_errors() -> void:
	var area: Node2D = STARTING_AREA_SCENE.instantiate()
	add_child_autofree(area)

	await wait_physics_frames(5)

	assert_true(is_instance_valid(area), "시작 지역 씬이 예외 없이 로드·틱되어야 한다")


## G2-4 헤드리스 검증 — 실제 시작 지역 씬에서 디버그 시간 가속(F10과 동일한
## GameClock.debug_jump_hours)으로 낮→밤 전환을 일으켜도 오류 없이 CanvasModulate가
## 반응하는지 확인한다(전환 로그는 eastern_frontier_starting_area.gd의 print로 콘솔에 남는다).
func test_time_acceleration_triggers_night_transition_without_errors() -> void:
	GameClock.reset()
	var area: Node2D = STARTING_AREA_SCENE.instantiate()
	add_child_autofree(area)
	await wait_physics_frames(2)

	watch_signals(GameClock)
	GameClock.debug_jump_hours(16.0)  ## 낮 16시간 전부 점프 → 밤 진입 (F10을 16회 누른 것과 동일)
	await wait_physics_frames(2)

	assert_true(is_instance_valid(area), "시간 점프 후에도 씬이 예외 없이 살아있어야 한다")
	assert_false(GameClock.is_day, "16시간 점프 후에는 밤이어야 한다")
	assert_signal_emitted(GameClock, "night_started")
	var modulate_node: CanvasModulate = area.get_node("DayNightModulate")
	assert_not_null(modulate_node, "야간 색조를 담당할 CanvasModulate 노드가 있어야 한다")
