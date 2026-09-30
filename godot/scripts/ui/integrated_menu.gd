## S05~S11 통합 메뉴 골격 (UI-2) — I/C/K/J/M/B 단축키 진입, ESC 복귀, 오픈 시 일시정지.
##
## `docs\art\ux\ux-foundation.md` 2장(단축키 표)·3장(화면 목록 S06~S11)·4장(전환 규칙 —
## "단축키 재입력 시 메뉴 닫힘", "다른 탭 단축키 입력 시 해당 탭으로 즉시 전환")을 그대로
## 구현한다. M3 스킬 탭과 M5 의뢰 저널까지 연결했으며 지도·도감은 후속 범위다.
##
## 월드에서 bind_player / bind_quests로 현재 캐릭터를 연결한다.
class_name IntegratedMenu
extends CanvasLayer

signal menu_opened
signal menu_closed

enum Tab { INVENTORY, CHARACTER, SKILL, JOURNAL, MAP, CODEX, SETTINGS }

const ACTION_TO_TAB := {
	"menu_inventory": Tab.INVENTORY,
	"menu_character": Tab.CHARACTER,
	"menu_skill": Tab.SKILL,
	"menu_journal": Tab.JOURNAL,
	"menu_map": Tab.MAP,
}

var pause_arbiter: UiPauseArbiter
var screen := "feature"
var pause_box: VBoxContainer
var heading: Label
var _is_open: bool = false

## M3 B-4: 캐릭터/스킬 탭 실값 바인딩용 참조(bind_player가 채운다).
var _bound_player: PlayerController = null
var _combat_stats: CombatantStats = null
var _progression: PlayerProgression = null
var _formula: DamageFormulaData = null

@onready var _background: ColorRect = $Background
@onready var _tabs: TabContainer = $Tabs
@onready var _inventory_tab: InventoryTabStub = $Tabs/InventoryTab
@onready var _character_tab: CharacterTab = $Tabs/CharacterTab
@onready var _skill_tab: SkillTab = $Tabs/SkillTab
@onready var _journal_tab: Control = $Tabs/JournalTab
@onready var _map_tab: Control = $Tabs/MapTab
@onready var _codex_tab: PlaceholderTab = $Tabs/CodexTab


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_background.color = Color(UiStyle.COLOR_OUTLINE, 1.0)
	_style_tabs()
	_tabs.set_tab_title(Tab.INVENTORY, "인벤토리")
	_tabs.set_tab_title(Tab.CHARACTER, "캐릭터")
	_tabs.set_tab_title(Tab.SKILL, "스킬")
	_tabs.set_tab_title(Tab.JOURNAL, "퀘스트 저널")
	_tabs.set_tab_title(Tab.MAP, "지도")
	_tabs.set_tab_title(Tab.CODEX, "도감")
	## 8장 M2 이후 과제(5·6·4번) — 의존 시스템 확정 전까지 빈 자리임을 명시.
	## 스킬 탭(3번)은 M3 B-4에서 실탭(스킬 포인트·강화 화면)으로 구현됐다.
	_create_settings()
	_create_pause_menu()
	_tabs.tabs_visible = false
	_tabs.offset_top = 130
	_codex_tab.set_message("도감 (도감 데이터 스키마 확정 후 구현 — M2 이후)")
	visible = false


