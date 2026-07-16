## CB-1 검증 — 대검 2타 콤보 데이터가 m2-warrior-skills.md 2장 표와 일치하는지 확인.
extends GutTest

const COMBO_PATH := "res://data/player/warrior_basic_combo.tres"


func test_combo_has_2_steps() -> void:
	var combo: WarriorComboData = load(COMBO_PATH)
	assert_eq(combo.steps.size(), 2)


func test_step1_matches_design_table() -> void:
	var combo: WarriorComboData = load(COMBO_PATH)
	var step1: WarriorAttackStep = combo.steps[0]
	assert_eq(step1.damage_coefficient, 1.0)
	assert_almost_eq(step1.get_total_motion_sec(), 0.50, 0.001, "선딜0.15+판정0.10+후딜0.25")
	assert_eq(step1.hitstop_preset, "약")


func test_step2_matches_design_table() -> void:
	var combo: WarriorComboData = load(COMBO_PATH)
	var step2: WarriorAttackStep = combo.steps[1]
	assert_eq(step2.damage_coefficient, 1.5)
	assert_almost_eq(step2.get_total_motion_sec(), 0.70, 0.001, "선딜0.20+판정0.15+후딜0.35")
	assert_eq(step2.hitstop_preset, "중")


func test_combo_window_is_0_6_sec() -> void:
	var combo: WarriorComboData = load(COMBO_PATH)
	assert_eq(combo.combo_window_sec, 0.6)
