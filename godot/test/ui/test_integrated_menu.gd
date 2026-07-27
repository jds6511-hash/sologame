## UI-2 검증 — 통합 메뉴 골격의 단축키 진입/토글/전환, ESC 복귀, 오픈 시 일시정지를 재현한다.
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _menu: IntegratedMenu


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/integrated_menu.tscn")
	_menu = scene.instantiate()
	add_child_autofree(_menu)


func _spawn_player() -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func after_each() -> void:
	## 메뉴가 열린 채로 테스트가 끝나면 SceneTree.paused=true가 남아 다른 테스트에 영향을
	## 주므로 항상 복원한다.
	get_tree().paused = false


func test_menu_starts_closed() -> void:
	assert_false(_menu.is_open())
	assert_false(_menu.visible)


func test_inventory_shortcut_opens_menu_and_pauses_tree() -> void:
	_menu._on_tab_shortcut(IntegratedMenu.Tab.INVENTORY)
	assert_true(_menu.is_open())
	assert_true(_menu.visible)
	assert_true(get_tree().paused)
	assert_eq(_menu.get_node("Tabs").current_tab, int(IntegratedMenu.Tab.INVENTORY))


func test_character_shortcut_opens_menu_on_character_tab() -> void:
	_menu._on_tab_shortcut(IntegratedMenu.Tab.CHARACTER)
	assert_true(_menu.is_open())
	assert_eq(_menu.get_node("Tabs").current_tab, int(IntegratedMenu.Tab.CHARACTER))


func test_same_shortcut_twice_closes_menu() -> void:
	_menu._on_tab_shortcut(IntegratedMenu.Tab.INVENTORY)
	_menu._on_tab_shortcut(IntegratedMenu.Tab.INVENTORY)
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_different_shortcut_switches_tab_without_closing() -> void:
	_menu._on_tab_shortcut(IntegratedMenu.Tab.INVENTORY)
	_menu._on_tab_shortcut(IntegratedMenu.Tab.CHARACTER)
	assert_true(_menu.is_open(), "다른 탭 단축키는 메뉴를 닫지 않고 전환만 한다")
	assert_eq(_menu.get_node("Tabs").current_tab, int(IntegratedMenu.Tab.CHARACTER))


func test_close_menu_unpauses_tree() -> void:
	_menu.open_menu()
	_menu.close_menu()
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_get_inventory_content_root_returns_control() -> void:
	var content_root: Control = _menu.get_inventory_content_root()
	assert_not_null(content_root, "IT-3 연동 지점 — 인벤토리 콘텐츠 루트는 항상 존재해야 함")


func test_bind_character_stats_updates_character_tab_labels() -> void:
	var stats := CombatantStats.new()
	stats.attack_power = 42.0
	stats.defense = 18.0
	stats.agility = 9.0
	stats.max_hp = 135.0
	stats.max_mp = 40.0

	_menu.bind_character_stats(stats, 5, "전사")

	var level_job_label: Label = _menu.get_node("Tabs/CharacterTab/VBox/LevelJobLabel")
	assert_eq(level_job_label.text, "Lv.5 전사")
	var stat_list_label: Label = _menu.get_node("Tabs/CharacterTab/VBox/StatListLabel")
	assert_true(stat_list_label.text.contains("공격력 42"))
	assert_true(stat_list_label.text.contains("최대 HP 135"))


# --- M3 B-4: bind_player 통합 배선(캐릭터 탭 치명타% · 스킬 탭 강화) ---


func test_bind_player_shows_crit_in_character_tab() -> void:
	var player := _spawn_player()
	_menu.bind_player(player)
	var stat_list_label: Label = _menu.get_node("Tabs/CharacterTab/VBox/StatListLabel")
	assert_true(stat_list_label.text.contains("치명타"), "치명타% 표시(공유 스탯+formula 산출)")


func test_skill_tab_binds_available_points() -> void:
	var player := _spawn_player()
	var skill_points: PlayerSkillPoints = player.get_node("PlayerSkillPoints")
	skill_points.grant_transition_points()  ## +2
	_menu.bind_player(player)
	var points_label: Label = _menu.get_node("Tabs/SkillTab/VBox/PointsLabel")
	assert_true(points_label.text.contains("2"), "잔여 스킬 포인트 표시")


