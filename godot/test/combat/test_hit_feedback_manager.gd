## CB-7 검증 — HitFeedback 공용 모듈이 프리셋(약/중/강)에 따라 화면 흔들림·피격 플래시
## 시그널을 올바른 값으로 발신하고, 히트스톱(Engine.time_scale)을 실시간으로 복원하는지 확인.
## 실제 셰이더/카메라 연출(CB-8)은 이 시그널을 구독하는 쪽 책임이라 본 테스트 범위 밖이다.
extends GutTest

var _weak_preset: HitFeedbackPreset
var _medium_preset: HitFeedbackPreset
var _strong_preset: HitFeedbackPreset


func before_each() -> void:
	_weak_preset = load("res://data/combat/hitfeedback_weak.tres")
	_medium_preset = load("res://data/combat/hitfeedback_medium.tres")
	_strong_preset = load("res://data/combat/hitfeedback_strong.tres")
	watch_signals(HitFeedback)


func after_each() -> void:
	Engine.time_scale = 1.0


func test_play_emits_screen_shake_with_preset_intensity() -> void:
	HitFeedback.play(_medium_preset, Vector2.ZERO)
	assert_signal_emitted_with_parameters(HitFeedback, "screen_shake_requested", [1])


func test_weak_preset_has_no_shake() -> void:
	HitFeedback.play(_weak_preset, Vector2.ZERO)
	assert_signal_emitted_with_parameters(HitFeedback, "screen_shake_requested", [0])


func test_strong_preset_has_shake_intensity_2() -> void:
	HitFeedback.play(_strong_preset, Vector2.ZERO)
	assert_signal_emitted_with_parameters(HitFeedback, "screen_shake_requested", [2])


func test_play_emits_hit_flash_only_when_target_given() -> void:
	var dummy := Node2D.new()
	add_child_autofree(dummy)
	HitFeedback.play(_weak_preset, Vector2.ZERO, dummy)
	assert_signal_emitted_with_parameters(HitFeedback, "hit_flash_requested", [dummy])


func test_play_without_target_does_not_emit_hit_flash() -> void:
	HitFeedback.play(_weak_preset, Vector2.ZERO)
	assert_signal_not_emitted(HitFeedback, "hit_flash_requested")


func test_play_with_null_preset_does_nothing() -> void:
	HitFeedback.play(null, Vector2.ZERO)
	assert_signal_not_emitted(HitFeedback, "screen_shake_requested")


func test_hitstop_restores_time_scale_after_duration() -> void:
	Engine.time_scale = 1.0
	HitFeedback.play(_strong_preset, Vector2.ZERO)  ## 강 = 0.10초 히트스톱
	assert_eq(Engine.time_scale, 0.0, "히트스톱 시작 시 즉시 0으로 낮춰야 함")
	await wait_seconds(0.15)
	assert_eq(Engine.time_scale, 1.0, "히트스톱 실시간 종료 후 원래 배속으로 복원")
