extends GutTest

const JOB = preload("res://data/jobs/job_def_sharpshooter.tres")
const ARCHER = preload("res://data/jobs/job_def_archer.tres")
const GLADIATOR = preload("res://data/jobs/job_def_gladiator.tres")


func test_inherits_archer_controls_and_growth_without_new_keys() -> void:
	assert_eq(JOB.job_id, &"sharpshooter")
	assert_eq(JOB.required_job_id, &"archer")
	assert_eq(JOB.transition_level(), 40)
	assert_same(JOB.growth, ARCHER.growth)
	assert_same(JOB.basic_combo, ARCHER.basic_combo)
	assert_same(JOB.skill_charge, ARCHER.skill_charge)
	assert_same(JOB.sprite_frames, ARCHER.sprite_frames)
	for slot in ["skill_slot_1", "skill_slot_2", "skill_slot_3"]:
		assert_same(JOB.get(slot), ARCHER.get(slot))
	assert_eq(JOB.skill_loadout().size(), ARCHER.skill_loadout().size())


func test_two_weapon_grants_follow_level_forty_b_formula() -> void:
	for job in [JOB, GLADIATOR]:
		var item = job.granted_weapon
		assert_not_null(item)
		assert_eq(item.level_limit, 40)
		assert_eq(item.grade, 1)
		assert_eq(item.main_stat_value, 8.0 + 1.6 * 40)
		assert_eq(item.price, 180 * roundi(2.0 * pow(40, 1.5)))
	assert_eq(JOB.granted_weapon.item_id, "WPN-BW-40-B")
	assert_eq(GLADIATOR.granted_weapon.item_id, "WPN-GS-40-B")


func test_sharpshooter_data_has_fixed_costs_and_bounded_charge() -> void:
	var rapid = JOB.skill_slot_4
	assert_eq(rapid.projectile_count, 3)
	assert_eq(rapid.projectile_interval_sec, 0.12)
	assert_eq(rapid.damage_coefficient, 0.8)
	assert_eq(rapid.focus_charge_cap, 10)
	var retreat = JOB.skill_slot_q
	assert_eq(retreat.projectile_count, 1)
	assert_eq(retreat.damage_coefficient, 1.2)
	assert_eq(retreat.focus_charge_cap, 10)
	var breathing = JOB.skill_slot_e
	assert_true(breathing.grants_breathing)
	assert_eq(breathing.buff_duration_sec, 6.0)
	assert_eq(breathing.aim_move_speed_multiplier, 0.8)
	assert_eq(breathing.self_heal_percent, 0.0)
	var pierce = JOB.skill_ultimate
	assert_eq(pierce.damage_coefficient, 2.5)
	assert_eq(pierce.arrow.pierce_count, 3)
	assert_eq(pierce.focus_charge_cap, 0)
	assert_eq(pierce.focus_cost, 50)
	assert_eq(pierce.hitstop_preset, "강")
	var skills = [rapid, retreat, breathing, pierce]
	var costs = [18, 16, 20, 28]
	var cooldowns = [6.0, 8.0, 14.0, 12.0]
	for index in skills.size():
		assert_eq(skills[index].fixed_mp_cost, costs[index])
		assert_eq(skills[index].mp_cost_percent, 0.0)
		assert_eq(skills[index].cooldown_sec, cooldowns[index])
