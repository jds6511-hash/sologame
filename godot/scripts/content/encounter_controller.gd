## 영구 진척은 저널에만 둔다. 압박·소환 개체는 보상 경로에 연결하지 않는다.
extends Node
const Content = preload("res://scripts/content/game_content.gd")
const MAX_ACTIVE := 4
var world: Node2D
var definitions: Dictionary = {}
var active := false
var source := ""
var elapsed := 0.0
var outside := 0.0
var damage_pause := 0.0
var _busy := false
var _generation := 0
var _last_hp := 0.0
var _projectiles: Array[Node] = []


func setup(owner_world: Node2D, config: Dictionary = {}) -> void:
	world = owner_world
	definitions = config if not config.is_empty() else Content.ENCOUNTERS
	var stats = world.get_node("Player/PlayerStats")
	_last_hp = stats.current_hp
	stats.died.connect(suspend)
	stats.hp_changed.connect(_hp_changed)
	world.get_node("MonsterSpawner").child_entered_tree.connect(_track_projectile)


func _hp_changed(hp: float, _maximum: float) -> void:
	if hp < _last_hp:
		pause_for_damage()
	_last_hp = hp


func pause_for_damage() -> void:
	damage_pause = float(definitions.get(source, {}).get("hit_pause", 0.5))


func _process(delta: float) -> void:
	advance(delta)


func _available() -> bool:
	return (
		is_instance_valid(world)
		and world.is_inside_tree()
		and not world.is_queued_for_deletion()
		and not is_queued_for_deletion()
		and not get_tree().paused
		and not world.get_node("Player").is_queued_for_deletion()
		and not world.get_node("Player/PlayerStats").is_dead()
	)


func targets() -> Array:
	var result := []
	if not is_instance_valid(world):
		return result
	for child in world.get_node("MonsterSpawner").get_children():
		if child.get_meta("encounter_owner", 0) == get_instance_id():
			result.append(child)
	return result


func _remaining(id: String) -> int:
	if not definitions.has(id):
		return 0
	var data: Dictionary = definitions[id]
	if data.region != world.map_id:
		return 0
	var journal: QuestJournal = world.get_node("QuestController").journal
	var kind := "INTERACT" if data.kind == "evacuation" else "KILL"
	if not journal.expects_event(data.quest_id, kind, data.target, id):
		return 0
	return (
		journal.catalog.definitions[data.quest_id].objective_counts[data.index]
		- journal.export_state()[data.quest_id].counts[data.index]
	)


func can_resume(id: String) -> bool:
	if not _available() or _busy or active or _remaining(id) <= 0:
		return false
	if world.get_node("Player").is_input_locked:
		return false
	for child in targets():
		if child.is_queued_for_deletion():
			return false
	return _capacity() > 0


func _capacity() -> int:
	var occupied := 0
	for child in world.get_node("MonsterSpawner").get_children():
		if child is MonsterBase and (not child.is_dead() or child.is_queued_for_deletion()):
			occupied += 1
	return maxi(0, MAX_ACTIVE - occupied)


func resume(id: String) -> bool:
	if not can_resume(id):
		return false
	_busy = true
	source = id
	_generation += 1
	active = true
	elapsed = 0.0
	outside = 0.0
	damage_pause = 0.0
	var data: Dictionary = definitions[id]
	var living := 0
	for child in targets():
		if not child.is_dead() and child.get_meta("spawn_source_id", "") == id:
			living += 1
	var desired := 2 if data.kind == "evacuation" else _remaining(id)
	var count := mini(maxi(0, desired - living), _capacity())
	for index in count:
		_spawn(
			data, id, data.points[(living + index) % data.points.size()], data.kind != "evacuation"
		)
	_busy = false
	return true


