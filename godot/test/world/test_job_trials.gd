extends GutTest

const Manager = preload("res://scripts/content/job_trial_manager.gd")
const Target = preload("res://scripts/content/job_trial_target.gd")


func after_each() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	BgmManager.reset()


func freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		freeze(child)


func fixture(id: String) -> Dictionary:
	var world := Node2D.new()
	add_child_autofree(world)
	var holder := Node.new()
	holder.name = "MonsterSpawner"
	world.add_child(holder)
	var player := Node2D.new()
	player.name = "Player"
	world.add_child(player)
	var stats := PlayerStatsComponent.new()
	stats.name = "PlayerStats"
	stats.stats = CombatantStats.new()
	stats.stats.max_hp = 100
	player.add_child(stats)
	stats.set_process(false)
	var catalog := QuestCatalog.new()
	catalog.definitions.clear()
	var definition := QuestData.new()
	definition.quest_id = id
	definition.title = "시련"
	definition.offer_text = "실제 전투 시련"
	for source in Manager.CONFIG[id]:
		definition.objective_kinds.append("INTERACT")
		definition.objective_targets.append("trial_target")
		definition.objective_sources.append(source)
		definition.objective_counts.append(1 if source.ends_with("guard") or source.ends_with("moving") else 2)
		definition.objective_labels.append(source)
		definition.objective_location_hints.append("훈련장")
	catalog.definitions[id] = definition
	var journal := QuestJournal.new(catalog)
	assert_eq(journal.accept(id), "")
	var controller := QuestController.new()
	controller.name = "QuestController"
	world.add_child(controller)
	controller.setup(player, journal)
	var manager := Manager.new()
	world.add_child(manager)
	manager.start(world)
	return {"world": world, "player": player, "journal": journal, "manager": manager, "holder": holder}


func test_resume_subtracts_living_and_only_strong_finisher_counts() -> void:
	var f := fixture("TR-WAR-02")
	assert_eq(f.holder.get_child_count(), 0, "로드/설치 자체는 생성하지 않음")
	assert_true(f.manager.resume())
	assert_eq(f.holder.get_child_count(), 2)
	assert_false(f.manager.resume(), "살아 있는 표적은 중복 생성하지 않음")
	var weak: Node = f.holder.get_child(0)
	weak.take_damage(999, "중", f.player)
	assert_eq(f.journal.export_state()["TR-WAR-02"].counts, [0, 0])
	var strong: Node = f.holder.get_child(1)
	strong.take_damage(999, "강", f.player)
	assert_eq(f.journal.export_state()["TR-WAR-02"].counts, [1, 0])
	assert_eq(f.manager.pending().count, 1)
	await get_tree().process_frame
	assert_true(f.manager.resume())
	assert_eq(f.holder.get_child_count(), 1)
	f.holder.get_child(0).take_damage(999, "강", f.player)
	assert_eq(f.manager.pending().source, "trial_war_guard")
	var saved: Dictionary = f.journal.export_state()
	assert_eq(f.journal.restore_state(saved), "")
	assert_eq(f.journal.export_state()["TR-WAR-02"].counts, [2, 0])


func test_arrow_requires_actual_positive_damage_and_launch_distance() -> void:
	var f := fixture("TR-ARC-02")
	assert_true(f.manager.resume())
	var target: Node = f.holder.get_child(0)
	target.take_damage(1, "약", f.player)
	assert_eq(f.journal.export_state()["TR-ARC-02"].counts, [0, 0, 0], "근접 피해는 화살 증거 아님")
	target.set_meta("trial_arrow_distance", 65.0)
	target.take_damage(1, "약", f.player)
	assert_eq(f.journal.export_state()["TR-ARC-02"].counts, [0, 0, 0])
	target.set_meta("trial_arrow_distance", 64.0)
	target.take_damage(0, "약", f.player)
	assert_eq(f.journal.export_state()["TR-ARC-02"].counts, [0, 0, 0])
	target.take_damage(1, "약", f.player)
	target.take_damage(1, "약", f.player)
	assert_eq(f.journal.export_state()["TR-ARC-02"].counts, [1, 0, 0], "표적당 한 번")
	var far := Target.new()
	far.trial_source = "trial_arc_far"
	far.stats = MonsterStatsData.new()
	far.target = f.player
	f.holder.add_child(far)
	var valid := []
	far.objective_met.connect(func(source: String, _node: Node): valid.append(source))
	far.set_meta("trial_arrow_distance", 127.0)
	far.take_damage(1, "약", f.player)
	assert_true(valid.is_empty())
	far.set_meta("trial_arrow_distance", 128.0)
	far.take_damage(1, "약", f.player)
	assert_eq(valid, ["trial_arc_far"])


