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

@onready var _background: ColorRect = $Background
@onready var _tabs: TabContainer = $Tabs
@onready var _inventory_tab: InventoryTabStub = $Tabs/InventoryTab
@onready var _character_tab: CharacterTab = $Tabs/CharacterTab
@onready var _skill_tab: PlaceholderTab = $Tabs/SkillTab
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
	## 8장 M2 이후 과제(3·5·6·4번) — 의존 시스템 확정 전까지 빈 자리임을 명시.
	_skill_tab.set_message("스킬 탭 (직업 스킬 트리 확정 후 구현 — M2 이후)")
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


## 캐릭터 탭 데이터 바인딩(읽기 전용 스탯 표시).
func bind_character_stats(stats: CombatantStats, level: int, job_name: String) -> void:
	_character_tab.bind_stats(stats, level, job_name)
