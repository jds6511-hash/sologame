## UI-1 검증 — HUD(hud.tscn)의 자식 요소 구성과 PlayerStatsComponent 연동을 재현한다.
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _hud: Hud


func _spawn_player() -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/hud.tscn")
	_hud = scene.instantiate()
	add_child_autofree(_hud)


func test_hud_has_expected_child_elements() -> void:
	assert_not_null(_hud.get_node_or_null("PlayerStatusPanel"), "A요소(플레이어 상태 패널)")
	assert_not_null(_hud.get_node_or_null("Minimap"), "B요소(미니맵)")
	assert_not_null(_hud.get_node_or_null("GameTimeDisplay"), "C요소(게임 내 시간)")
	assert_not_null(_hud.get_node_or_null("SkillSlotBar"), "F요소(스킬 슬롯 바)")
	assert_not_null(_hud.get_node_or_null("InteractionPrompt"), "I요소(상호작용 프롬프트)")
	assert_not_null(_hud.get_node_or_null("ExpBar"), "J요소(경험치 바)")


func test_game_time_shows_dummy_default() -> void:
	var time_label: Label = _hud.get_node("GameTimeDisplay/HBox/TimeLabel")
	assert_eq(time_label.text, "1일차 14:30")


func test_set_exp_ratio_resizes_fill() -> void:
	var exp_bar_width: float = _hud.get_node("ExpBar").size.x
	_hud.set_exp_ratio(0.5)
	var fill: ColorRect = _hud.get_node("ExpBar/Fill")
	assert_almost_eq(fill.size.x, exp_bar_width * 0.5, 0.5)


func test_interaction_prompt_show_and_hide() -> void:
	_hud.show_interaction_prompt("대화", Vector2(100, 100))
	var prompt: InteractionPrompt = _hud.get_node("InteractionPrompt")
	assert_true(prompt.visible)
	assert_eq(prompt.text, "[F] 대화")
	_hud.hide_interaction_prompt()
	assert_false(prompt.visible)


func test_bind_player_syncs_initial_hp_mp() -> void:
	var player: PlayerController = _spawn_player()
	var stats: PlayerStatsComponent = player.get_node("PlayerStats")

	_hud.bind_player(player, stats)

	var hp_label: Label = _hud.get_node("PlayerStatusPanel/HPBar/Label")
	var expected := "%d/%d" % [roundi(stats.current_hp), roundi(stats.stats.max_hp)]
	assert_eq(hp_label.text, expected)


func test_bind_player_hp_changed_signal_updates_label() -> void:
	var player: PlayerController = _spawn_player()
	var stats: PlayerStatsComponent = player.get_node("PlayerStats")
	_hud.bind_player(player, stats)

	stats.take_damage(30.0)

	var hp_label: Label = _hud.get_node("PlayerStatusPanel/HPBar/Label")
	var expected := "%d/%d" % [roundi(stats.current_hp), roundi(stats.stats.max_hp)]
	assert_eq(hp_label.text, expected)