func test_death_suspends_existing_targets_until_explicit_resume() -> void:
	var f := fixture("TR-WAR-02")
	assert_true(f.manager.resume())
	var stats: PlayerStatsComponent = f.player.get_node("PlayerStats")
	stats.current_hp = 0
	stats.died.emit()
	assert_false(f.manager.can_resume())
	for target in f.manager.targets():
		assert_false(target.is_physics_processing())
	stats.current_hp = 100
	assert_true(f.manager.can_resume())
	assert_eq(f.manager.pending().count, 0, "부활 후 남은 적만 재개")
	assert_true(f.manager.resume())
	assert_eq(f.holder.get_child_count(), 2)
	for target in f.manager.targets():
		assert_true(target.is_physics_processing())


func test_product_trials_report_then_unlock_both_job_families() -> void:
	for job in [&"warrior", &"archer"]:
		var world: Node = load("res://scripts/world/game_product.gd").instantiate_world("durgan_training")
		world.set_meta("save_directory", "user://product_verify")
		add_child(world)
		freeze(world)
		var controller: QuestController = world.get_node("QuestController")
		var journal := controller.journal
		var bootstrap: Node = load("res://scripts/world/game_bootstrap.gd").new()
		var states: Dictionary = bootstrap.preparation(journal.catalog, 7).quests
		bootstrap.free()
		states["MQ-07-01"] = {"state": "completed", "counts": Array(journal.catalog.definitions["MQ-07-01"].objective_counts)}
		assert_eq(journal.restore_state(states), "")
		var player: PlayerController = world.get_node("Player")
		var transition: PlayerJobTransition = player.get_node("PlayerJobTransition")
		transition.restore_saved_job(job)
		player.get_node("PlayerProgression").current_level = 40
		transition._update_availability(40)
		var trial := "TR-WAR-02" if job == &"warrior" else "TR-ARC-02"
		var next_job: StringName = &"gladiator" if job == &"warrior" else &"sharpshooter"
		assert_false(transition.can_transition(next_job), "보고 전 승급 불가")
		assert_eq(controller.accept("TR-ARC-02" if job == &"warrior" else "TR-WAR-02"), "trial_job_required")
		var dialog: QuestDialog = world.get_node("QuestDialog")
		assert_true(dialog.open_dialog("durgan_trainer"))
		dialog._select(trial)
		dialog.choose("accept", trial)
		assert_eq(journal.export_state()[trial].state, "active")
		var manager: Node = world.get_node("JobTrialManager")
		for _stage in Manager.CONFIG[trial].size():
			assert_true(manager.resume())
			for target in manager.targets():
				if target.is_queued_for_deletion():
					continue
				target.set_physics_process(false)
				if target.trial_source in ["trial_arc_near", "trial_arc_far"]:
					var distance := 48.0 if target.trial_source == "trial_arc_near" else 160.0
					await actual_arrow(world, player, target, distance)
				else:
					target.take_damage(10000, "강", player)
			await get_tree().process_frame
		assert_eq(journal.export_state()[trial].state, "ready")
		assert_true(dialog.open_dialog("durgan_trainer"))
		dialog._select(trial)
		dialog.choose("report", trial)
		assert_eq(journal.export_state()[trial].state, "completed")
		assert_true(transition.can_transition(next_job), "실제 목표 완료와 NPC 보고 뒤 승급 가능")
		world.queue_free()
		await get_tree().process_frame


func actual_arrow(world: Node, player: PlayerController, target: Node2D, distance: float) -> void:
	var arrow: ArrowProjectile = preload("res://scenes/player/arrow_projectile.tscn").instantiate()
	world.add_child(arrow)
	arrow.global_position = target.get_node("CollisionShape2D").global_position - Vector2(distance, 0)
	var action: Resource = preload("res://data/player/archer_basic_combo.tres").steps[0]
	arrow.configure(action, preload("res://data/player/arrows/arrow_basic.tres"), 16)
	arrow.arrow_hit_landed.connect(func(step: Resource, body: Node): player.attack_hit.emit(step, body))
	arrow.launch(Vector2.RIGHT, 224)
	for _frame in 90:
		await get_tree().physics_frame
		if not is_instance_valid(target) or target.is_queued_for_deletion():
			return
	assert_true(false, "실제 화살 충돌로 표적이 완료되어야 함")
