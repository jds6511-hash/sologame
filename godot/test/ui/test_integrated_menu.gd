## UI-2 검증 — 통합 메뉴 골격의 단축키 진입/토글/전환, ESC 복귀, 오픈 시 일시정지를 재현한다.
extends GutTest

var _menu: IntegratedMenu


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/integrated_menu.tscn")
	_menu = scene.instantiate()
	add_child_autofree(_menu)


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
