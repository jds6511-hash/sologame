extends Node

const Target = preload("res://scripts/content/job_trial_target.gd")
const CONFIG := {
	"TR-WAR-02": ["trial_war_heavy", "trial_war_guard"],
	"TR-ARC-02": ["trial_arc_near", "trial_arc_far", "trial_arc_moving"],
}
var world: Node2D
var active := false


func start(owner_world: Node2D) -> void:
	world = owner_world
	world.get_node("Player/PlayerStats").died.connect(_suspend)


func _suspend() -> void:
	active = false
	for monster in targets():
		monster.set_physics_process(false)


func targets() -> Array:
	var result := []
	for child in world.get_node("MonsterSpawner").get_children():
		if child.get_meta("trial_owner", 0) == get_instance_id():
			result.append(child)
	return result


func can_resume() -> bool:
	return not pending().is_empty()


func pending() -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree() or get_tree().paused:
		return {}
	var player: Node = world.get_node("Player")
	if player.get_node("PlayerStats").is_dead():
		return {}
	var journal: QuestJournal = world.get_node("QuestController").journal
	for id in CONFIG:
		if not journal.catalog.definitions.has(id):
			continue
		var definition: QuestData = journal.catalog.definitions[id]
		for index in CONFIG[id].size():
			var source: String = CONFIG[id][index]
			if not journal.expects_event(id, "INTERACT", "trial_target", source):
				continue
			var remaining: int = definition.objective_counts[index] - journal.export_state()[id].counts[index]
			var living := 0
			for child in targets():
				if child is MonsterBase and not child.is_dead() and child.trial_source == source:
					living += 1
			if remaining > living or not active:
				return {"source": source, "count": maxi(0, remaining - living), "living": living}
	return {}


func resume() -> bool:
	var next := pending()
	if next.is_empty():
		return false
	active = true
	for existing in targets():
		existing.set_physics_process(true)
	for index in next.count:
		var monster := Target.new()
		monster.trial_source = next.source
		monster.set_meta("spawn_source_id", next.source)
		monster.set_meta("trial_owner", get_instance_id())
		monster.stats = MonsterStatsData.new()
		monster.stats.display_name = "훈련 표적"
		monster.stats.max_hp = 180
		monster.stats.attack_power = 25
		monster.target = world.get_node("Player")
		monster.position = Vector2(352 + (next.living + index) * 64, 224)
		monster.objective_met.connect(_credit)
		world.get_node("MonsterSpawner").add_child(monster)
		# 공통 공격 리졸버만 연결한다. 처치 EXP/골드/드롭은 생성하지 않는다.
		var resolver := MonsterAttackResolver.new()
		resolver.name = "TrialAttackResolver"
		resolver.monster_path = NodePath("..")
		resolver.formula_data = preload("res://data/combat/damage_formula.tres")
		monster.add_child(resolver)
	return true


func _credit(source: String, target: Node) -> void:
	if target.get_meta("trial_owner", 0) != get_instance_id() or not target.credited:
		return
	var journal: QuestJournal = world.get_node("QuestController").journal
	for id in CONFIG:
		if journal.expects_event(id, "INTERACT", "trial_target", source):
			journal.record_event("INTERACT", "trial_target", source, 0)
			return
