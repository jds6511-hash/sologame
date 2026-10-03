# gdlint: disable=max-returns
extends RefCounted

const QUIET_SECONDS := 5.0
const ENEMY_DISTANCE := 160.0


static func blocked_reason(world: Node) -> String:
	var quests := world.get_node_or_null("QuestController") as QuestController
	if quests != null and quests.is_reward_busy():
		return "reward_busy"
	var encounter := world.get_node_or_null("EncounterController")
	if encounter != null and bool(encounter.get("active")):
		return "encounter_active"
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
		if enemy_blocks_save(enemy, player.global_position):
			return "enemy_nearby"
	return ""


## 실패 안내용 읽기 전용 정보. 저장 허용 판정/반경은 blocked_reason과 동일하다.
static func nearby_enemy_details(world: Node) -> Dictionary:
	var player := world.get_node_or_null("Player") as Node2D
	var spawner := world.get_node_or_null("MonsterSpawner")
	if player == null or spawner == null:
		return {}
	var closest := ENEMY_DISTANCE
	var detail := {}
	for enemy in spawner.get_children():
		if not enemy_blocks_save(enemy, player.global_position):
			continue
		var offset: Vector2 = enemy.global_position - player.global_position
		if offset.length() >= closest:
			continue
		closest = offset.length()
		var label := "주변 개체"
		if enemy is MonsterBase and enemy.stats != null:
			label = enemy.stats.display_name
		detail = {"name": label, "distance": closest, "offset": offset}
	return detail


static func enemy_blocks_save(enemy: Node, position: Vector2) -> bool:
	if enemy is MonsterBase:
		return enemy.blocks_save_from(position, ENEMY_DISTANCE)
	return enemy is Node2D and enemy.global_position.distance_to(position) < ENEMY_DISTANCE