func _style_tabs() -> void:
	UiStyle.apply_body_font(_tabs, 30)
	_tabs.add_theme_font_override("font", load(UiStyle.FONT_HEADING_PATH))
	for key in ["font_selected_color", "font_hovered_color", "font_unselected_color"]:
		_tabs.add_theme_color_override(key, Color.WHITE)
	for state in ["tab_selected", "tab_unselected", "tab_hovered", "tab_focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("34465d") if state == "tab_selected" else Color("202938")
		box.content_margin_left = 24
		box.content_margin_right = 24
		box.content_margin_top = 18
		box.content_margin_bottom = 18
		if state == "tab_selected":
			box.border_color = Color("f9cf75")
			box.border_width_bottom = 4
		if state == "tab_focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = Color.WHITE
			box.set_border_width_all(2)
		_tabs.add_theme_stylebox_override(state, box)
	var body := StyleBoxFlat.new()
	body.bg_color = Color("111d2c")
	for side in ["left", "right", "top", "bottom"]:
		body.set("content_margin_" + side, 24)
	_tabs.add_theme_stylebox_override("panel", body)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("menu_pause"):
		if _is_open:
			if screen == "settings":
				open_settings()
			else:
				close_menu()
		else:
			open_settings()
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if _is_open and screen != "feature":
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_B:
		_on_tab_shortcut(Tab.INVENTORY)
		get_viewport().set_input_as_handled()
		return
	for action_name in ACTION_TO_TAB.keys():
		if event.is_action_pressed(action_name):
			_on_tab_shortcut(ACTION_TO_TAB[action_name])
			get_viewport().set_input_as_handled()
			return


func open_settings() -> void:
	if not _is_open:
		open_menu()
	if not _is_open:
		return
	screen = "pause"
	_tabs.hide()
	heading.hide()
	pause_box.show()
	pause_box.get_child(1).grab_focus()


func _create_pause_menu() -> void:
	heading = Label.new()
	heading.position = Vector2(84, 55)
	UiStyle.apply_body_font(heading, 36)
	add_child(heading)
	pause_box = VBoxContainer.new()
	pause_box.position = Vector2(650, 260)
	pause_box.size = Vector2(620, 500)
	pause_box.add_theme_constant_override("separation", 24)
	add_child(pause_box)
	var title := Label.new()
	title.text = "일시정지"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_body_font(title, 40)
	pause_box.add_child(title)
	_menu_button(pause_box, "계속하기", close_menu)
	_menu_button(pause_box, "저장 / 불러오기", _open_save)
	_menu_button(pause_box, "설정", _show_settings)
	_menu_button(pause_box, "게임 종료", _ask_quit)
	pause_box.hide()
	_menu_button(_character_tab.get_node("VBox"), "장비 관리", _open_equipment)


func _menu_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	UiStyle.apply_action_button(button)
	parent.add_child(button)
	button.pressed.connect(callback)


func _show_settings() -> void:
	screen = "settings"
	pause_box.hide()
	_tabs.show()
	_tabs.current_tab = Tab.SETTINGS
	heading.text = "설정"
	heading.show()


func _ask_quit() -> void:
	var confirm: ConfirmationDialog = get_node("QuitConfirmation")
	confirm.popup_centered(Vector2i(580, 180))
	confirm.get_cancel_button().grab_focus()


func _open_save() -> void:
	var save = get_parent().get_node_or_null("SaveMenu")
	if save == null:
		return
	close_menu()
	save.open_from_pause(self)


func _open_equipment() -> void:
	var economy = get_parent().get_node_or_null("EconomyPanel")
	if economy != null:
		close_menu()
		economy.open("gear")


func _create_settings() -> void:
	var box := VBoxContainer.new()
	box.name = "SettingsTab"
	box.add_theme_constant_override("separation", 24)
	_tabs.add_child(box)
	_tabs.set_tab_title(Tab.SETTINGS, "설정")
	var label := Label.new()
	label.text = "B 가방 · C 캐릭터/장비 · K 스킬 · J 의뢰 · M 지도\n음량·그래픽 세부 설정은 준비 중입니다."
	UiStyle.apply_body_font(label, 26)
	box.add_child(label)
	_menu_button(box, "뒤로", open_settings)
	var confirm := ConfirmationDialog.new()
	confirm.name = "QuitConfirmation"
	confirm.title = "게임 종료"
	confirm.dialog_text = "저장하지 않은 진행은 사라집니다. 종료할까요?"
	confirm.ok_button_text = "종료"
	confirm.cancel_button_text = "돌아가기"
	add_child(confirm)
	confirm.confirmed.connect(func(): get_tree().quit())


## 같은 탭 단축키를 다시 누르면 닫힘, 다른 탭 단축키면 그 탭으로 즉시 전환(ux 4장 규칙).
func _on_tab_shortcut(tab: int) -> void:
	var economy = get_parent().get_node_or_null("EconomyPanel")
	if tab == Tab.INVENTORY and economy != null:
		if is_menu_blocked():
			return
		if _is_open:
			close_menu()
		economy.open("bag")
		return
	if _is_open and _tabs.current_tab == tab:
		close_menu()
		return
	## 열 수 없는 상황이면 탭도 바꾸지 않는다 — 안 열리는데 탭만 조용히 바뀌면 다음에 열었을 때
	## 엉뚱한 탭이 나온다.
	if not _is_open and is_menu_blocked():
		return
	_tabs.current_tab = tab
	screen = "feature"
	pause_box.hide()
	_tabs.show()
	heading.text = _tabs.get_tab_title(tab) + "    ·    Esc 닫기"
	heading.show()
	_refresh_character_tab()
	if not _is_open:
		open_menu()


## 사망 연출 중에는 메뉴를 열지 않는다 (디렉터 확정, D-3 리포트 비차단 이슈 3).
## 두 가지가 동시에 깨지기 때문이다: ① `open_menu`의 `get_tree().paused = true`가
## `PlayerDeathSequence._process()`를 멈춰 연출이 그 자리에 정지한다 ② 암전 CanvasLayer(20)가
## 메뉴(10)보다 위라, 암전 구간에 열면 메뉴가 검은 화면 **아래** 깔려 보이지도 않는다.
## 플레이어를 바인드하지 않은 씬(메뉴 단독 테스트 등)에서는 막을 근거가 없으므로 통과시킨다.
func is_menu_blocked() -> bool:
	if _bound_player == null:
		return false
	var death_sequence := (
		_bound_player.get_node_or_null("PlayerDeathSequence") as PlayerDeathSequence
	)
	return death_sequence != null and death_sequence.is_active()


func open_menu() -> void:
	if _is_open or is_menu_blocked():
		return
	pause_arbiter = UiPauseArbiter.for_world(get_parent())
	if not pause_arbiter.acquire(self):
		return
	_is_open = true
	visible = true
	menu_opened.emit()


func close_menu() -> void:
	if not _is_open:
		return
	get_node("QuitConfirmation").hide()
	_is_open = false
	visible = false
	pause_arbiter.release(self)
	menu_closed.emit()


func is_open() -> bool:
	return _is_open


## IT-3(인벤토리 시스템) 연동 지점 — 실제 인벤토리 UI 서브트리를 이 루트 아래에 추가하면 된다.
func get_inventory_content_root() -> Control:
	return _inventory_tab.get_content_root()


func bind_quests(journal: QuestJournal) -> void:
	_journal_tab.bind_journal(journal)


## 캐릭터 탭 데이터 바인딩(읽기 전용 스탯 표시) — 치명타% 미포함 하위 호환 경로.
func bind_character_stats(stats: CombatantStats, level: int, job_name: String) -> void:
	_character_tab.bind_stats(stats, level, job_name)


## M3 B-4 통합 배선 지점 — player.tscn 인스턴스를 넘기면 캐릭터/스킬 탭을 실값으로 채운다.
## 월드 씬에서 `integrated_menu.bind_player(player)`를 한 번 호출하면 된다(hud.bind_player와
## 동일 패턴). progression·skill_points·stats·formula를 player의 자식 노드에서 읽기 전용으로
## 참조한다(진행 노드·player.tscn을 수정하지 않는다).
func bind_player(player: PlayerController) -> void:
	_bound_player = player
	_map_tab.bind_world(player.get_parent())
	var stats_component := player.get_node_or_null("PlayerStats") as PlayerStatsComponent
	if stats_component:
		_combat_stats = stats_component.stats
	_progression = player.get_node_or_null("PlayerProgression") as PlayerProgression
	var resolver := player.get_node_or_null("AttackResolver") as PlayerAttackResolver
	if resolver:
		_formula = resolver.formula_data
	_refresh_character_tab()
	if _progression:
		## 레벨업 시 스탯·레벨이 바뀌므로 캐릭터 탭을 다시 채운다(PlayerStatGrowth가 먼저
		## 재계산한 뒤 이 핸들러가 돌도록 연결 순서상 보장된다 — 진행 노드가 먼저 _ready에서 연결).
		_progression.leveled_up.connect(_on_player_leveled_up)
	var skill_points := player.get_node_or_null("PlayerSkillPoints") as PlayerSkillPoints
	if skill_points:
		_skill_tab.bind(skill_points, _collect_skills(player))
	## M3: 전직 시 스킬 로드아웃과 스탯이 함께 바뀌므로 두 탭을 다시 채운다 — bind 시점
	## 스냅샷이 굳으면 전직해도 스킬 탭에 새 스킬(4/Q/E/R/우클릭)이 나타나지 않는다.
	var transition := player.get_node_or_null("PlayerJobTransition") as PlayerJobTransition
	if transition:
		transition.job_changed.connect(_on_job_changed)


func _on_job_changed(_job_id: StringName) -> void:
	_refresh_character_tab()
	_skill_tab.rebind_skills(_collect_skills(_bound_player))


## 캐릭터 탭 실값 갱신 — 치명타%는 공유 CombatantStats에 없어 formula로 산출한다(spec 5-2).
func _refresh_character_tab() -> void:
	if _combat_stats == null:
		return
	var level: int = _progression.current_level if _progression else 1
	var job_name := _resolve_job_name(_bound_player)
	var crit_percent := -1.0
	if _formula:
		crit_percent = (
			DamageCalculator.calculate_crit_chance(_combat_stats.agility, _formula) * 100.0
		)
	_character_tab.bind_stats(_combat_stats, level, job_name, crit_percent)


func _on_player_leveled_up(_new_level: int) -> void:
	_refresh_character_tab()


func _resolve_job_name(player: PlayerController) -> String:
	if player == null:
		return "전사"
	var growth := player.get_node_or_null("PlayerStatGrowth")
	if growth and growth.job:
		return growth.job.display_name
	return "전사"


## 강화 대상 스킬 목록 — 스킬 바(F행)와 동일 순서의 슬롯 7종 + 우클릭(보조 동작). 우클릭은
## HUD 스킬 바에 칸이 없지만(ux 5장 F행은 9칸 고정) 전직으로 개방되는 직업 스킬이므로 강화
## 대상에 포함한다. null 슬롯(미개방)은 SkillTab이 건너뛴다.
func _collect_skills(player: PlayerController) -> Array:
	return [
		player.skill_slot_1,
		player.skill_slot_2,
		player.skill_slot_3,
		player.skill_slot_4,
		player.skill_slot_q,
		player.skill_slot_e,
		player.skill_ultimate,
		player.skill_charge,
	]