func _spawn(data: Dictionary, id: String, point: Vector2, rewarded: bool) -> MonsterBase:
	var monster: MonsterBase = load("res://scenes/monsters/%s.tscn" % data.scene).instantiate()
	monster.stats = load(data.stats)
	monster.target = world.get_node("Player")
	monster.position = point
	monster.set_meta("encounter_owner", get_instance_id())
	monster.set_meta("spawn_source_id", id)
	monster.set_meta("content_id", data.content_id)
	if rewarded and Content.MONSTER_EXP_PROFILES.has(data.content_id):
		monster.set_meta(
			"kill_exp_profile", Content.EXP_PROFILES[Content.MONSTER_EXP_PROFILES[data.content_id]]
		)
	if data.kind == "boss":
		var states: Dictionary = world.get_node("QuestController").journal.export_state()
		monster.support_enabled = states.get("MQ-09-03", {}).get("counts", [0, 0, 0])[1] > 0
		monster.summon_requested.connect(_summon)
	world.get_node("MonsterSpawner").add_child(monster)
	if rewarded:
		world._on_monster_spawned(monster)
	# 기존 몬스터 씬은 공격 리졸버가 있다. 시련처럼 없을 때만 단독 연결한다.
	var has_resolver := false
	for child in monster.get_children():
		has_resolver = has_resolver or child is MonsterAttackResolver
	if not has_resolver:
		var resolver := MonsterAttackResolver.new()
		resolver.monster_path = NodePath("..")
		resolver.formula_data = preload("res://data/combat/damage_formula.tres")
		monster.add_child(resolver)
	monster.died.connect(_enemy_died)
	return monster


func _summon(count: int) -> void:
	# 피격 물리 질의 중에는 노드를 추가하지 않는다.
	_spawn_summons.call_deferred(count, _generation)


func _spawn_summons(count: int, generation: int) -> void:
	if generation != _generation or not active or _busy or not _available():
		return
	_busy = true
	var variant: Dictionary = Content.MONSTER_VARIANTS.demon_scout
	var data := {
		"kind": "summon", "scene": "poacher", "stats": variant.stats, "content_id": "demon_scout"
	}
	for index in mini(count, _capacity()):
		_spawn(data, source + "_summon", Vector2(560 + index * 160, 576), false)
	_busy = false


func _enemy_died() -> void:
	if not active or definitions[source].kind == "evacuation":
		return
	var living := 0
	for child in targets():
		if not child.is_dead():
			living += 1
	if _remaining(source) == 0 or (definitions[source].kind == "wave" and living == 0):
		active = false
		_cleanup()


func advance(delta: float) -> void:
	if not active or delta <= 0.0 or not _available():
		return
	if definitions[source].kind != "evacuation":
		return
	var paused := minf(delta, damage_pause)
	damage_pause = maxf(0.0, damage_pause - delta)
	var player = world.get_node("Player")
	if (
		player.position.distance_to(definitions[source].position)
		> float(definitions[source].get("radius", 48.0))
	):
		outside += delta
		if outside > float(definitions[source].get("outside_reset", 0.5)):
			elapsed = 0.0
		return
	outside = 0.0
	if player.is_input_locked:
		return
	var duration := float(definitions[source].get("duration", 8.0))
	elapsed = minf(duration, elapsed + delta - paused)
	if elapsed >= duration:
		var data: Dictionary = definitions[source]
		world.get_node("QuestController").journal.record_event("INTERACT", data.target, source, 0)
		active = false
		_cleanup()


func _track_projectile(child: Node) -> void:
	if active and not child is MonsterBase and child.has_method("launch"):
		_projectiles.append(child)


func _cleanup() -> void:
	for projectile in _projectiles:
		if is_instance_valid(projectile):
			projectile.process_mode = Node.PROCESS_MODE_DISABLED
			projectile.queue_free()
	_projectiles.clear()
	for child in targets():
		child.set_physics_process(false)
		child.set_process(false)
		if child.has_method("suspend"):
			child.suspend()
		for connection in child.attack_landed.get_connections():
			child.attack_landed.disconnect(connection.callable)
		child.queue_free()


func suspend() -> void:
	_generation += 1
	active = false
	elapsed = 0.0
	outside = 0.0
	damage_pause = 0.0
	_cleanup()
