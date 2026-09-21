extends CanvasLayer

var session: Node
var panel: PanelContainer
var confirmation: ConfirmationDialog
var slots: OptionButton
var status: Label
var badge: Button
var _action := ""
var _slot := 0
var _integrated_mode: Node.ProcessMode
var _owns_pause := false


func setup(owner_session: Node) -> void:
	session = owner_session
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	var root := Control.new()
	var theme := Theme.new()
	theme.default_font = load(UiStyle.FONT_BODY_PATH)
	theme.default_font_size = UiStyle.FONT_SIZE_BODY
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	badge = Button.new()
	badge.text = "저장·불러오기 [F6]"
	badge.position = Vector2(710, 12)
	badge.custom_minimum_size = Vector2(500, 42)
	badge.add_theme_font_size_override("font_size", 24)
	badge.pressed.connect(open_menu)
	root.add_child(badge)
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -440
	panel.offset_right = 440
	panel.offset_top = -380
	panel.offset_bottom = 380
	panel.add_theme_stylebox_override("panel", UiStyle.make_panel_stylebox())
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	var title := Label.new()
	title.text = "저장 · 불러오기"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	slots = OptionButton.new()
	box.add_child(slots)
	for action in ["save", "load", "new"]:
		var button := Button.new()
		button.text = {"save": "선택 슬롯에 저장", "load": "선택 슬롯 불러오기", "new": "새 캐릭터 시작"}[action]
		button.pressed.connect(request_action.bind(action))
		box.add_child(button)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(800, 130)
	box.add_child(status)
	var warning := Label.new()
	warning.text = "안전한 곳에서 멈춘 뒤 저장하세요.\n불러오면 적이 다시 배치됩니다.\n줍지 않은 아이템은 사라집니다."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warning)
	var close := Button.new()
	close.text = "돌아가기 [Esc]"
	close.pressed.connect(close_menu)
	box.add_child(close)
	confirmation = ConfirmationDialog.new()
	confirmation.theme = theme
	confirmation.title = "진행 확인"
	confirmation.ok_button_text = "진행"
	confirmation.cancel_button_text = "취소"
	confirmation.confirmed.connect(_confirm_action)
	add_child(confirmation)
	panel.hide()
	session.status_changed.connect(_show_status)
	_show_status(session.last_message)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F6:
		if panel.visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and panel.visible:
		close_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if panel.visible or session._change_blocked():
		return
	var integrated = session.world.get_node("IntegratedMenu")
	if integrated.is_open() or get_tree().paused:
		return
	_integrated_mode = integrated.process_mode
	integrated.process_mode = Node.PROCESS_MODE_DISABLED
	_owns_pause = true
	get_tree().paused = true
	refresh_slots()
	panel.show()
	_show_status(session.last_message)


func close_menu() -> void:
	confirmation.hide()
	panel.hide()
	if _owns_pause:
		session.world.get_node("IntegratedMenu").process_mode = _integrated_mode
		get_tree().paused = false
		_owns_pause = false


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false


func refresh_slots() -> void:
	var selected := maxi(slots.selected, 0)
	slots.clear()
	for slot in range(1, 11):
		var result: Dictionary = {"ok": false, "code": session.account_error}
		if session.account_error.is_empty():
			result = session.store.read_save("character", slot)
		var text: String = "빈 슬롯" if result.code == "missing" else error_text(result.code)
		if result.ok:
			text = (
				"%s · Lv%d · %s%s"
				% [
					result.data.name,
					int(result.data.player.level),
					{"adventurer": "모험가", "warrior": "전사", "archer": "궁수", "gladiator": "검투사"}.get(
						result.data.player.job_id, result.data.player.job_id
					),
					" (백업)" if result.recovered else ""
				]
			)
		if session.active_slot == slot:
			text += " · 자동 저장 대상"
		slots.add_item("%02d  %s" % [slot, text])
	slots.select(selected)


func request_action(action: String) -> void:
	_action = action
	_slot = slots.selected + 1
	confirmation.dialog_text = (
		"슬롯 %02d에 저장합니다.\n기존 캐릭터가 있다면 덮어씁니다." % _slot
		if action == "save"
		else "저장하지 않은 진행을 버립니다.\n계속하시겠습니까?"
	)
	confirmation.popup_centered(Vector2i(560, 160))


func _confirm_action() -> void:
	var result: Dictionary
	match _action:
		"save":
			result = session.save_slot(_slot)
		"load":
			result = session.load_slot(_slot)
		"new":
			result = session.new_character()
		_:
			return
	if not result.ok:
		var message: String = error_text(result.code)
		if result.has("main_code"):
			message += (
				"\n주 파일: %s / 백업: %s"
				% [error_text(result.main_code), error_text(result.backup_code)]
			)
		_show_status(message)
	elif _action == "save":
		refresh_slots()


func _show_status(message: String) -> void:
	status.text = message
	badge.tooltip_text = message
	if session.active_slot > 0:
		badge.text = "저장 [F6] · 자동 슬롯 %02d" % session.active_slot
	if message.begins_with("자동 저장"):
		badge.text = "[F6] " + message


static func error_text(code: String) -> String:
	if code.begins_with("account_") and code != "account_mismatch":
		return "계정 파일: " + error_text(code.trim_prefix("account_"))
	return (
		{
			"missing": "파일 없음",
			"not_checked": "검사하지 않음",
			"ok": "정상",
			"death_sequence": "부활이 끝난 뒤 다시 시도하세요.",
			"boss_encounter": "보스전 중에는 저장할 수 없습니다. 종료 후 안전한 곳에서 저장하세요.",
			"player_locked": "행동 제한이 끝난 뒤 다시 시도하세요.",
			"action_in_progress": "공격과 회피를 마친 뒤 저장하세요.",
			"moving": "멈춘 뒤 다시 저장하세요.",
			"recent_combat": "마지막 전투 행동 후 5초 동안 기다려 주세요.",
			"cooldown_or_buff": "재사용 대기와 임시 효과가 끝난 뒤 저장하세요.",
			"enemy_nearby": "적에게서 떨어진 안전한 곳에서 저장하세요.",
			"corrupt": "파일 손상",
			"invalid_data": "저장 내용 오류",
			"unsupported_version": "지원하지 않는 저장 버전",
			"too_large": "파일 크기 초과",
			"io_error": "파일 읽기·쓰기 실패",
			"account_mismatch": "계정이 일치하지 않습니다.",
			"pending_transfer": "미완료 창고 거래가 있습니다.",
			"unsupported_transfer_history": "지원하지 않는 거래 기록입니다.",
			"position_outside_map": "저장 위치가 현재 지도 밖입니다.",
			"session_blocked": "현재 상태에서는 캐릭터를 바꿀 수 없습니다."
		}
		. get(code, "저장 처리 실패 (%s)" % code)
	)
