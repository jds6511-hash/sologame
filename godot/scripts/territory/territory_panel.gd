extends CanvasLayer
const Model = preload("res://scripts/territory/territory_model.gd")
const Travel = preload("res://scripts/territory/territory_travel.gd")
const Content = preload("res://scripts/content/game_content.gd")
const ERRORS := {
	"warp_departure": "도시 서쪽 입구의 워프 표식 또는 소유 영지 관리인 가까이에서 이용하세요.",
	"ownership": "소유 영지가 없습니다.",
	"onsite": "영지 관리인 가까이에서 이용하세요.",
	"gold": "골드가 부족합니다.",
	"gold_limit": "골드 보유 한도 때문에 처리할 수 없습니다.",
	"quantity": "들개 이빨 3개가 필요합니다.",
	"material": "들개 이빨 3개가 필요합니다.",
	"order_unavailable": "이미 납품했습니다. 다음 주문을 기다려 주세요.",
	"facility_limit": "이미 건설했거나 시설 슬롯이 가득 찼습니다.",
	"development_limit": "모든 외형 복구를 완료했습니다.",
	"cooldown": "귀환 인장을 다시 사용할 때까지 기다려 주세요.",
	"player_unavailable": "사망 또는 캐릭터 전환 중에는 이용할 수 없습니다.",
	"session_blocked": "다른 창이나 캐릭터 전환이 끝난 뒤 시도하세요.",
	"region_locked": "목적지에 필요한 의뢰를 먼저 완료하세요."
}
var runtime: Node
var arbiter: UiPauseArbiter
var box: VBoxContainer
var message: Label
var opened := false
var confirmation: ConfirmationDialog
var pending := ""
var selected_holding := ""


func setup(controller: Node) -> void:
	runtime = controller
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	arbiter = UiPauseArbiter.for_world(get_parent())
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.05, 0.97)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(120, 70)
	panel.size = Vector2(1680, 940)
	add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "영지 투자 확인"
	add_child(confirmation)
	confirmation.confirmed.connect(_confirm)
	confirmation.canceled.connect(func(): pending = "")
	runtime.changed.connect(_refresh_if_open)
	hide()


func open() -> bool:
	if runtime.player.get_node("PlayerStats").is_dead() or not arbiter.acquire(self):
		return false
	opened = true
	selected_holding = runtime.onsite()
	show()
	_refresh()
	return true


func close() -> void:
	pending = ""
	confirmation.hide()
	opened = false
	hide()
	arbiter.release(self)


func _unhandled_input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("menu_pause"):
		close()
		get_viewport().set_input_as_handled()


func _refresh_if_open() -> void:
	if opened:
		_refresh()


func _label(text: String, size: int = 26) -> Label:
	var label := Label.new()
	label.text = text
	UiStyle.apply_body_font(label, size)
	box.add_child(label)
	return label


