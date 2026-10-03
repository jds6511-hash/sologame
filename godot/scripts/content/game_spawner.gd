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
		var content_id: String = Content.HABITATS[slot.source][3]
		var respawn := 30.0
		if Content.MONSTER_EXP_PROFILES.has(content_id):
			respawn = Content.EXP_PROFILES[Content.MONSTER_EXP_PROFILES[content_id]].respawn_seconds
		if (
			slot.wait >= respawn
			and world.get_node("Player").global_position.distance_to(slot.point) > 160
		):
			_spawn(slot)


func _spawn(slot: Dictionary) -> void:
	var dog: bool = Content.HABITATS[slot.source][3] == "feral_dog"
	var scene: String = Content.HABITATS[slot.source][2]
	var monster: MonsterBase = load("res://scenes/monsters/%s.tscn" % scene).instantiate()
	var content_id: String = Content.HABITATS[slot.source][3]
	if Content.MONSTER_VARIANTS.has(content_id):
		monster.stats = load(Content.MONSTER_VARIANTS[content_id].stats)
		# 임시 아트도 계열을 구별한다. 하피는 지형 충돌을 유지하는 도약 접근형이다.
		if content_id == "wild_boar":
			monster.modulate = Color("ad815d")
		elif content_id == "cursed_scarecrow":
			monster.modulate = Color("dfbd63")
		elif content_id == "cliff_harpy":
			monster.modulate = Color("91bcec")
	monster.position = slot.point
	monster.target = world.get_node("Player")
	if dog:
		monster.set("pack_id", "m7_solo_%s" % str(slot.point))
	monster.set_meta("content_id", Content.HABITATS[slot.source][3])
	monster.set_meta("spawn_source_id", slot.source)
	if Content.MONSTER_EXP_PROFILES.has(content_id):
		monster.set_meta(
			"kill_exp_profile", Content.EXP_PROFILES[Content.MONSTER_EXP_PROFILES[content_id]]
		)
	# 저장 안전 판정·전투 소비자는 기존 MonsterSpawner의 자식을 읽는다.
	world.get_node("MonsterSpawner").add_child(monster)
	world._on_monster_spawned(monster)
	slot.monster = monster
	slot.wait = 0.0
