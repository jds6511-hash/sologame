extends "res://scripts/chapter_two/m7_spawner.gd"


func start(owner_world: Node2D) -> void:
	world = owner_world
	var layout = load("res://scripts/chapter_two_closure/closure_layout.gd")
	for source in layout.HABITATS:
		for point in layout.HABITATS[source]:
			var slot := {"point": point, "source": source, "monster": null, "wait": 0.0}
			slots.append(slot)
			_spawn(slot)