func _button(text: String, callback: Callable, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = text
	UiStyle.apply_action_button(button)
	button.disabled = disabled
	box.add_child(button)
	button.pressed.connect(callback)


func _refresh() -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	_label("영지와 도시 이동", 36)
	_button("닫기 [Esc]", close)
	var data: Dictionary = runtime.state()
	var economy: Dictionary = runtime.player.get_meta("economy_candidate").state()
	_label("보유 골드: %dG" % economy.gold)
	var owned: bool = not data.holdings.is_empty()
	if not data.holdings.has(selected_holding):
		selected_holding = data.representative
	var onsite: bool = runtime.onsite() == selected_holding and owned
	_label("현장 관리" if onsite else "원격 조회 · 수령/납품/투자는 해당 영지 관리인 앞에서 가능합니다")
	if owned:
		for holding_id in data.holdings:
			_button(Travel.HOLDING_NAMES[holding_id] + " 조회", _select_holding.bind(holding_id))
		_label(
			(
				"조회: %s · 대표 영지: %s"
				% [
					Travel.HOLDING_NAMES[selected_holding],
					Travel.HOLDING_NAMES[data.representative]
				]
			)
		)
		var holding: Dictionary = data.holdings[selected_holding]
		var costs: Dictionary = (
			Model.VILLAGE_COSTS if selected_holding == "jaetgol" else Model.COSTS
		)
		_label(
			(
				"공용 금고 %dG / 상한 %dG · 대표 순수입 %dG/일 · 대표 번영 %d"
				% [
					data.treasury,
					Model.daily_rate(data) * 7,
					Model.daily_rate(data),
					Model.prosperity(data)
				]
			)
		)
		_label(
			(
				"시설 %d/%d · 외형 복구 %d/5 · 조수입에서 유지비를 뺀 수입입니다"
				% [
					holding.facilities.size(),
					4 if selected_holding == "jaetgol" else 2,
					holding.development
				]
			)
		)
		if selected_holding == "jaetgol":
			_label("시설 2칸은 후속 개방 예정 · 현재 시장/공방만 건설 가능")
		if selected_holding != data.representative:
			_label("하위 영지의 시설·복구는 보존됩니다. 수입과 주문 주기는 대표 영지 기준입니다.")
		_button("금고 수령", _act.bind("collect"), not onsite or data.treasury == 0)
		_button(
			"시장 건설 · %dG · 대표 영지일 때 주문 갱신 주기 절반" % costs.market,
			_ask.bind("market"),
			not onsite or "market" in holding.facilities
		)
		_button(
			"공방 건설 · %dG · C급 장비/포션 상점" % costs.workshop,
			_ask.bind("workshop"),
			not onsite or "workshop" in holding.facilities
		)
		_button(
			"외형 복구 투자 · %dG · 수입 증가 없음" % costs.develop,
			_ask.bind("develop"),
			not onsite or holding.development >= 5
		)
		var minutes := int(
			ceil(maxi(0, int(data.order.deadline_ms) - int(data.elapsed_ms)) / 60000.0)
		)
		_label(
			(
				"주문: %s · 다음 갱신까지 실제 진행 시간 %d분"
				% ["납품 완료" if data.order.completed else "들개 이빨 3개", minutes]
			)
		)
		_button(
			"들개 이빨 3개 납품 · %dG + 대표 영지 번영2" % data.order.reward,
			_act.bind("deliver"),
			not onsite or data.order.completed
		)
	else:
		_label("영지 없음 · 여울목 방어와 문장원 심사 후 관리가 열립니다")
	_label("유료 이동: 도시 서쪽 입구 워프 표식 / 소유 영지 관리인 근처에서 출발")
	for city in Travel.CITIES:
		var quote: Dictionary = Travel.quote(
			runtime.travel_state(),
			data,
			runtime.world.map_id,
			city,
			runtime.world.get_node("QuestController").journal.reputation()
		)
		var title: String = Content.NAMES[Travel.CITIES[city].map_id]
		var departure: String = Travel.departure_error(
			runtime.world.map_id, runtime.player.position, data
		)
		if departure != "":
			quote.error = departure
		_button(
			(
				title
				+ (
					" · %dG" % quote.cost
					if quote.error == ""
					else (" · 게이트에서 출발" if quote.error == "warp_departure" else " · 미개방/현재 위치")
				)
			),
			_ask_warp.bind(city),
			quote.error != ""
		)
	var cooldown: int = runtime.travel_state().return_ms
	_label("무료 귀환 공통 재사용까지 %d초" % int(ceil(cooldown / 1000.0)))
	for holding_id in data.holdings:
		var offer: Dictionary = Travel.quote(
			runtime.travel_state(), data, runtime.world.map_id, holding_id, 0, true
		)
		_button(
			Travel.HOLDING_NAMES[holding_id] + " 무료 귀환",
			_warp.bind(holding_id, true),
			offer.error != ""
		)
	message = _label("")


func _select_holding(holding_id: String) -> void:
	selected_holding = holding_id
	_refresh()


func _ask(action: String) -> void:
	if runtime.onsite() != selected_holding:
		message.text = ERRORS.onsite
		return
	pending = action
	var costs: Dictionary = Model.VILLAGE_COSTS if selected_holding == "jaetgol" else Model.COSTS
	confirmation.dialog_text = (
		"%s에 %dG를 사용합니다. 실행할까요?"
		% [{"market": "시장 건설", "workshop": "공방 건설", "develop": "외형 복구"}[action], costs[action]]
	)
	confirmation.popup_centered(Vector2i(640, 220))


func _ask_warp(city: String) -> void:
	var departure: String = Travel.departure_error(
		runtime.world.map_id, runtime.player.position, runtime.state()
	)
	if departure != "":
		message.text = ERRORS.get(departure, "이동 조건을 확인하세요.")
		return
	pending = "warp:" + city
	var offer: Dictionary = Travel.quote(
		runtime.travel_state(),
		runtime.state(),
		runtime.world.map_id,
		city,
		runtime.world.get_node("QuestController").journal.reputation()
	)
	confirmation.dialog_text = (
		"%s로 이동 · %dG를 지불합니다. 저장은 별도입니다." % [Content.NAMES[Travel.CITIES[city].map_id], offer.cost]
	)
	confirmation.popup_centered(Vector2i(640, 220))


func _confirm() -> void:
	var action := pending
	pending = ""
	if action.begins_with("warp:"):
		_warp(action.trim_prefix("warp:"), false)
	elif not action.is_empty():
		_act(action)


func _act(action: String) -> void:
	if runtime.onsite() != selected_holding:
		message.text = ERRORS.onsite
		return
	var error: String = runtime.act(action)
	_refresh()
	message.text = "처리 완료" if error.is_empty() else ERRORS.get(error, "조건을 확인한 뒤 다시 시도하세요.")


func _warp(city: String, returning: bool = false) -> void:
	var session: Node = runtime.world.get_node("SaveSession")
	close()
	var result: Dictionary = session.warp(city, returning)
	if result.ok:
		return
	open()
	message.text = ERRORS.get(String(result.code), "이동 조건을 확인한 뒤 다시 시도하세요.")
