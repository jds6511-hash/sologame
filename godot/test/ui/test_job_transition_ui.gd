## M3 전직 UI 검증(1차) — 전직 가능 알림, 직업 선택 화면, 전직 후 UI 재바인딩, 디버그 레벨 키.
##
## 전직 조건(Lv10)은 PlayerProgression에 실제 경험치를 넣어 만든다 — 레벨업 시그널 경로를
## 그대로 태워야 PlayerJobTransition의 전직 가능 판정까지 실제 순서대로 재현된다.
##
## 2차 전직(Lv40 검투사) 화면과 분노 게이지 HUD 연동은 `test_job_transition_tier2_ui.gd`
## 참고(gdlint max-public-methods 20개 제한으로 파일 분리).
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## available_jobs 순서(player.tscn) — 0=전사, 1=궁수.
const WARRIOR_INDEX := 0
const ARCHER_INDEX := 1

var _hud: Hud
var _player: PlayerController
var _progression: PlayerProgression
var _transition: PlayerJobTransition


func before_each() -> void:
	GameClock.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_progression = _player.get_node("PlayerProgression")
	_transition = _player.get_node("PlayerJobTransition")
	_hud = load("res://scenes/ui/hud.tscn").instantiate()
	add_child_autofree(_hud)
	_hud.bind_player(_player, _player.get_node("PlayerStats"))


func after_each() -> void:
	## 직업 선택 화면은 열릴 때 SceneTree를 정지시키므로 항상 복원한다(통합 메뉴 테스트와 동일).
	get_tree().paused = false
	GameClock.reset()


## 전직 임계(Lv10)까지 레벨을 올린다 — 레벨당 남은 요구 경험치를 정확히 투입.
func _level_up_to_transition() -> void:
	while _progression.current_level < 10:
		_progression.add_exp(_progression.exp_to_next())


func _notice() -> JobTransitionNotice:
	return _hud.get_node("JobTransitionNotice")


func _screen() -> JobSelectionScreen:
	return _hud.get_node("JobSelectionScreen")


func _slot(slot_name: String) -> SkillSlot:
	return _hud.get_node("SkillSlotBar/" + slot_name)


# --- 전직 가능 알림 (transition_became_available 구독) ---


func test_notice_hidden_before_transition_level() -> void:
	assert_false(_notice().visible, "Lv10 미달에는 전직 알림이 표시되지 않는다")


func test_notice_shown_when_transition_becomes_available() -> void:
	_level_up_to_transition()
	assert_true(_transition.transition_available, "Lv10 도달로 전직 가능 상태")
	assert_true(_notice().visible, "전직 가능 시 HUD 알림 표시")


func test_notice_hidden_after_transition() -> void:
	_level_up_to_transition()
	_transition.request_transition_by_index(WARRIOR_INDEX)
	assert_false(_notice().visible, "전직 완료 후 알림은 사라진다")


# --- 직업 선택 화면 ---


func test_screen_does_not_open_before_transition_available() -> void:
	_screen().open()
	assert_false(_screen().is_open(), "Lv10 미달에는 직업 선택 화면이 열리지 않는다")
	assert_false(get_tree().paused)


func test_notice_request_opens_screen_and_pauses() -> void:
	_level_up_to_transition()
	_notice().selection_requested.emit()
	assert_true(_screen().is_open(), "알림 요청(클릭·V 키)으로 직업 선택 화면이 열린다")
	assert_true(get_tree().paused, "모달이므로 게임이 일시정지된다")


func test_screen_has_one_card_per_available_job() -> void:
	var cards: HBoxContainer = _screen().get_node("Panel/VBox/CardsRow")
	assert_eq(cards.get_child_count(), _transition.available_jobs.size(), "직업 수만큼 카드 생성")


func test_screen_cards_show_job_display_names() -> void:
	var cards: HBoxContainer = _screen().get_node("Panel/VBox/CardsRow")
	var warrior_name: Label = cards.get_child(WARRIOR_INDEX).get_child(0).get_child(0)
	var archer_name: Label = cards.get_child(ARCHER_INDEX).get_child(0).get_child(0)
	assert_true(warrior_name.text.contains("전사"), "1번 카드 = 전사")
	assert_true(archer_name.text.contains("궁수"), "2번 카드 = 궁수")


