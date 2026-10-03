extends GutTest

const Rules = preload("res://scripts/progression/content_kill_exp.gd")
const Content = preload("res://scripts/content/game_content.gd")


func test_profile_multiplier_and_overlevel_floor() -> void:
	var profile := {"base_exp": 1889, "overlevel_factors": [1.0, 0.5, 0.25]}
	assert_eq(Rules.gain(profile, 0, 1.0, 1.0, 1.0), 1889)
	assert_eq(Rules.gain(profile, 1, 1.0, 1.0, 1.0), 945)
	assert_eq(Rules.gain(profile, 2, 1.0, 1.0, 1.0), 472)
	assert_eq(Rules.gain(profile, 3, 2.0, 1.0, 1.2), 1)
	assert_eq(Rules.gain(profile, -5, 1.0, 1.2, 1.2), 2720)


func test_real_death_signal_uses_profile_without_changing_legacy() -> void:
	var player := PlayerProgression.new()
	player.level_curve = preload("res://data/progression/level_curve.tres")
	player.level_diff_curve = preload("res://data/progression/level_diff_curve.tres")
	player.current_level = 16
	autofree(player)
	var monster := MonsterBase.new()
	autofree(monster)
	monster.set_meta("kill_exp_profile", Content.EXP_PROFILES["4"])
	var table := DropTableData.new()
	table.monster_level = 16
	GameClock.reset()
	player.register_monster(monster, table)
	monster.died.emit()
	assert_eq(player.current_exp, 1889)
	player.current_exp = 0
	var old := MonsterBase.new()
	autofree(old)
	player.register_monster(old, table)
	old.died.emit()
	assert_eq(player.current_exp, player.level_curve.mob_exp(16))
	assert_false(Content.MONSTER_EXP_PROFILES.has("rabbit"))
