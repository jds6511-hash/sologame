# gdlint: disable=max-returns
extends RefCounted

const QUIET_SECONDS := 5.0
const ENEMY_DISTANCE := 160.0


static func blocked_reason(world: Node) -> String:
	var player := world.get_node_or_null("Player") as PlayerController
	var spawner := world.get_node_or_null("MonsterSpawner")
	if player == null or spawner == null:
		return "unsupported_world"
	var stats := player.get_node_or_null("PlayerStats") as PlayerStatsComponent
	var death := player.get_node_or_null("PlayerDeathSequence") as PlayerDeathSequence
	if stats == null or death == null:
		return "unsupported_world"
	if death.is_active():
		return "death_sequence"
	var reason := stats.save_block_reason(QUIET_SECONDS)
	if not reason.is_empty():
		return reason
	reason = player.save_block_reason()
	if not reason.is_empty():
		return reason
	for enemy in spawner.get_children():
		if (
			enemy is Node2D
			and enemy.global_position.distance_to(player.global_position) < ENEMY_DISTANCE
		):
			return "enemy_nearby"
	return ""
