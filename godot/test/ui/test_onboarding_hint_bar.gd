## UI-4 검증 — OnboardingHintBar(T 바) 페이드/토스트 동작 재현.
extends GutTest

var _bar: OnboardingHintBar


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/onboarding_hint_bar.tscn")
	_bar = scene.instantiate()
	add_child_autofree(_bar)


func test_starts_hidden() -> void:
	var panel: Panel = _bar.get_node("Panel")
	assert_false(panel.visible)


func test_show_hint_fades_in_over_0_3_sec() -> void:
	_bar.show_hint("테스트 힌트")
	_bar._process(0.3)
	var panel: Panel = _bar.get_node("Panel")
	assert_true(panel.visible)
	assert_almost_eq(panel.modulate.a, 1.0, 0.01)
	assert_eq(_bar.get_node("Panel/Label").text, "테스트 힌트")


func test_hide_hint_fades_out_and_hides_panel() -> void:
	_bar.show_hint("테스트 힌트")
	_bar._process(0.3)
	_bar.hide_hint()
	_bar._process(0.3)
	var panel: Panel = _bar.get_node("Panel")
	assert_false(panel.visible)
	assert_almost_eq(panel.modulate.a, 0.0, 0.01)


func test_flash_message_auto_hides_after_hold_duration() -> void:
	_bar.flash_message("첫 처치! 경험치 +5", 2.0)
	_bar._process(0.3)  ## 페이드인 완료
	assert_true(_bar.is_flashing())
	_bar._process(2.0)  ## hold_sec 경과 -> 페이드아웃 시작
	_bar._process(0.3)  ## 페이드아웃 완료
	assert_false(_bar.is_flashing())
	assert_false(_bar.get_node("Panel").visible)
