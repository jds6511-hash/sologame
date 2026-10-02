extends Node
const Content = preload("res://scripts/content/game_content.gd")
var world: Node2D
var slots: Array[Dictionary] = []


func start(owner_world: Node2D) -> void:
	world = owner_world
	for source in Content.HABITATS:
		if Content.HABITATS[source][0] != world.map_id:
			continue
		for point in Content.HABITATS[source][1]:
			var slot := {"point": point, "source": source, "monster": null, "wait": 0.0}
			slots.append(slot)
			_spawn(slot)


func _process(delta: float) -> void:
	if not is_instance_valid(world) or world.is_queued_for_deletion():
		return
	for slot in slots:
		if is_instance_valid(slot.monster):
			continue
		slot.wait += delta
		if (
			slot.wait >= 30
			and world.get_node("Player").global_position.distance_to(slot.point) > 160
		):
			_spawn(slot)


func _spawn(slot: Dictionary) -> void:
	var dog: bool = Content.HABITATS[slot.source][3] == "feral_dog"
	var scene: String = Content.HABITATS[slot.source][2]
	var monster: MonsterBase = load("res://scenes/monsters/%s.tscn" % scene).instantiate()
	monster.position = slot.point
	monster.target = world.get_node("Player")
	if dog:
		monster.set("pack_id", "m7_solo_%s" % str(slot.point))
	monster.set_meta("content_id", Content.HABITATS[slot.source][3])
	monster.set_meta("spawn_source_id", slot.source)
	# 저장 안전 판정·전투 소비자는 기존 MonsterSpawner의 자식을 읽는다.
	world.get_node("MonsterSpawner").add_child(monster)
	world._on_monster_spawned(monster)
	slot.monster = monster
	slot.wait = 0.0
