extends SceneTree
## 실제 월드 씬 입력 주입 QA. 전투 배치는 순간이동, 사망은 피해 API로 준비한다.
## 게임 파일을 바꾸지 않는다. 실패 시 종료 코드 1, 120초 제한 초과 시 2.

const OUTPUT := "res://../docs/qa/screenshots/playtest-2026-09-11/"
var failures := 0
var checks := 0
var started := 0
var world: Node
var player: Node2D
var attack_count := 0
var hit_count := 0
var dash_count := 0
var skill_count := 0
var potion_count := 0


func _initialize() -> void:
	started = Time.get_ticks_msec()
	call_deferred("_run")


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - started > 120000:
		printerr("[시간초과] 플레이 테스트 120초 제한")
		quit(2)
	return false


func _check(label: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if not condition:
		failures += 1
	print("[검사] %s | %s | %s" % ["통과" if condition else "실패", label, detail])


func _delay(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _key(code: int, pressed: bool, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.shift_pressed = shift
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(code: int, shift: bool = false) -> void:
	if code == KEY_F:
		# 줍기는 _process에서 just_pressed를 읽는다. 해당 프레임 처리 전에 주입한다.
		await process_frame
	_key(code, true, shift)
	await _delay(0.08)
	_key(code, false, shift)
	await _delay(0.08)


func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = root.get_final_transform() * root.get_mouse_position()
	Input.parse_input_event(event)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path(OUTPUT).simplify_path()
	DirAccess.make_dir_recursive_absolute(directory)
	var result := root.get_texture().get_image().save_png(directory.path_join(label + ".png"))
	_check("화면 저장 " + label, result == OK)


func _load_world(path: String) -> void:
	paused = false
	if is_instance_valid(world):
		world.queue_free()
		await process_frame
	world = load(path).instantiate()
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player")
	player.attack_step_started.connect(func(_i, _p): attack_count += 1)
	player.attack_hit.connect(func(_step, _target): hit_count += 1)
	player.dash_started.connect(func(): dash_count += 1)
	player.skill_used.connect(func(_name): skill_count += 1)
	player.get_node("PlayerStats").potion_used.connect(func(_amount): potion_count += 1)
	await _delay(1.0)
	_check("월드 로드", world.get_node("MonsterSpawner").get_child_count() > 0, path)


func _run() -> void:
	seed(20260911)
	if "--combat-only" in OS.get_cmdline_user_args():
		await _load_world("res://scenes/world/m3_new_enemy_field.tscn")
		await _enemy_checks()
		quit(0 if failures == 0 else 1)
		return
	await _load_world("res://scenes/world/eastern_frontier_starting_area.tscn")
	await _capture("01-start")
	var origin := player.global_position
	_key(KEY_D, true)
	await _delay(0.6)
	_key(KEY_D, false)
	var distance := player.global_position.distance_to(origin)
	_check("D 이동", distance > 20.0, "이동량 %.2f px" % distance)
	await _tap(KEY_SPACE)
	_check("Space 회피", dash_count == 1, "남은 충전 %d" % player.dash_charges)
	await _delay(0.5)
	_mouse(true)
	await _delay(2.5)
	_mouse(false)
	_check("좌클릭 홀드 연속 공격", attack_count >= 2, "스윙 %d회" % attack_count)
	await _delay(0.8)
	await _tap(KEY_1)
	_check("1번 강타 시전", skill_count > 0)
	await _delay(1.0)
	await _menu_checks()
	await _potion_and_death()
	await _job_checks()
	await _load_world("res://scenes/world/m3_new_enemy_field.tscn")
	await _enemy_checks()
	print(
		(
			"[최종] 검사 %d / 실패 %d / 경과 %.1f초"
			% [checks, failures, (Time.get_ticks_msec() - started) / 1000.0]
		)
	)
	quit(0 if failures == 0 else 1)


func _menu_checks() -> void:
	var menu := world.get_node("IntegratedMenu")
	var codes := [KEY_I, KEY_C, KEY_K, KEY_J, KEY_M, KEY_B]
	for index in codes.size():
		await _tap(codes[index])
		_check(
			"메뉴 탭 %d" % index,
			menu.is_open() and paused and menu.get_node("Tabs").current_tab == index
		)
		if index == 1:
			await _capture("02-character")
		if index == 2:
			await _capture("03-skills")
	var before := player.global_position
	_key(KEY_D, true)
	await _delay(0.4)
	_key(KEY_D, false)
	_check("메뉴 중 이동 정지", player.global_position.is_equal_approx(before))
	await _tap(KEY_ESCAPE)
	_check("ESC 메뉴 복귀", not menu.is_open() and not paused)


func _potion_and_death() -> void:
	var stats := player.get_node("PlayerStats")
	var inventory := player.get_node("Inventory")
	_check("물약 재현 시작 재고 0", inventory.bag.is_empty())
	stats.take_damage(stats.stats.max_hp * 0.6)
	await _delay(0.8)
	var hp_before: float = stats.current_hp
	await _tap(KEY_5)
	_check(
		"재고 0이면 5번 물약 사용 불가",
		potion_count == 0,
		(
			"HP %.1f → %.1f, 사용 시그널 %d, 가방 %d칸"
			% [hp_before, stats.current_hp, potion_count, inventory.bag.size()]
		)
	)
	inventory.add_gold(1000)
	stats.take_damage(stats.stats.max_hp * 10.0)
	_check("치명 피해 후 사망·입력 차단", stats.is_dead() and player.is_input_locked)
	await _tap(KEY_I)
	_check("사망 중 메뉴 차단", not world.get_node("IntegratedMenu").is_open() and not paused)
	await _delay(4.0)
	_check(
		"부활·입력 잠금 해제",
		not stats.is_dead() and not player.is_input_locked,
		(
			"HP %.1f/%.1f, MP %.1f/%.1f"
			% [stats.current_hp, stats.stats.max_hp, stats.current_mp, stats.stats.max_mp]
		)
	)
	_check("시작 지점 부활", player.global_position.distance_to(stats.get_respawn_position()) < 1.0)
	_check("사망 골드 패널티", inventory.gold == 950, "잔액 %d" % inventory.gold)
	await _capture("04-respawn")
	var item: Node2D = load("res://scenes/items/world_item.tscn").instantiate()
	item.item_data = load("res://data/items/pot_hp_1.tres")
	world.add_child(item)
	item.global_position = player.global_position
	await _delay(0.2)
	await _tap(KEY_F)
	_check(
		"F로 근처 물약 줍기",
		not is_instance_valid(item) and inventory.bag.size() == 1,
		"테스트 도구가 플레이어 위치에 물약 1개 생성"
	)
	if is_instance_valid(item):
		print(
			(
				"[줍기 원인] 아이템 mask=%d, 플레이어 layer=%d, 감지=%d"
				% [
					item.collision_mask,
					player.collision_layer,
					item.get_overlapping_bodies().size()
				]
			)
		)
		item.collision_mask = player.collision_layer
		item.global_position += Vector2(64, 0)
		await _delay(0.2)
		item.global_position = player.global_position
		await _delay(0.2)
		print(
			(
				"[줍기 대조군 준비] 감지=%d, 인벤토리 연결=%s"
				% [item.get_overlapping_bodies().size(), item.get("_nearby_inventory") != null]
			)
		)
		await _tap(KEY_F)
		print(
			(
				"[줍기 대조군 결과] 월드 아이템 잔존=%s, 보유수량=%d"
				% [is_instance_valid(item), inventory.get_bag_quantity("POT-HP-1")]
			)
		)
		_check(
			"줍기 대조군: 테스트 인스턴스 감지 마스크만 수정",
			not is_instance_valid(item) and inventory.get_bag_quantity("POT-HP-1") == 1
		)


func _job_checks() -> void:
	var progression := player.get_node("PlayerProgression")
	var transition := player.get_node("PlayerJobTransition")
	await _tap(KEY_PAGEUP, true)
	_check("Shift+PageUp 10레벨 상승", progression.current_level == 11)
	await _tap(KEY_F11)
	_check("F11 전사 전직", transition.current_job_id == &"warrior", str(transition.current_job_id))
	for _index in 3:
		await _tap(KEY_PAGEUP, true)
	await _tap(KEY_F11)
	_check(
		"F11 2차 검투사 전직", transition.current_job_id == &"gladiator", str(transition.current_job_id)
	)
	await _capture("05-gladiator")


func _enemy_checks() -> void:
	var progression := player.get_node("PlayerProgression")
	var stats := player.get_node("PlayerStats")
	await _tap(KEY_PAGEUP, true)
	await _tap(KEY_F12)
	_check("F12 궁수 전직", player.get_node("PlayerJobTransition").current_job_id == &"archer")
	var target: Node2D
	for monster in world.get_node("MonsterSpawner").get_children():
		if monster.scene_file_path.ends_with("/imp.tscn"):
			target = monster
			break
	if target == null:
		_check("전투 대상 임프 존재", false)
		return
	print("[전투 준비] 순간이동으로 임프와 48px 거리 배치, 능력치·적 AI 원본 유지")
	player.global_position = target.global_position + Vector2(-48, 0)
	await _delay(0.2)
	var hp_before: float = stats.current_hp
	var hits_before := hit_count
	var xp_before: int = progression.current_exp
	var gold_before: int = player.get_node("Inventory").gold
	_mouse(true)
	for _index in 60:
		if is_instance_valid(target) and not target.is_dead():
			var motion := InputEventMouseMotion.new()
			motion.position = (
				root.get_final_transform() * target.get_global_transform_with_canvas().origin
			)
			motion.global_position = motion.position
			root.push_input(motion, true)
			root.warp_mouse(target.get_global_transform_with_canvas().origin)
			if _index == 0:
				print(
					(
						"[조준 검증] 목표 %s / 마우스 월드 %s / 변환 %s"
						% [
							target.global_position,
							player.get_global_mouse_position(),
							root.get_final_transform()
						]
					)
				)
		await _delay(0.1)
	_mouse(false)
	_check("궁수 화살 실제 명중", hit_count > hits_before, "명중 %d회" % (hit_count - hits_before))
	_check(
		"적 AI 실제 피해", stats.current_hp < hp_before, "HP %.1f → %.1f" % [hp_before, stats.current_hp]
	)
	print(
		(
			"[전투 관찰] XP %d → %d, 골드 %d → %d"
			% [xp_before, progression.current_exp, gold_before, player.get_node("Inventory").gold]
		)
	)
	await _capture("06-archer-combat")
	_check(
		"교전 중 미니맵 적 표시",
		world.get_node("Hud/Minimap/Dots").get_child_count() > 0,
		(
			"몬스터 %d, 등록 그룹 %d"
			% [
				world.get_node("MonsterSpawner").get_child_count(),
				get_nodes_in_group("monsters").size()
			]
		)
	)
	if is_instance_valid(target) and not target.is_dead():
		print("[처치 배선 대조군] 잔여 적을 피해 API로 처치: 실제 사냥 처치 기록과 구분")
		target.take_damage(100000.0, "약", player)
		await _delay(0.1)
		_check(
			"처치 XP·골드 배선",
			progression.current_exp > xp_before and player.get_node("Inventory").gold > gold_before,
			"XP %d / 골드 %d" % [progression.current_exp, player.get_node("Inventory").gold]
		)
