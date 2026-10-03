extends "res://scripts/npc/quest_npc.gd"
var manager: Node
var source := ""
var data: Dictionary
var _status: Label

func configure(owner_manager: Node, id: String, config: Dictionary) -> void:
	manager = owner_manager
	source = id
	data = config
	npc_id = id
	_status = Label.new()
	_status.position = Vector2(-120, 38)
	_status.size = Vector2(240, 40)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.apply_label_font(_status, 10)
	add_child(_status)
	queue_redraw()

func update_target() -> void:
	_available = can_interact()

func can_interact() -> bool:
	return _can_interact() and is_instance_valid(manager) and manager.can_resume(source)

func interact() -> bool:
	return can_interact() and manager.resume(source)

func interaction_verb() -> String:
	return "대피 지원 시작" if data.kind == "evacuation" else "전투 재개"

func _process(_delta: float) -> void:
	if not is_instance_valid(manager) or _status == null:
		return
	_status.text = ""
	if not manager.active and manager._remaining(source) > 0 and manager._capacity() == 0:
		_status.text = "주변 적을 정리한 뒤 재개하세요"
	if manager.active and manager.source == source:
		if data.kind == "evacuation":
			_status.text = "대피 지원 %.1f / 8초\n원 밖 0.5초 이탈 시 초기화" % manager.elapsed
		else:
			for monster in manager.targets():
				if monster.has_method("current_telegraph"):
					_status.text = "%s · HP %d / %d · %d단계\n%s" % [monster.stats.display_name,
						monster.hp, monster.effective_max_hp(), monster.phase, str(monster.current_telegraph())]
					break
	queue_redraw()

func _draw() -> void:
	if data.is_empty():
		return
	var color := Color(0.35, 0.78, 1.0, 0.7)
	if data.kind == "evacuation":
		draw_arc(Vector2.ZERO, 48, 0, TAU, 48, color, 2.0)
		# 주민은 대피 장면 표시이며 피격·길찾기 대상이 아니다.
		for index in 3:
			draw_circle(Vector2(-16 + index * 16, -8), 4, Color(0.9, 0.8, 0.5))
		if is_instance_valid(manager) and manager.active and manager.source == source:
			draw_arc(Vector2.ZERO, 44, -PI / 2, -PI / 2 + TAU * manager.elapsed / 8.0, 48, Color.GREEN, 3.0)
	else:
		draw_circle(Vector2.ZERO, 14, color)
