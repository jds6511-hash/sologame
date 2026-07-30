## M3 분노 게이지 HUD 검증 (C-1 UI) — 3단 임계 표시, 비검투사 미표시, 모듈 시그널 구독.
##
## 게이지 값은 PlayerRageModule의 공개 API(add_from_hit_taken 등)로만 움직인다 — 내부 변수를
## 직접 넣으면 시그널 경로를 건너뛰어 "구독으로 갱신된다"는 것을 검증할 수 없다. 피격 충전은
## +12/회(skill_secondary_execution.tres)라 5회=60(처형 가능) / 7회=84(격노) / 9회=만땅이다.
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const GLADIATOR_JOB := preload("res://data/jobs/job_def_gladiator.tres")

var _player: PlayerController
var _gauge: RageGauge


func before_each() -> void:
	GameClock.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_gauge = load("res://scenes/ui/rage_gauge.tscn").instantiate()
	add_child_autofree(_gauge)
	_gauge.bind_player(_player)


func after_each() -> void:
	GameClock.reset()


## 검투사 로드아웃을 실제로 적용해 분노 게이지를 활성화한다(2차 전직과 같은 경로).
func _become_gladiator() -> void:
	_player.apply_transition_loadout(GLADIATOR_JOB.skill_loadout(), GLADIATOR_JOB.basic_combo)


## 피격 충전(+12)을 count회 발생시킨다.
func _charge_by_hits(count: int) -> void:
	for _i in count:
		_player.rage.add_from_hit_taken()


func _fill() -> ColorRect:
	return _gauge.get_node("Bar/Fill")


func _border() -> Panel:
	return _gauge.get_node("Bar/Border")


func _label_text() -> String:
	var label: Label = _gauge.get_node("StateLabel")
	return label.text


func _tick_lit(node_name: String) -> bool:
	var tick: ColorRect = _gauge.get_node("Bar/" + node_name)
	return tick.color == RageGauge.COLOR_RAGE_FULL


# --- 비검투사 미표시 ---


func test_gauge_hidden_for_adventurer() -> void:
	assert_false(_gauge.visible, "모험가(미전직)는 분노 게이지를 쓰지 않으므로 표시되지 않는다")


func test_gauge_hidden_for_tier1_warrior() -> void:
	var warrior: JobDefinition = _player.get_node("PlayerJobTransition").available_jobs[0]
	_player.apply_transition_loadout(warrior.skill_loadout(), warrior.basic_combo)
	assert_false(_gauge.visible, "1차 전사는 처형 일격이 없어 게이지가 표시되지 않는다")


func test_gauge_shown_after_gladiator_loadout() -> void:
	_become_gladiator()
	assert_true(_gauge.visible, "검투사 로드아웃이 적용되면 게이지가 나타난다")


func test_gauge_hides_again_when_loadout_loses_finisher() -> void:
	_become_gladiator()
	var warrior: JobDefinition = _player.get_node("PlayerJobTransition").available_jobs[0]
	_player.apply_transition_loadout(warrior.skill_loadout(), warrior.basic_combo)
	assert_false(_gauge.visible, "피니셔가 없는 로드아웃으로 바뀌면 다시 숨는다")


# --- 3단 임계 표시 (형태 이중 신호 = 채움 굵기 + 임계 눈금 + 상태 텍스트) ---


func test_below_finisher_threshold_shows_base_state() -> void:
	_become_gladiator()
	_charge_by_hits(2)  ## 24 — 처형 하한(50) 미달

	assert_eq(_fill().color, RageGauge.COLOR_RAGE_BASE, "하한 미달은 어두운 기본색(#a22633)")
	assert_eq(_fill().size.y, RageGauge.FILL_HEIGHT_CHARGING, "하한 미달은 가장 얇은 채움")
	assert_false(_tick_lit("FinisherTick"), "처형 눈금 미점등")
	assert_false(_tick_lit("EnrageTick"), "격노 눈금 미점등")
	assert_false(_border().visible, "발광 테두리 없음")
	assert_eq(_label_text(), "분노 24 / 100", "상태 태그 없이 수치만 표기")


func test_finisher_ready_tier_is_distinct() -> void:
	_become_gladiator()
	_charge_by_hits(5)  ## 60 — 처형 가능(>=50), 격노(80) 미달

	assert_eq(_fill().color, RageGauge.COLOR_RAGE_CHARGED, "하한 이상은 충전색(#e43b44)")
	assert_eq(_fill().size.y, RageGauge.FILL_HEIGHT_READY, "하한 이상은 채움이 굵어진다")
	assert_true(_tick_lit("FinisherTick"), "처형 눈금 점등")
	assert_false(_tick_lit("EnrageTick"), "격노 눈금은 아직 미점등")
	assert_false(_border().visible, "격노가 아니므로 발광 테두리 없음")
	assert_true(_label_text().contains("처형 가능"), "처형 가능 표기")
	assert_false(_label_text().contains("격노"), "격노가 아닌데 격노로 표기하지 않는다")


