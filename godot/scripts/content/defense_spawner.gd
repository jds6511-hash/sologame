extends Node
const Content = preload("res://scripts/content/game_content.gd")
const MAX_LIVING := 3
var world: Node2D


func start(owner_world: Node2D) -> void:
	world = owner_world


func can_resume() -> bool:
	return not _pending().is_empty()


func resume() -> bool:
	var pending := _pending()
	if pending.is_empty():
		return false
	var wave: Dictionary = Content.DEFENSE_WAVES[pending.source]
	for index in pending.count:
		var monster: MonsterBase = load("res://scenes/monsters/%s.tscn" % wave.scene).instantiate()
		monster.stats = load(wave.stats)
		monster.position = wave.points[(pending.living + index) % wave.points.size()]
		monster.target = world.get_node("Player")
		if "pack_id" in monster:
			monster.set("pack_id", pending.source)
		monster.set_meta("content_id", wave.content_id)
		monster.set_meta("spawn_source_id", pending.source)
		world.get_node("MonsterSpawner").add_child(monster)
		world._on_monster_spawned(monster)
	return true


func _pending() -> Dictionary:
	if not is_instance_valid(world) or world.is_queued_for_deletion() or is_queued_for_deletion():
		return {}
	if not world.is_inside_tree() or get_tree().paused:
		return {}
	var player: Node = world.get_node("Player")
	if player.is_queued_for_deletion() or player.get_node("PlayerStats").is_dead():
		return {}
	var holder: Node = world.get_node("MonsterSpawner")
	if holder.is_queued_for_deletion():
		return {}
	var journal: QuestJournal = world.get_node("QuestController").journal
	for source in Content.DEFENSE_WAVES:
		var wave: Dictionary = Content.DEFENSE_WAVES[source]
		if wave.region != world.map_id or not journal.expects_event(wave.quest_id, "KILL", wave.content_id, source):
			continue
		var living := 0
		var total := 0
		for child in holder.get_children():
			if not child is MonsterBase or child.is_dead():
				continue
			# 삭제 대기 개체도 이번 프레임에는 자리를 점유한다.
			total += 1
			if child.get_meta("spawn_source_id", "") == source:
				living += 1
		var state: Dictionary = journal.export_state()[wave.quest_id]
		var definition: QuestData = journal.catalog.definitions[wave.quest_id]
		var remaining: int = definition.objective_counts[wave.index] - state.counts[wave.index]
		var count := mini(maxi(0, remaining - living), maxi(0, MAX_LIVING - total))
		if count > 0:
			return {"source": source, "count": count, "living": living}
	return {}
