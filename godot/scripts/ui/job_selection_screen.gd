## 직업 선택 화면 (M3 전직 UI) — 1차 직업(전사/궁수) 및 2차 상위 계통(검투사) 선택 모달.
##
## **1차/2차 공용 (M3 C-1 확장)**: 초판은 `is_transitioned`면 열리지 않았는데, 그 조건 때문에
## 2차 전직(Lv40 검투사)에서 화면이 열리지 않아 디버그 키(F11)가 유일한 경로였다. 판정을
## **"다음 단계 후보가 없으면 닫힘"** 으로 바꿨다 — 계통 단계 수를 UI가 알 필요가 없고
## (`tier2_jobs`에 3차가 추가돼도 그대로 동작), 최종 계통에 도달하면 후보가 비어 자연히
## 열리지 않는다. 후보 목록은 반드시 B-5가 계산한 것을 그대로 써야 한다 — 카드 인덱스를
## `request_transition_by_index`에 되돌려 주므로 UI가 같은 규칙을 다시 구현하면 어긋난다.
##
## `docs\design\systems\jobs.md` 1장(모험가 Lv1~10 -> Lv10 1차 전직)·6장(전직 보상: 스킬
## 개방·스킬 포인트 +2·직업 무기)의 문구를 그대로 안내하고, 선택 시
## `PlayerJobTransition.request_transition_by_index(index)`(B-5 공개 API)를 호출한다.
## 성공/실패 판정과 실제 적용(스탯 재계산·슬롯 개방·무기 교체)은 전부 B-5가 하고, 이 화면은
## 결과만 받아 닫힌다 — 단방향 데이터 흐름(skill_tab.gd와 동일 기조).
##
## 직업 카드는 씬에 고정하지 않고 전직 후보 목록으로 런타임 생성한다 — 직업이 늘어도
## (히든 직업 등) .tres 추가만으로 카드가 늘어난다. 표시 정보는 JobDefinition/JobGrowthData에
## 이미 있는 값만 쓴다(직업명·주스탯·개방 슬롯 수·지급 무기) — 직업별 소개 문구는 데이터에
## 없으므로 넣지 않았다(임의 창작 금지 — 결과 보고 "UX 설계 필요" 참조).
##
## 통합 메뉴와 같은 풀스크린 모달 규약을 따른다: 열면 게임 일시정지, ESC로 닫기, 열려 있는
## 동안 다른 화면 단축키 비활성(ux 4장 "모달 우선"). 정식 전직 절차(도시 전직 기관 + 전직
## 시험 퀘스트, jobs.md 6장)의 NPC·퀘스트 경로는 후속 작업이며, 그전까지 이 화면이 전직
## 가능 알림에서 바로 열리는 정식 진입점이다.
class_name JobSelectionScreen
extends Control

## 전직이 실제로 성공했을 때 새 직업 id를 실어 발신 — HUD 후속 훅용.
signal job_selected(job_id: StringName)

## 카드 1장 크기(1920x1080 기준). 세로는 내용에 맞춰 늘어난다.
const CARD_WIDTH := 396
## 주스탯 표시명 — JobGrowthData.MainStat 열거값 순서(STR/AGI/INT/VIT)와 1:1.
const MAIN_STAT_NAMES: Array[String] = ["힘", "민첩", "지력", "체력"]

var _transition: PlayerJobTransition = null

@onready var _dim: ColorRect = $Dim
@onready var _panel: Panel = $Panel
@onready var _title_label: Label = $Panel/VBox/TitleLabel
@onready var _guide_label: Label = $Panel/VBox/GuideLabel
@onready var _cards_row: HBoxContainer = $Panel/VBox/CardsRow
@onready var _footer_label: Label = $Panel/VBox/FooterLabel


func _ready() -> void:
	## 스스로 게임을 일시정지시키므로 정지 중에도 계속 동작해야 한다(통합 메뉴와 동일).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.color = Color(UiStyle.COLOR_OUTLINE, 0.92)
	_panel.add_theme_stylebox_override("panel", UiStyle.make_panel_stylebox())
	## 제목은 본문 등급(갈무리11×3=33px)의 다음 정수배인 44px(×4)를 쓴다 — 픽셀 폰트는
	## 정수 배수만 허용(ux 5-0절 폰트 규칙).
	UiStyle.apply_body_font(_title_label, 44)
	_title_label.add_theme_color_override("font_color", UiStyle.COLOR_EXP)
	UiStyle.apply_label_font(_guide_label)
	_guide_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	UiStyle.apply_label_font(_footer_label)
	_footer_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_SUB)
	visible = false


## transition: player.tscn의 "PlayerJobTransition" 자식. null이면(구버전 씬) 화면이 열리지 않는다.
func bind_transition(transition: PlayerJobTransition) -> void:
	_transition = transition
	_build_cards()


## 전직 가능 상태에서만 열린다 — 조건은 B-5의 상태를 그대로 신뢰한다. 1차·2차 구분은 하지
## 않고 "지금 갈 수 있는 후보가 있는가"로만 판정한다(헤더 참조). 후보는 현재 직업에 따라
## 달라지므로 열 때마다 카드를 다시 만든다.
func open() -> void:
	if _transition == null or not _transition.transition_available:
		return
	_build_cards()
	if _cards_row.get_child_count() == 0:
		return  ## 최종 계통(또는 상위 직업 데이터 미등록) — 열 화면이 없다
	_refresh_texts()
	visible = true
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func is_open() -> bool:
	return visible


