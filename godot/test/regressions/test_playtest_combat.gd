extends GutTest
## 실제 교전 오류와 히트스톱의 물리 이동 경계를 고정한다.
const PLAYER := preload("res://scenes/player/player.tscn")
const IMP := preload("res://scenes/monsters/imp.tscn")


func test_melee_pose_tracks_hitbox_phase_and_survives_facing_change() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	player._start_attack_step(0)
	player._update_visual()
	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	await wait_seconds(0.12)
	assert_eq(sprite.frame, 0, "선딜 타이머가 멈추면 검도 치켜든 상태 유지")
	player._process_attack_state(player.combo_data.steps[0].startup_sec)
	player._update_visual()
	assert_eq(sprite.frame, 1, "판정 시작과 타격 그림이 일치")
	player.get_node("Facing").rotation = PI / 2.0
	player._update_visual()
	assert_eq(sprite.frame, 1, "방향 전환이 선딜 그림으로 되감기지 않음")
	player._process_attack_state(player.combo_data.steps[0].active_sec)
	player._update_visual()
	assert_eq(sprite.frame, 2, "판정 종료와 회수 그림이 일치")
	player._end_combo()
	player._update_visual()
	assert_true(sprite.is_playing(), "공격 종료 후 대기 애니메이션 재생 복구")


func test_archer_release_pose_starts_with_projectile_phase() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var job = load("res://data/jobs/job_def_archer.tres")
	player.visual.set_job_sprite_frames(job.sprite_frames)
	player.combo_data = load("res://data/player/archer_basic_combo.tres")
	player._start_attack_step(0)
	player._attack_phase_timer = 0.15
	player._update_visual()
	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	assert_eq(sprite.frame, 1, "선딜 후반은 완전히 당긴 활")
	player.attack_state = PlayerController.AttackState.ACTIVE
	player._attack_phase_timer = 0.0
	player._update_visual()
	assert_eq(sprite.frame, 2, "화살 발사 단계에서 시위를 놓음")
	player.attack_state = PlayerController.AttackState.RECOVERY
	player._update_visual()
	assert_eq(sprite.frame, 3, "후딜에 화살을 다시 물리지 않음")


func after_each() -> void:
	Engine.time_scale = 1.0


func test_charge_release_and_gladiator_skills_follow_actual_phase() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	var skills := [
		"res://data/player/skills/skill_secondary_charged_smash.tres",
		"res://data/player/skills/gladiator/skill_secondary_execution.tres",
		"res://data/player/skills/gladiator/skill_slot4_whirlwind.tres",
		"res://data/player/skills/gladiator/skill_slotq_charge_slam.tres"
	]
	for path in skills:
		var skill = load(path)
		player._skills.begin_active(skill)
		player._update_visual()
		assert_eq(sprite.frame, 1, "%s: 즉시 판정은 선딜 그림 생략" % skill.skill_name)
		player._skills.process_state(skill.get_active_duration_sec())
		player._update_visual()
		assert_eq(sprite.frame, 2, "%s: 판정 종료 후 회수" % skill.skill_name)
		player._skills.process_state(skill.recovery_sec * 0.75)
		player._update_visual()
		assert_eq(sprite.frame, 3, "%s: 후딜 후반 마지막 자세" % skill.skill_name)
		player._skills.finish()


func test_repeated_hits_connect_death_effect_once_even_after_target_moves() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var enemy: MonsterBase = IMP.instantiate()
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy.hp = 10000.0
	var resolver := player.get_node("AttackResolver") as PlayerAttackResolver
	resolver.preset_weak = null
	resolver.preset_medium = null
	resolver.preset_strong = null
	var step := player.combo_data.steps[0]
	resolver._on_attack_hit(step, enemy)
	resolver._on_attack_hit(step, enemy)
	enemy.global_position += Vector2(16, 0)
	resolver._on_attack_hit(step, enemy)
	var own_connections := 0
	for connection in enemy.died.get_connections():
		if connection.callable.get_object() == resolver:
			own_connections += 1
	assert_eq(own_connections, 1, "위치가 변해도 사망 효과 구독은 한 번")


func test_hitstop_blocks_zero_delta_motion_and_restores_afterwards() -> void:
	var player: PlayerController = PLAYER.instantiate()
	add_child_autofree(player)
	var enemy: MonsterBase = IMP.instantiate()
	add_child_autofree(enemy)
	await wait_physics_frames(2)
	Engine.time_scale = 0.0
	assert_false(player._guard_finite_before_move())
	assert_false(enemy._guard_finite_before_move())
	await get_tree().create_timer(0.05, true, false, true).timeout
	assert_true(player.global_position.is_finite())
	assert_true(enemy.global_position.is_finite())
	Engine.time_scale = 1.0
	await wait_physics_frames(2)
	assert_true(player._guard_finite_before_move())
	assert_true(enemy._guard_finite_before_move())
