## HUD 분노 게이지 (M3 C-1 UI) — 검투사(전사 2차 전직) 전용 자원 게이지.
##
## `PlayerRageModule`(scripts/player/player_rage_module.gd)의 공개 시그널
## `rage_changed(current, max)` · `enrage_changed(is_enraged)`만 구독하는 단방향 표시 위젯이다
## (skill_tab.gd·job_selection_screen.gd와 같은 기조 — 게이지 상태는 전부 모듈이 소유한다).
##
## **비검투사에서는 아예 표시되지 않는다**: 모듈은 우클릭 격노 파생 스킬(처형 일격)이 배선된
## 직업에서만 활성이라(`is_active()`), 1차 전사·궁수·모험가에서는 finisher가 null이다. 게이지는
## 매 갱신마다 `is_active()`를 다시 보고 visible을 정하므로, 전직 로드아웃 교체(refresh_job ->
## reset -> rage_changed 발신) 순간 자동으로 나타나고 사라진다 — job_changed 구독이 불필요하다.
##
## **3단 시각화** (`docs\design\systems\m3-warrior-tier2-skills.md` 2-1·2-3장): 50 = 처형 일격
## 발동 가능 / 80 = 격노 진입(공격력 +12%) / 100 = 최대 처형 계수. 세 구간이 플레이어 판단
## ("지금 터뜨릴까, 격노까지 참을까, 만땅을 노릴까")의 근거이므로 각각 다르게 보여야 한다.
## 처형은 **분노 ≥ 50에서 격노와 무관하게** 발동 가능하므로 라벨도 두 상태를 따로 표기한다.
## 임계값은 하드코딩하지 않고 피니셔 리소스(GladiatorSkillData)에서 읽어 눈금 위치까지
## 계산한다 — 밸런스 튜닝이 .tres 한 곳에서 끝난다.
##
## **색·형태 규격** (`docs\art\STYLE_GUIDE.md` 6-1-1 A/B범주 화이트리스트): 바 기본
## `#a22633`(HP 바 `#e43b44`보다 어둡다) / 충전분 `#e43b44` / 만땅 테두리 `#feae34`.
## 색만으로 구분하지 않기 위한 **형태 이중 신호 3중**: ① 구간별 채움 굵기 3단(1/3 -> 2/3 ->
## 꽉 = 6 -> 12 -> 18px, 바닥 정렬이라 단계가 오를 때 굵어지는 것이 보인다) ② 임계 눈금 2개
## (50·80 위치에 바 위아래로 튀어나온 세로 틱 — 통과하면 점등) ③ 한국어 상태 텍스트
## ("처형 가능" · "격노" · "처형 최대").
## 격노 발광은 B범주 한도(외곽 2px·알파 ≤ 50%) 안에서 **바 바깥쪽 테두리 맥동**으로 준다 —
## 테두리를 바 위에 겹치면 채움(붉은색) 위의 붉은 2px 선이 보이지 않아 신호 구실을 못한다.
##
## 위치: 스킬 슬롯 바(ux-foundation 5장 F행, (600, 924)) 바로 위에 같은 폭으로 붙였다 —
## 처형 일격이 우클릭 파생이라 시선이 머무는 곳이 스킬 바이고, 좌상 A열(A' 버프 아이콘·G 펫
## 상태 예약분)을 침범하지 않기 때문이다. **ux-foundation.md에 분노 게이지 항목이 없어 기존
## 앵커 규칙에서 파생시킨 배치이므로 정식 UX 설계 시 재확인이 필요하다**(결과 보고 "UX 설계
## 필요" 참조 — job_transition_notice.gd가 E행 앵커를 재사용한 것과 같은 상황).
class_name RageGauge
extends Control

## 게이지 구간. CHARGING = 처형 불가 / FINISHER_READY = 처형 가능(>=50) /
## ENRAGED = 처형 가능 + 격노(>=80) / MAX = 만땅(최대 처형 계수).
enum Tier { CHARGING, FINISHER_READY, ENRAGED, MAX }

## STYLE_GUIDE 6-1-1 A범주 확정색 (변경 금지 — art-director 판정 D3-A2-2).
const COLOR_RAGE_BASE := Color("#a22633")  ## 처형 하한 미달 구간(HP 바보다 어둡다)
const COLOR_RAGE_CHARGED := Color("#e43b44")  ## 처형 하한 이상 충전분
const COLOR_RAGE_FULL := Color("#feae34")  ## 만땅 발광 테두리·통과한 임계 눈금