func test_screen_select_warrior_performs_transition_and_closes() -> void:
	_level_up_to_transition()
	_screen().open()

	_screen()._select_job(WARRIOR_INDEX)

	assert_true(_transition.is_transitioned, "전직 실행")
	assert_eq(_transition.current_job_id, &"warrior")
	assert_false(_screen().is_open(), "전직 후 화면이 닫힌다")
	assert_false(get_tree().paused, "화면이 닫히면 일시정지가 풀린다")


## 궁수는 고유 스킬이 아직 미구현(C-4)이라 공용 3종만 열리지만, 선택 자체는 되어야 한다.
func test_screen_select_archer_performs_transition() -> void:
	_level_up_to_transition()
	_screen().open()

	_screen()._select_job(ARCHER_INDEX)

	assert_true(_transition.is_transitioned)
	assert_eq(_transition.current_job_id, &"archer")


func test_screen_select_fails_before_transition_available() -> void:
	_screen()._select_job(WARRIOR_INDEX)
	assert_false(_transition.is_transitioned, "Lv10 미달이면 전직되지 않는다")


func test_screen_close_unpauses() -> void:
	_level_up_to_transition()
	_screen().open()
	_screen().close()
	assert_false(_screen().is_open())
	assert_false(get_tree().paused)


# --- 전직 후 재바인딩 (job_changed 구독) ---


func test_skill_bar_locks_unopened_slots_before_transition() -> void:
	assert_lt(_slot("Slot4").modulate.a, 1.0, "모험가는 4번 슬롯 미개방")
	assert_lt(_slot("SlotQ").modulate.a, 1.0, "모험가는 Q 슬롯 미개방")
	assert_lt(_slot("SlotE").modulate.a, 1.0, "모험가는 E 슬롯 미개방")
	assert_lt(_slot("SlotUltimate").modulate.a, 1.0, "모험가는 궁극기 슬롯 미개방")
	assert_eq(_slot("Slot1").modulate.a, 1.0, "공용 스킬(강타)은 개방 상태")


func test_skill_bar_rebinds_opened_slots_after_transition() -> void:
	_level_up_to_transition()
	_transition.request_transition_by_index(WARRIOR_INDEX)

	assert_eq(_slot("Slot4").modulate.a, 1.0, "전직 후 4번 슬롯 개방")
	assert_eq(_slot("SlotQ").modulate.a, 1.0, "전직 후 Q 슬롯 개방")
	assert_eq(_slot("SlotE").modulate.a, 1.0, "전직 후 E 슬롯 개방")
	assert_eq(_slot("SlotUltimate").modulate.a, 1.0, "전직 후 궁극기 슬롯 개방")


func test_skill_bar_shows_icons_for_opened_slots_after_transition() -> void:
	_level_up_to_transition()
	_transition.request_transition_by_index(WARRIOR_INDEX)
	var icon: TextureRect = _slot("SlotUltimate").get_node("Icon")
	assert_not_null(icon.texture, "전직 후 궁극기 칸에 아이콘이 채워진다")


func test_hud_job_label_updates_after_transition() -> void:
	_level_up_to_transition()
	_transition.request_transition_by_index(WARRIOR_INDEX)
	var label: Label = _hud.get_node("PlayerStatusPanel/LevelJobLabel")
	assert_eq(label.text, "Lv.10 전사", "전직 후 직업명 갱신")


# --- 디버그 레벨 점프 키 ---


func test_debug_level_keys_grant_single_level() -> void:
	var keys: DebugLevelKeys = _hud.get_node("DebugLevelKeys")
	keys.grant_levels(1)
	assert_eq(_progression.current_level, 2, "Page Up 1회 = +1 레벨")


func test_debug_level_keys_grant_bulk_reaches_transition() -> void:
	var keys: DebugLevelKeys = _hud.get_node("DebugLevelKeys")
	keys.grant_levels(DebugLevelKeys.BULK_LEVEL_COUNT)
	assert_eq(_progression.current_level, 11, "Shift+Page Up = +10 레벨")
	assert_true(_transition.transition_available, "레벨 점프로도 전직 가능 판정이 정상 발생")
	assert_true(_notice().visible, "레벨 점프 후 전직 알림 표시")


func test_debug_level_keys_stop_at_max_level() -> void:
	var keys: DebugLevelKeys = _hud.get_node("DebugLevelKeys")
	keys.grant_levels(200)
	assert_true(_progression.is_max_level(), "만렙에서 멈춘다")
