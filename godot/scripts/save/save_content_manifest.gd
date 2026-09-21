extends RefCounted

# 명시적 콘텐츠 목록: 저장 파일의 경로로 load하지 않는다.
const ITEMS := [
	preload("res://data/items/acc_neck_10_b.tres"),
	preload("res://data/items/acc_ring_10_b.tres"),
	preload("res://data/items/arm_body_01_b.tres"),
	preload("res://data/items/arm_body_01_c.tres"),
	preload("res://data/items/arm_body_10_b.tres"),
	preload("res://data/items/arm_foot_01_b.tres"),
	preload("res://data/items/arm_foot_01_c.tres"),
	preload("res://data/items/arm_foot_10_c.tres"),
	preload("res://data/items/arm_head_01_b.tres"),
	preload("res://data/items/arm_head_01_c.tres"),
	preload("res://data/items/arm_head_10_c.tres"),
	preload("res://data/items/arm_leg_01_b.tres"),
	preload("res://data/items/arm_leg_01_c.tres"),
	preload("res://data/items/arm_leg_10_c.tres"),
	preload("res://data/items/mat_dog_fang.tres"),
	preload("res://data/items/mat_highwayman_badge.tres"),
	preload("res://data/items/mat_imp_horn.tres"),
	preload("res://data/items/mat_outlaw_mark.tres"),
	preload("res://data/items/mat_poacher_pelt.tres"),
	preload("res://data/items/mat_rabbit_foot.tres"),
	preload("res://data/items/mat_slime_core.tres"),
	preload("res://data/items/mat_spider_silk.tres"),
	preload("res://data/items/pot_hp_1.tres"),
	preload("res://data/items/pot_hp_2.tres"),
	preload("res://data/items/wpn_bw_10_b.tres"),
	preload("res://data/items/wpn_bw_10_c.tres"),
	preload("res://data/items/wpn_bw_20_b.tres"),
	preload("res://data/items/wpn_bw_20_c.tres"),
	preload("res://data/items/wpn_bw_30_b.tres"),
	preload("res://data/items/wpn_bw_30_c.tres"),
	preload("res://data/items/wpn_gs_01_b.tres"),
	preload("res://data/items/wpn_gs_01_c.tres"),
	preload("res://data/items/wpn_gs_10_b.tres"),
	preload("res://data/items/wpn_gs_10_c.tres"),
	preload("res://data/items/wpn_gs_20_b.tres"),
	preload("res://data/items/wpn_gs_20_c.tres"),
	preload("res://data/items/wpn_gs_30_b.tres"),
	preload("res://data/items/wpn_gs_30_c.tres"),
	preload("res://data/items/wpn_gs_40_b.tres"),
	preload("res://data/items/wpn_gs_40_c.tres"),
	preload("res://data/items/wpn_sw_01_b.tres"),
	preload("res://data/items/wpn_sw_01_c.tres"),
]
const SKILLS := {
	"skill_secondary_aim_mode":
	preload("res://data/player/skills/archer/skill_secondary_aim_mode.tres"),
	"skill_slot4_rapid_shot":
	preload("res://data/player/skills/archer/skill_slot4_rapid_shot.tres"),
	"skill_slote_hawk_eye": preload("res://data/player/skills/archer/skill_slote_hawk_eye.tres"),
	"skill_slotq_acrobatic_shot":
	preload("res://data/player/skills/archer/skill_slotq_acrobatic_shot.tres"),
	"skill_ultimate_piercing_burst":
	preload("res://data/player/skills/archer/skill_ultimate_piercing_burst.tres"),
	"skill_secondary_execution":
	preload("res://data/player/skills/gladiator/skill_secondary_execution.tres"),
	"skill_slot4_whirlwind":
	preload("res://data/player/skills/gladiator/skill_slot4_whirlwind.tres"),
	"skill_slote_blood_shout":
	preload("res://data/player/skills/gladiator/skill_slote_blood_shout.tres"),
	"skill_slotq_charge_slam":
	preload("res://data/player/skills/gladiator/skill_slotq_charge_slam.tres"),
	"skill_secondary_charged_smash":
	preload("res://data/player/skills/skill_secondary_charged_smash.tres"),
	"skill_slot1_strike": preload("res://data/player/skills/skill_slot1_strike.tres"),
	"skill_slot2_sprint": preload("res://data/player/skills/skill_slot2_sprint.tres"),
	"skill_slot3_first_aid": preload("res://data/player/skills/skill_slot3_first_aid.tres"),
	"skill_slot4_crushing_blow": preload("res://data/player/skills/skill_slot4_crushing_blow.tres"),
	"skill_slote_battle_shout": preload("res://data/player/skills/skill_slote_battle_shout.tres"),
	"skill_slotq_charge_rush": preload("res://data/player/skills/skill_slotq_charge_rush.tres"),
	"skill_ultimate_earth_smash":
	preload("res://data/player/skills/skill_ultimate_earth_smash.tres"),
}