## 구간별 채움 굵기(px) — 색과 무관한 1차 이중 신호. 바 높이(18)의 1/3 · 2/3 · 전체를 써서
## 한눈에 "몇 단인지" 읽히게 하고, 바닥 정렬로 위로 자라게 한다.
const FILL_HEIGHT_CHARGING := 6.0
const FILL_HEIGHT_READY := 12.0
const FILL_HEIGHT_ENRAGED := 18.0

## 격노 테두리 맥동 1회 길이(현실 초)와 알파 상한(B범주 "알파 ≤ 50%").
const ENRAGE_PULSE_SEC := 0.8
const ENRAGE_BORDER_ALPHA := 0.5

const TICK_WIDTH := 3.0
## 아직 통과하지 못한 임계 눈금 색(보조 텍스트색을 낮춘 값 — 위치만 알려 준다).
const TICK_COLOR_PENDING := Color(0.75294118, 0.79607844, 0.86274510, 0.45)

var _rage: PlayerRageModule = null
var _bar_width := 0.0
var _bar_height := 0.0
var _pulse_tween: Tween = null
## 지금 테두리에 적용된 구간(Tier) — 같은 구간이면 트윈·스타일박스를 다시 만들지 않는다.
var _border_tier: int = -1

@onready var _state_label: Label = $StateLabel
@onready var _bar: Control = $Bar
@onready var _background: ColorRect = $Bar/Background
@onready var _fill: ColorRect = $Bar/Fill
@onready var _finisher_tick: ColorRect = $Bar/FinisherTick
@onready var _enrage_tick: ColorRect = $Bar/EnrageTick
@onready var _border: Panel = $Bar/Border


func _ready() -> void:
	UiStyle.apply_label_font(_state_label)
	_state_label.add_theme_color_override("font_outline_color", UiStyle.COLOR_OUTLINE)
	_state_label.add_theme_constant_override("outline_size", 4)
	_background.color = UiStyle.COLOR_OUTLINE
	_bar_width = _bar.size.x
	_bar_height = _bar.size.y
	_finisher_tick.size.x = TICK_WIDTH
	_enrage_tick.size.x = TICK_WIDTH
	_border.visible = false
	## 검투사 로드아웃이 적용될 때까지 숨긴다(bind 전에는 어떤 직업인지 알 수 없다).
	visible = false


## player: player.tscn 루트(PlayerController). 분노 모듈은 컨트롤러가 소유한 RefCounted이며
## 전직 시에도 교체되지 않고 refresh_job으로 내용만 갱신되므로, 시그널은 1회만 연결한다.
func bind_player(player: PlayerController) -> void:
	_rage = player.rage
	_rage.rage_changed.connect(_on_rage_changed)
	_rage.enrage_changed.connect(_on_enrage_changed)
	## 디버그 직행 시작(initial_job_id = gladiator)처럼 bind 시점에 이미 활성인 경우도 반영.
	refresh()


func _on_rage_changed(_current_rage: float, _max_rage: float) -> void:
	refresh()


func _on_enrage_changed(_is_enraged: bool) -> void:
	refresh()


## 현재 모듈 상태를 화면에 다시 그린다(테스트·외부 호출 공용).
##
## 구간 판정을 격노 플래그가 아니라 **게이지 값**으로 하는 이유: 모듈은 값 변경 시
## rage_changed를 먼저 발신하고 그 다음에 격노 진입/해제를 재평가하므로(`_add`), 플래그를
## 기준으로 삼으면 80을 넘긴 프레임에 한 번 어긋난 화면이 보인다.
func refresh() -> void:
	if _rage == null or not _rage.is_active() or _rage.max_rage() <= 0.0:
		visible = false
		_apply_border(Tier.CHARGING)
		return
	visible = true
	var max_rage := _rage.max_rage()
	var current: float = _rage.current_rage
	var tier := _tier_of(current)
	_place_tick(_finisher_tick, _rage.finisher.rage_finisher_min / max_rage)
	_place_tick(_enrage_tick, _rage.finisher.rage_enrage_threshold / max_rage)
	_apply_fill(current / max_rage, tier)
	_apply_ticks(tier)
	_apply_border(tier)
	_apply_label(current, max_rage, tier)


func _tier_of(current: float) -> Tier:
	if current >= _rage.max_rage():
		return Tier.MAX
	if current >= _rage.finisher.rage_enrage_threshold:
		return Tier.ENRAGED
	if current >= _rage.finisher.rage_finisher_min:
		return Tier.FINISHER_READY
	return Tier.CHARGING