func test_enraged_tier_is_distinct() -> void:
	_become_gladiator()
	_charge_by_hits(7)  ## 84 — 격노(>=80), 만땅 미달

	assert_eq(_fill().size.y, RageGauge.FILL_HEIGHT_ENRAGED, "격노 구간은 채움이 가장 굵다")
	assert_true(_tick_lit("FinisherTick"), "처형 눈금 점등 유지")
	assert_true(_tick_lit("EnrageTick"), "격노 눈금 점등")
	assert_true(_border().visible, "격노는 발광 테두리로 표시")
	assert_true(_label_text().contains("처형 가능"), "격노 중에도 처형은 별개 항목으로 표기")
	assert_true(_label_text().contains("격노"), "격노 표기")


func test_max_tier_shows_execution_maximum() -> void:
	_become_gladiator()
	_charge_by_hits(9)  ## 108 -> 100으로 클램프(만땅 = 최대 처형 계수)

	assert_eq(_fill().size.x, _gauge.get_node("Bar").size.x, "만땅은 바를 가득 채운다")
	assert_true(_border().visible, "만땅은 테두리 표시")
	assert_true(_label_text().contains("처형 최대"), "만땅은 최대 처형 계수임을 알린다")
	assert_true(_label_text().contains("격노"), "만땅은 격노 상태도 포함")


## 세 구간의 채움 굵기가 서로 달라야 한다(색만으로 구분하지 않는다는 요구의 핵심).
func test_three_tiers_have_distinct_fill_heights() -> void:
	assert_ne(RageGauge.FILL_HEIGHT_CHARGING, RageGauge.FILL_HEIGHT_READY)
	assert_ne(RageGauge.FILL_HEIGHT_READY, RageGauge.FILL_HEIGHT_ENRAGED)


## 격노 테두리 알파는 STYLE_GUIDE 6-1-1 B범주 상한(50%)을 넘지 않는다.
func test_enrage_border_alpha_within_style_guide_limit() -> void:
	assert_lte(RageGauge.ENRAGE_BORDER_ALPHA, 0.5, "자기 상태 오라 알파 ≤ 50%")


# --- 임계 눈금 위치는 데이터에서 계산된다 ---


func test_threshold_ticks_positioned_from_skill_data() -> void:
	_become_gladiator()
	var finisher: GladiatorSkillData = _player.rage.finisher
	var bar_width: float = _gauge.get_node("Bar").size.x
	var finisher_tick: ColorRect = _gauge.get_node("Bar/FinisherTick")
	var enrage_tick: ColorRect = _gauge.get_node("Bar/EnrageTick")

	var expected_finisher: float = (
		bar_width * (finisher.rage_finisher_min / finisher.rage_max) - RageGauge.TICK_WIDTH * 0.5
	)
	var expected_enrage: float = (
		bar_width * (finisher.rage_enrage_threshold / finisher.rage_max)
		- RageGauge.TICK_WIDTH * 0.5
	)
	assert_almost_eq(finisher_tick.position.x, expected_finisher, 0.5, "처형 눈금 = 50 위치")
	assert_almost_eq(enrage_tick.position.x, expected_enrage, 0.5, "격노 눈금 = 80 위치")


# --- 시그널 구독 갱신 (rage_changed / enrage_changed) ---


func test_gauge_follows_rage_changed_signal() -> void:
	_become_gladiator()
	var bar_width: float = _gauge.get_node("Bar").size.x
	_charge_by_hits(1)  ## 12 / 100

	assert_almost_eq(_fill().size.x, bar_width * 0.12, 0.5, "rage_changed 구독으로 채움 갱신")


func test_gauge_resets_after_finisher_consumes_rage() -> void:
	_become_gladiator()
	_charge_by_hits(7)
	assert_true(_border().visible, "소모 전에는 격노 표시")

	_player.rage.consume_for_finisher()

	assert_eq(_fill().size.x, 0.0, "처형 일격 발동으로 전량 소모되면 게이지가 비워진다")
	assert_false(_border().visible, "소모 후 격노 해제(enrage_changed) 반영")
	assert_false(_tick_lit("FinisherTick"), "소모 후 처형 눈금 소등")
	assert_eq(_label_text(), "분노 0 / 100", "소모 후 상태 태그 제거")


func test_gauge_reflects_enrage_release_by_decay() -> void:
	_become_gladiator()
	_charge_by_hits(7)  ## 84
	## 전투 이탈(5초) 후 감쇠 초당 -5 — 1초분을 더 진행해 80 미만으로 떨어뜨린다.
	_player.rage.advance(6.0)
	_player.rage.advance(1.0)

	assert_lt(_player.rage.current_rage, 80.0, "감쇠로 격노 임계 미달")
	assert_false(_border().visible, "80 미만이 되면 격노 표시가 사라진다")
	assert_true(_label_text().contains("처형 가능"), "여전히 50 이상이므로 처형은 가능")
