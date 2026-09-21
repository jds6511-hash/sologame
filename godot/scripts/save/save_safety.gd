# gdlint: disable=max-returns
extends RefCounted

const QUIET_SECONDS := 5.0
const ENEMY_DISTANCE := 160.0


static func blocked_reason(world: Node) -> String:
	var player = world.get_node("Player")
	var stats = player.get_node("PlayerStats")
	if stats.is_dead() or player.get_node("PlayerDeathSequence").is_active():
		return "death_sequence"
	if player.is_input_locked or player.is_hit_stunned or player.is_hit_invincible:
		return "player_locked"
	if player.attack_state != 0 or player.skill_state != 0 or player.is_dashing:
		return "action_in_progress"
	if (
		player._is_charging_secondary
		or player._shots.is_aiming
		or player._shots._burst_remaining > 0
	):
		return "action_in_progress"
	if player.velocity.length_squared() > 1.0:
		return "moving"
	if stats._time_since_combat_action_sec < QUIET_SECONDS:
		return "recent_combat"
	for timer in [
		stats._potion_cooldown_timer,
		stats._defense_buff_timer,
		player._skills._secondary_cooldown,
		player._shots._buff_timer,
		player._move_slow_timer,
		player._buff_superarmor_timer,
		player.rage._buff_timer
	]:
		if timer > 0.0:
			return "cooldown_or_buff"
	if not player._dash_recharge_timers.is_empty():
		return "cooldown_or_buff"
	for remaining in player._skills._cooldowns.values():
		if remaining > 0.0:
			return "cooldown_or_buff"
	for enemy in world.get_node("MonsterSpawner").get_children():
		if (
			enemy is Node2D
			and enemy.global_position.distance_to(player.global_position) < ENEMY_DISTANCE
		):
			return "enemy_nearby"
	return ""