func test_skill_tab_upgrade_button_spends_points_and_levels_skill() -> void:
	var player := _spawn_player()
	var skill_points: PlayerSkillPoints = player.get_node("PlayerSkillPoints")
	skill_points.grant_transition_points()  ## +2
	_menu.bind_player(player)

	## 첫 행 = 강타(강타 Lv1→2 비용 1). 강화 버튼을 눌러 실제 상태 변화 확인.
	var first_row: HBoxContainer = _menu.get_node("Tabs/SkillTab/VBox/SkillList").get_child(0)
	var button: Button = first_row.get_child(2)
	button.pressed.emit()

	assert_eq(skill_points.get_skill_level(&"강타"), 2, "강타 Lv2로 강화")
	assert_eq(skill_points.available_points, 1, "비용 1 차감")
	var level_label: Label = first_row.get_child(1)
	assert_true(level_label.text.contains("Lv.2"), "강화 후 레벨 라벨 갱신")


func test_skill_tab_button_disabled_without_points() -> void:
	var player := _spawn_player()
	_menu.bind_player(player)  ## 포인트 0(레벨업/전직 없음)

	var first_row: HBoxContainer = _menu.get_node("Tabs/SkillTab/VBox/SkillList").get_child(0)
	var button: Button = first_row.get_child(2)
	assert_true(button.disabled, "포인트 부족 시 강화 버튼 비활성")


# --- M3 전직 UI: 전직 후 스킬/캐릭터 탭 재바인딩(job_changed 구독) ---


## 큐에 삭제 예약된 이전 행을 제외한 실제 스킬 행 목록(재바인딩 직후 검사용).
func _live_skill_rows() -> Array:
	var rows: Array = []
	for child in _menu.get_node("Tabs/SkillTab/VBox/SkillList").get_children():
		if not child.is_queued_for_deletion():
			rows.append(child)
	return rows


func _level_up_to_transition(progression: PlayerProgression) -> void:
	while progression.current_level < 10:
		progression.add_exp(progression.exp_to_next())


func test_skill_tab_lists_only_adventurer_skills_before_transition() -> void:
	var player := _spawn_player()
	_menu.bind_player(player)
	assert_eq(_live_skill_rows().size(), 3, "모험가는 공용 3종만 강화 대상")


func test_skill_tab_rebinds_job_skills_after_transition() -> void:
	var player := _spawn_player()
	var transition: PlayerJobTransition = player.get_node("PlayerJobTransition")
	_menu.bind_player(player)
	_level_up_to_transition(player.get_node("PlayerProgression"))

	transition.request_transition_by_index(0)  ## 0 = 전사

	## 전사 로드아웃 = 공용 3 + 고유 4(4/Q/E/궁극기) + 우클릭 1 = 8종.
	assert_eq(_live_skill_rows().size(), 8, "전직 후 개방 스킬이 스킬 탭에 나타난다")


func test_skill_tab_grants_transition_points_after_transition() -> void:
	var player := _spawn_player()
	var transition: PlayerJobTransition = player.get_node("PlayerJobTransition")
	_menu.bind_player(player)
	_level_up_to_transition(player.get_node("PlayerProgression"))

	transition.request_transition_by_index(0)

	var points_label: Label = _menu.get_node("Tabs/SkillTab/VBox/PointsLabel")
	assert_false(points_label.text.contains(": 0"), "전직 보너스 포인트가 스킬 탭에 반영")


func test_character_tab_shows_job_name_after_transition() -> void:
	var player := _spawn_player()
	var transition: PlayerJobTransition = player.get_node("PlayerJobTransition")
	_menu.bind_player(player)
	_level_up_to_transition(player.get_node("PlayerProgression"))

	transition.request_transition_by_index(0)

	var level_job_label: Label = _menu.get_node("Tabs/CharacterTab/VBox/LevelJobLabel")
	assert_true(level_job_label.text.contains("전사"), "전직 후 캐릭터 탭 직업명 갱신")
