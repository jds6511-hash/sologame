extends RefCounted


static func install(world: Node2D) -> void:
	if world.map_id != "durgan_training" or world.has_node("JobTrialManager"):
		return
	var manager := preload("res://scripts/content/job_trial_manager.gd").new()
	manager.name = "JobTrialManager"
	world.add_child(manager)
	manager.start(world)
	var rally := preload("res://scripts/content/job_trial_rally.gd").new()
	rally.npc_id = "job_trial_rally"
	rally.position = Vector2(224, 352)
	world.add_child(rally)
	world._name_label(rally, "훈련 시작 / 재개")
	rally.setup(world.get_node("Player"), world.get_node("QuestController"), world.get_node("QuestDialog"), world.get_node("Hud"))
	rally.configure(manager)
	world.get_node("WorldInteraction").candidates.append(rally)
