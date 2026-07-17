## UI-1 검증 — 플레이어 상태 패널(A요소)의 HP/MP 바 갱신, 잔상 감쇠, 저체력 테두리 점멸.
extends GutTest

var _panel: PlayerStatusPanel


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/player_status_panel.tscn")
	_panel = scene.instantiate()
	add_child_autofree(_panel)


func test_set_hp_updates_fill_and_label() -> void:
	_panel.set_hp(50.0, 100.0)
	var fill: ColorRect = _panel.get_node("HPBar/Fill")
	var bar_width: float = _panel.get_node("HPBar").size.x
	var label: Label = _panel.get_node("HPBar/Label")
	assert_almost_eq(fill.size.x, bar_width * 0.5, 0.5)
	assert_eq(label.text, "50/100")


func test_set_mp_updates_fill_and_label() -> void:
	_panel.set_mp(20.0, 40.0)
	var fill: ColorRect = _panel.get_node("MPBar/Fill")
	var bar_width: float = _panel.get_node("MPBar").size.x
	var label: Label = _panel.get_node("MPBar/Label")
	assert_almost_eq(fill.size.x, bar_width * 0.5, 0.5)
	assert_eq(label.text, "20/40")


func test_low_hp_shows_border_blink() -> void:
	var border: Panel = _panel.get_node("HPBar/BorderBlink")
	_panel.set_hp(20.0, 100.0)  ## 30% 이하
	_panel._process(0.1)
	assert_true(border.visible)


func test_normal_hp_hides_border_blink() -> void:
	var border: Panel = _panel.get_node("HPBar/BorderBlink")
	_panel.set_hp(80.0, 100.0)
	_panel._process(0.1)
	assert_false(border.visible)


func test_ghost_bar_lags_behind_on_damage_then_catches_up() -> void:
	var ghost: ColorRect = _panel.get_node("HPBar/Ghost")
	var bar_width: float = _panel.get_node("HPBar").size.x
	_panel.set_hp(100.0, 100.0)
	_panel._process(0.1)  ## 잔상도 100%로 시작
	assert_almost_eq(ghost.size.x, bar_width, 0.5)

	_panel.set_hp(20.0, 100.0)  ## 급격한 데미지
	_panel._process(0.05)
	assert_true(ghost.size.x > bar_width * 0.2, "잔상은 즉시 따라가지 않고 서서히 감소해야 한다")

	for i in range(50):  ## 충분한 시간 경과 후 실제 HP를 따라잡아야 함
		_panel._process(0.1)
	assert_almost_eq(ghost.size.x, bar_width * 0.2, 0.5)


func test_set_level_and_job_updates_label() -> void:
	_panel.set_level_and_job(3, "전사")
	var label: Label = _panel.get_node("LevelJobLabel")
	assert_eq(label.text, "Lv.3 전사")