## 열려 있는 동안 키 입력을 독점한다(ux 4장 "모달 우선" — 통합 메뉴 단축키·전직 알림 V 키가
## 이 화면 위에서 반응하면 안 된다). `_input`은 `_unhandled_input`보다 먼저 돌기 때문에
## 여기서 처리 완료로 표시하면 다른 화면이 같은 키를 받지 않는다. 마우스 이벤트는 삼키지
## 않는다 — 카드의 선택 버튼이 클릭을 받아야 하기 때문(전체 화면 Dim이 월드로 새는 것은 막는다).
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event == null:
		return
	get_viewport().set_input_as_handled()
	if not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.keycode == KEY_ESCAPE:
		close()
		return
	## 숫자 키 1~9로도 선택할 수 있다(카드에 표기된 번호와 일치).
	var index: int = key_event.keycode - KEY_1
	if index >= 0 and index <= 8:
		_select_job(index)


func _build_cards() -> void:
	for child in _cards_row.get_children():
		_cards_row.remove_child(child)
		child.queue_free()
	var candidates := _candidate_jobs()
	for i in candidates.size():
		var job_def: JobDefinition = candidates[i]
		if job_def == null:
			continue
		_cards_row.add_child(_make_card(i, job_def))


## 지금 전직할 수 있는 직업 후보 — **B-5의 판정을 그대로 쓴다**. 카드 인덱스가 그대로
## `request_transition_by_index`의 인덱스이므로 목록 산출을 UI에서 다시 구현하면 안 된다
## (미전직이면 available_jobs 그대로, 전직 후에는 required_job_id가 맞는 상위 계통만).
## 공개 접근자가 없어 B-5의 내부 함수를 호출한다 — 공개 API 승격 요청은 결과 보고에 남겼다.
func _candidate_jobs() -> Array[JobDefinition]:
	if _transition == null:
		return []
	return _transition._candidate_jobs()


## 제목·안내문을 현재 전직 단계에 맞춘다(1차 Lv10 / 2차 Lv40). 임계 레벨은 후보 직업의
## 정의(transition_level_override)에서 읽으므로 데이터가 바뀌어도 문구가 따라간다.
func _refresh_texts() -> void:
	_title_label.text = "2차 전직" if _transition.is_transitioned else "1차 전직"
	_guide_label.text = (
		(
			"Lv.%d 도달 — 직업을 선택하면 즉시 전직이 완료됩니다.\n"
			+ "· 직업 스킬 슬롯 개방 (4 · Q · E · R · 우클릭)\n"
			+ "· 스킬 포인트 +2\n"
			+ "· 직업 전용 무기 지급 — 카드의 '지급 무기' 표기 확인"
		)
		% _threshold_level()
	)


## 후보 계통의 전직 임계 레벨(계통 내에서는 동일하다). 후보가 없으면 0.
func _threshold_level() -> int:
	for job_def in _candidate_jobs():
		if job_def != null:
			return job_def.transition_level()
	return 0


## 직업 카드 1장 — 번호+직업명, 주스탯, 개방 슬롯 수, 지급 무기, 선택 버튼.
func _make_card(index: int, job_def: JobDefinition) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", UiStyle.make_panel_stylebox())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	var name_label := Label.new()
	UiStyle.apply_body_font(name_label)
	name_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	name_label.text = "%d. %s" % [index + 1, job_def.display_name]
	box.add_child(name_label)

	box.add_child(_make_detail_label("주스탯: %s" % _main_stat_name(job_def)))
	box.add_child(_make_detail_label("개방 스킬: %d종" % _open_skill_count(job_def)))
	box.add_child(_make_detail_label("지급 무기: %s" % _granted_weapon_name(job_def)))

	var button := Button.new()
	UiStyle.apply_label_font(button)
	button.custom_minimum_size = Vector2(0, 60)
	button.text = "%s 전직 (%d)" % [job_def.display_name, index + 1]
	button.pressed.connect(_select_job.bind(index))
	box.add_child(button)
	return card


func _make_detail_label(text: String) -> Label:
	var label := Label.new()
	UiStyle.apply_label_font(label)
	label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_SUB)
	label.text = text
	return label


func _main_stat_name(job_def: JobDefinition) -> String:
	if job_def.growth == null:
		return "-"
	return MAIN_STAT_NAMES[int(job_def.growth.main_stat)]


## 이 직업이 실제로 채우는 스킬 슬롯 수(승계형 교체 — null 슬롯은 미개방). 궁수처럼 고유
## 스킬이 아직 미구현인 직업은 공용 3종만 세어져 그대로 표시된다(과장 없이 사실만 노출).
func _open_skill_count(job_def: JobDefinition) -> int:
	var count := 0
	for skill in job_def.skill_loadout().values():
		if skill != null:
			count += 1
	return count


func _granted_weapon_name(job_def: JobDefinition) -> String:
	if job_def.granted_weapon == null:
		return "없음 (준비 중)"
	return job_def.granted_weapon.item_name


## 전직 실행 — 성공하면 화면을 닫는다. 실패(범위 밖 번호·조건 미충족)면 아무 일도 없다.
func _select_job(index: int) -> void:
	if _transition == null:
		return
	if not _transition.request_transition_by_index(index):
		return
	job_selected.emit(_transition.current_job_id)
	close()
