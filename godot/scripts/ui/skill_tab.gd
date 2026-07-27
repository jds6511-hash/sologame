## S08 통합 메뉴 — 스킬 탭 (스킬 포인트·강화 화면, M3 B-4).
##
## `docs\art\ux\ux-foundation.md` 3장 S08(스킬 탭)·5장 정보 위계("스킬 강화는 상시 표시가
## 아님 → 통합 메뉴"). PlayerSkillPoints(B-3)를 구독해 잔여 포인트·스킬별 강화 레벨을 표시하고,
## 강화 버튼으로 try_upgrade_skill을 호출한다. 결과(포인트 차감·레벨 상승)는
## points_changed·skill_upgraded 시그널로 되돌아와 표시를 갱신한다(단방향 데이터 흐름).
##
## 스킬 행은 씬에 고정하지 않고 bind()가 넘겨받은 스킬 목록으로 런타임 생성한다 — 직업/스킬이
## 늘어도(전직·2번째 직업) 그대로 재사용된다. skill_id는 WarriorSkillData.skill_name,
## 궁극기 여부는 skill_type == ULTIMATE로 판정한다(PlayerSkillPoints 계약과 일치).
class_name SkillTab
extends Control

var _skill_points: PlayerSkillPoints = null
## [{ id: StringName, is_ultimate: bool, level_label: Label, button: Button }]
var _rows: Array = []

@onready var _points_label: Label = $VBox/PointsLabel
@onready var _skill_list: VBoxContainer = $VBox/SkillList


func _ready() -> void:
	UiStyle.apply_body_font(_points_label)
	_points_label.add_theme_color_override("font_color", UiStyle.COLOR_EXP)


## skill_points: PlayerSkillPoints(B-3). skills: 강화 대상 WarriorSkillData 배열(플레이어의
## 스킬 슬롯 7종 등). 호출자(통합 메뉴)가 player에서 모아 넘긴다.
func bind(skill_points: PlayerSkillPoints, skills: Array) -> void:
	_skill_points = skill_points
	_build_rows(skills)
	skill_points.points_changed.connect(_on_points_changed)
	skill_points.skill_upgraded.connect(_on_skill_upgraded)
	_refresh_all()


func _build_rows(skills: Array) -> void:
	for child in _skill_list.get_children():
		child.queue_free()
	_rows.clear()
	for skill in skills:
		if skill == null:
			continue
		_add_row(skill)


func _add_row(skill: WarriorSkillData) -> void:
	var is_ultimate: bool = skill.skill_type == WarriorSkillData.SkillType.ULTIMATE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(260, 0)
	UiStyle.apply_body_font(name_label)
	name_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	name_label.text = skill.skill_name + ("  [궁극기]" if is_ultimate else "")

	var level_label := Label.new()
	level_label.custom_minimum_size = Vector2(150, 0)
	UiStyle.apply_label_font(level_label)
	level_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_SUB)

	var button := Button.new()
	UiStyle.apply_label_font(button)
	button.custom_minimum_size = Vector2(180, 0)
	button.pressed.connect(_on_upgrade_pressed.bind(StringName(skill.skill_name), is_ultimate))

	row.add_child(name_label)
	row.add_child(level_label)
	row.add_child(button)
	_skill_list.add_child(row)

	var row_refs := {
		"id": StringName(skill.skill_name),
		"is_ultimate": is_ultimate,
		"level_label": level_label,
		"button": button,
	}
	_rows.append(row_refs)


## 강화 시도 — 성공/실패 판정은 PlayerSkillPoints가 하고, 표시 갱신은 시그널이 처리한다.
func _on_upgrade_pressed(skill_id: StringName, is_ultimate: bool) -> void:
	_skill_points.try_upgrade_skill(skill_id, is_ultimate)


func _on_points_changed(available_points: int, _spent_points: int) -> void:
	_points_label.text = "스킬 포인트: %d" % available_points
	for row in _rows:
		_refresh_row(row)


func _on_skill_upgraded(_skill_id: StringName, _new_level: int) -> void:
	for row in _rows:
		_refresh_row(row)


func _refresh_all() -> void:
	_points_label.text = "스킬 포인트: %d" % _skill_points.available_points
	for row in _rows:
		_refresh_row(row)


## 한 스킬 행의 레벨 라벨·강화 버튼을 현재 상태로 갱신한다. 만렙이면 버튼을 "만렙"으로 잠그고,
## 포인트가 부족하면(can_upgrade_skill=false) 버튼을 비활성화한다(ux 색+비활성 이중 신호).
func _refresh_row(row: Dictionary) -> void:
	var skill_id: StringName = row["id"]
	var is_ultimate: bool = row["is_ultimate"]
	var level: int = _skill_points.get_skill_level(skill_id)
	var max_level: int = _skill_points.rule.max_skill_level(is_ultimate)
	var level_label: Label = row["level_label"]
	var button: Button = row["button"]
	level_label.text = "Lv.%d / %d" % [level, max_level]
	if level >= max_level:
		button.text = "만렙"
		button.disabled = true
		return
	var cost: int = _skill_points.rule.upgrade_cost(level, is_ultimate)
	button.text = "강화 (%d)" % cost
	button.disabled = not _skill_points.can_upgrade_skill(skill_id, is_ultimate)
