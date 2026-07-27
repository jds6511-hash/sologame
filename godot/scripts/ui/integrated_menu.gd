## S05~S11 통합 메뉴 골격 (UI-2) — I/C/K/J/M/B 단축키 진입, ESC 복귀, 오픈 시 일시정지.
##
## `docs\art\ux\ux-foundation.md` 2장(단축키 표)·3장(화면 목록 S06~S11)·4장(전환 규칙 —
## "단축키 재입력 시 메뉴 닫힘", "다른 탭 단축키 입력 시 해당 탭으로 즉시 전환")을 그대로
## 구현한다. 인벤토리·캐릭터 탭만 실제 내용이 있고 나머지(스킬/퀘스트 저널/지도/도감)는
## 빈 자리다 — 각각 담당 시스템(직업 트리·퀘스트 구조·월드맵·도감 스키마)이 M2 범위 밖.
##
## player.tscn·world 씬을 직접 수정하지 않았다 — 이 씬을 게임 씬에 자식으로 추가하기만
## 하면 단축키가 바로 동작한다(부착 방법은 결과 보고 참조).
class_name IntegratedMenu
extends CanvasLayer

signal menu_opened
signal menu_closed

enum Tab { INVENTORY, CHARACTER, SKILL, JOURNAL, MAP, CODEX }

const ACTION_TO_TAB := {
	"menu_inventory": Tab.INVENTORY,
	"menu_character": Tab.CHARACTER,
	"menu_skill": Tab.SKILL,
	"menu_journal": Tab.JOURNAL,
	"menu_map": Tab.MAP,
	"menu_codex": Tab.CODEX,
}

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
@onready var _journal_tab: PlaceholderTab = $Tabs/JournalTab
@onready var _map_tab: PlaceholderTab = $Tabs/MapTab
@onready var _codex_tab: PlaceholderTab = $Tabs/CodexTab


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_background.color = Color(UiStyle.COLOR_OUTLINE, 0.92)
	_tabs.set_tab_title(Tab.INVENTORY, "인벤토리")
	_tabs.set_tab_title(Tab.CHARACTER, "캐릭터")
	_tabs.set_tab_title(Tab.SKILL, "스킬")
	_tabs.set_tab_title(Tab.JOURNAL, "퀘스트 저널")
	_tabs.set_tab_title(Tab.MAP, "지도")
	_tabs.set_tab_title(Tab.CODEX, "도감")
	## 8장 M2 이후 과제(5·6·4번) — 의존 시스템 확정 전까지 빈 자리임을 명시.
	## 스킬 탭(3번)은 M3 B-4에서 실탭(스킬 포인트·강화 화면)으로 구현됐다.
	_journal_tab.set_message("퀘스트 저널 (퀘스트 구조 확정 후 구현 — M2 이후)")
	_map_tab.set_message("지도 (월드맵 구조 확정 후 구현 — M2 이후)")
	_codex_tab.set_message("도감 (도감 데이터 스키마 확정 후 구현 — M2 이후)")
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	for action_name in ACTION_TO_TAB.keys():
		if event.is_action_pressed(action_name):
			_on_tab_shortcut(ACTION_TO_TAB[action_name])
			get_viewport().set_input_as_handled()
			return
	if _is_open and event.is_action_pressed("menu_pause"):
		close_menu()
		get_viewport().set_input_as_handled()


## 같은 탭 단축키를 다시 누르면 닫힘, 다른 탭 단축키면 그 탭으로 즉시 전환(ux 4장 규칙).
func _on_tab_shortcut(tab: int) -> void:
	if _is_open and _tabs.current_tab == tab:
		close_menu()
		return
	_tabs.current_tab = tab
	if not _is_open:
		open_menu()


func open_menu() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	get_tree().paused = true
	menu_opened.emit()


func close_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_tree().paused = false
	menu_closed.emit()


func is_open() -> bool:
	return _is_open


## IT-3(인벤토리 시스템) 연동 지점 — 실제 인벤토리 UI 서브트리를 이 루트 아래에 추가하면 된다.
func get_inventory_content_root() -> Control:
	return _inventory_tab.get_content_root()


## 캐릭터 탭 데이터 바인딩(읽기 전용 스탯 표시) — 치명타% 미포함 하위 호환 경로.
func bind_character_stats(stats: CombatantStats, level: int, job_name: String) -> void:
	_character_tab.bind_stats(stats, level, job_name)


## M3 B-4 통합 배선 지점 — player.tscn 인스턴스를 넘기면 캐릭터/스킬 탭을 실값으로 채운다.
## 월드 씬에서 `integrated_menu.bind_player(player)`를 한 번 호출하면 된다(hud.bind_player와
## 동일 패턴). progression·skill_points·stats·formula를 player의 자식 노드에서 읽기 전용으로
## 참조한다(진행 노드·player.tscn을 수정하지 않는다).
func bind_player(player: PlayerController) -> void:
	_bound_player = player
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