## 임계 눈금을 게이지 비율 위치에 세운다(눈금 폭 때문에 반 칸 왼쪽으로 보정).
func _place_tick(tick: ColorRect, ratio: float) -> void:
	tick.position.x = _bar_width * clampf(ratio, 0.0, 1.0) - TICK_WIDTH * 0.5


## 채움 폭 = 게이지 비율, 채움 굵기 = 구간(색맹 대응 1차 신호). 바닥 정렬이라 구간이 올라갈
## 때 위로 두꺼워진다.
func _apply_fill(ratio: float, tier: Tier) -> void:
	var height := _fill_height(tier)
	_fill.size = Vector2(_bar_width * clampf(ratio, 0.0, 1.0), height)
	_fill.position.y = _bar_height - height
	_fill.color = COLOR_RAGE_BASE if tier == Tier.CHARGING else COLOR_RAGE_CHARGED


func _fill_height(tier: Tier) -> float:
	match tier:
		Tier.CHARGING:
			return FILL_HEIGHT_CHARGING
		Tier.FINISHER_READY:
			return FILL_HEIGHT_READY
		_:
			return FILL_HEIGHT_ENRAGED


## 통과한 임계 눈금만 점등한다 — 50/80 두 지점이 각각 켜지므로 구간을 눈금 개수로도 읽는다.
func _apply_ticks(tier: Tier) -> void:
	var finisher_passed := tier != Tier.CHARGING
	var enrage_passed := tier == Tier.ENRAGED or tier == Tier.MAX
	_finisher_tick.color = COLOR_RAGE_FULL if finisher_passed else TICK_COLOR_PENDING
	_enrage_tick.color = COLOR_RAGE_FULL if enrage_passed else TICK_COLOR_PENDING


## 격노(>=80)는 붉은 테두리 맥동(B범주 외곽 2px·알파 ≤ 50%), 만땅은 `#feae34` 고정 테두리
## (A범주 "만땅 발광 테두리")로 구분한다. 테두리 프레임은 바보다 4px 바깥에 있어(씬 오프셋)
## 채움 색에 묻히지 않는다.
func _apply_border(tier: Tier) -> void:
	if tier == Tier.CHARGING or tier == Tier.FINISHER_READY:
		_stop_pulse()
		_border.visible = false
		_border_tier = -1
		return
	_border.visible = true
	if _border_tier == int(tier):
		return
	_stop_pulse()
	if tier == Tier.MAX:
		_set_border_color(COLOR_RAGE_FULL)
	else:
		_set_border_color(COLOR_RAGE_CHARGED)
		_start_pulse()
	_border_tier = int(tier)


func _set_border_color(color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.set_border_width_all(2)
	box.border_color = color
	_border.add_theme_stylebox_override("panel", box)


func _start_pulse() -> void:
	_border.modulate.a = ENRAGE_BORDER_ALPHA
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(
		_border, "modulate:a", ENRAGE_BORDER_ALPHA * 0.5, ENRAGE_PULSE_SEC * 0.5
	)
	_pulse_tween.tween_property(_border, "modulate:a", ENRAGE_BORDER_ALPHA, ENRAGE_PULSE_SEC * 0.5)


func _stop_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	_border.modulate.a = 1.0


## 상태 텍스트(3차 신호) — 처형 가능(>=50)과 격노(>=80)를 **별개 항목으로** 나열한다.
## "격노 시 처형"이 아니라 "처형 가능 · 격노"다(2-3장 표기 통일).
func _apply_label(current: float, max_rage: float, tier: Tier) -> void:
	var tags := PackedStringArray()
	if tier == Tier.MAX:
		tags.append("처형 최대")
	elif tier != Tier.CHARGING:
		tags.append("처형 가능")
	if tier == Tier.ENRAGED or tier == Tier.MAX:
		var buff_percent := roundi(_rage.finisher.enrage_attack_buff_percent * 100.0)
		tags.append("격노 공격력 +%d%%" % buff_percent)
	var text := "분노 %d / %d" % [roundi(current), roundi(max_rage)]
	if not tags.is_empty():
		text += " — " + " · ".join(tags)
	_state_label.text = text
	_state_label.add_theme_color_override("font_color", _label_color(tier))


func _label_color(tier: Tier) -> Color:
	match tier:
		Tier.CHARGING:
			return UiStyle.COLOR_TEXT_SUB
		Tier.MAX:
			return COLOR_RAGE_FULL
		_:
			return UiStyle.COLOR_TEXT
