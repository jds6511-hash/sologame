## M3 2차 전직 UI 검증 (C-1) — Lv40 검투사 선택 화면과 전직 후 분노 게이지 HUD 표시.
##
## 1차 전직 화면·알림·디버그 키 검증은 `test_job_transition_ui.gd` 참고(gdlint
## max-public-methods 20개 제한으로 파일 분리). 레벨은 PlayerProgression에 실제 경험치를 넣어
## 올리고 전직도 실제 API로 실행한다 — 후보 목록(available_jobs -> tier2_jobs) 전환이 실제
## 순서대로 일어나야 카드 인덱스 정합까지 검증된다.
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## available_jobs 순서(player.tscn) — 0=전사, 1=궁수.
const WARRIOR_INDEX := 0
## 2차 전직 임계(job_def_gladiator.tres의 transition_level_override).
const TIER2_LEVEL := 40
## 2차 후보(전사의 상위 계통)는 검투사 1종뿐이라 카드 번호는 항상 1번(index 0)이다.
const GLADIATOR_INDEX := 0

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
	## 직업 선택 화면은 열릴 때 SceneTree를 정지시키므로 항상 복원한다(1차 테스트와 동일).
	get_tree().paused = false
	GameClock.reset()


func _notice() -> JobTransitionNotice:
	return _hud.get_node("JobTransitionNotice")


func _screen() -> JobSelectionScreen:
	return _hud.get_node("JobSelectionScreen")


func _cards() -> HBoxContainer:
	return _screen().get_node("Panel/VBox/CardsRow")


func _rage_gauge() -> RageGauge:
	return _hud.get_node("RageGauge")


func _level_up_to(level: int) -> void:
	while _progression.current_level < level:
		_progression.add_exp(_progression.exp_to_next())


## 전사로 1차 전직한 뒤 2차 임계(Lv40)까지 올린다.
func _reach_tier2_as_warrior() -> void:
	_level_up_to(10)
	_transition.request_transition_by_index(WARRIOR_INDEX)
	_level_up_to(TIER2_LEVEL)


# --- 2차 전직 화면 진입 ---


func test_notice_shows_second_tier_text_at_level_40() -> void:
	_reach_tier2_as_warrior()
	assert_true(_transition.transition_available, "Lv40 도달로 2차 전직 가능")
	assert_true(_notice().visible, "2차 전직도 같은 배너로 알린다")
	var title: Label = _notice().get_node("VBox/TitleLabel")
	assert_eq(title.text, "2차 전직 가능!", "1차 알림과 문구로 구분한다")


func test_screen_opens_after_first_transition() -> void:
	_reach_tier2_as_warrior()
	_screen().open()
	assert_true(_screen().is_open(), "전직 이력이 있어도(is_transitioned) 2차 화면은 열린다")
	assert_true(get_tree().paused, "모달이므로 게임이 일시정지된다")


func test_screen_shows_only_gladiator_card() -> void:
	_reach_tier2_as_warrior()
	_screen().open()

	assert_eq(_cards().get_child_count(), 1, "전사의 상위 계통 후보는 검투사 1종")
	var card_name: Label = _cards().get_child(GLADIATOR_INDEX).get_child(0).get_child(0)
	assert_true(card_name.text.contains("검투사"), "카드 = 검투사")


func test_screen_texts_switch_to_second_tier() -> void:
	_reach_tier2_as_warrior()
	_screen().open()

	var title: Label = _screen().get_node("Panel/VBox/TitleLabel")
	var guide: Label = _screen().get_node("Panel/VBox/GuideLabel")
	assert_eq(title.text, "2차 전직")
	assert_true(guide.text.contains("Lv.40"), "안내문의 임계 레벨은 직업 정의에서 읽는다")


## jobs.md 6장: 검투사 지급 무기(WPN-GS-40-B)는 미발행이라 "없음 (준비 중)"이 정상 동작이다.
func test_gladiator_card_shows_pending_weapon_as_normal() -> void:
	_reach_tier2_as_warrior()
	_screen().open()

	var weapon_label: Label = _cards().get_child(GLADIATOR_INDEX).get_child(0).get_child(3)
	assert_eq(weapon_label.text, "지급 무기: 없음 (준비 중)")


func test_tier1_screen_does_not_include_gladiator() -> void:
	_level_up_to(10)
	_screen().open()

	assert_eq(_cards().get_child_count(), _transition.available_jobs.size(), "Lv10 화면은 1차만")
	for card in _cards().get_children():
		var card_name: Label = card.get_child(0).get_child(0)
		assert_false(card_name.text.contains("검투사"), "1차 화면에 상위 계통이 섞이지 않는다")


# --- 2차 전직 실행 ---


func test_screen_select_performs_gladiator_transition() -> void:
	_reach_tier2_as_warrior()
	_screen().open()

	_screen()._select_job(GLADIATOR_INDEX)

	assert_eq(_transition.current_job_id, &"gladiator", "2차 전직 실행")
	assert_false(_screen().is_open(), "전직 후 화면이 닫힌다")
	assert_false(get_tree().paused)


## 최종 계통(검투사 = 3차 데이터 미등록)에서는 후보가 없어 화면이 열리지 않는다.
func test_screen_does_not_open_without_next_candidate() -> void:
	_reach_tier2_as_warrior()
	_screen().open()
	_screen()._select_job(GLADIATOR_INDEX)

	_screen().open()

	assert_false(_screen().is_open(), "다음 단계 후보가 없으면 열리지 않는다")
	assert_false(get_tree().paused)


# --- 분노 게이지 HUD 연동 ---


func test_rage_gauge_hidden_before_gladiator() -> void:
	assert_false(_rage_gauge().visible, "모험가는 분노 게이지 미표시")
	_level_up_to(10)
	_transition.request_transition_by_index(WARRIOR_INDEX)
	assert_false(_rage_gauge().visible, "1차 전사도 분노 게이지 미표시")


## 검투사는 전사 성장 배분(job_growth_warrior.tres)을 재사용하므로 성장 데이터의 표시명을
## 쓰면 "전사"로 남는다 — 라벨은 JobDefinition의 표시명을 따라야 한다.
func test_hud_job_label_shows_gladiator_after_tier2() -> void:
	_reach_tier2_as_warrior()
	_screen().open()
	_screen()._select_job(GLADIATOR_INDEX)

	var label: Label = _hud.get_node("PlayerStatusPanel/LevelJobLabel")
	assert_eq(label.text, "Lv.40 검투사", "2차 전직 후 직업명 갱신")


func test_rage_gauge_shown_after_gladiator_transition() -> void:
	_reach_tier2_as_warrior()
	_screen().open()
	_screen()._select_job(GLADIATOR_INDEX)

	assert_true(_rage_gauge().visible, "검투사 전직 후 분노 게이지 표시")
	var state_label: Label = _rage_gauge().get_node("StateLabel")
	assert_eq(state_label.text, "분노 0 / 100", "전직 직후 게이지는 0에서 시작(2-1장 시작치 0)")
