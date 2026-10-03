## 저장 목표 하나를 현장 관찰·방향 선택으로 해결한다. 임시 단서는 보상을 주지 않는다.
extends Node2D

const CONFIG := {
	"marsh_route":
	{
		"correct": 2,
		"notice":
		(
			"진흙에 세 갈래 흔적이 남아 있다. 운송 수레는 폭이 일정한 두 바퀴 홈을 남긴다.\n"
			+ "발자국이나 끊긴 홈과 구별해, 두 홈이 끝까지 이어지는 갈래로 걸어가 [F]로 확인하세요."
		),
		"labels": ["흔적 A", "흔적 B", "흔적 C"],
		"wrong": ["발자국은 짐승의 것이다. 수레의 두 바퀴 홈을 찾아보자.", "홈이 중간에서 끊긴다. 짐을 실은 수레가 계속 지나간 길이 아니다."],
		"success": "두 바퀴 홈이 갈대 사이로 이어진다. 은폐 운송로의 방향을 기록했다.",
	},
	"mosswood_water":
	{
		"correct": 0,
		"notice":
		(
			"세 갈래 물길을 대조한다. 떠내려오는 잎은 상류에서 합류점 쪽으로 흐른다.\n"
			+ "잎 모양과 화살표를 보고 이곳으로 흘러드는 갈래를 찾아, 직접 걸어가 [F]로 확인하세요."
		),
		"labels": ["물길 A", "물길 B", "물길 C"],
		"wrong": ["이 갈래는 물이 바깥으로 빠져나간다. 이곳으로 흘러드는 상류를 찾자.", "잎이 고여 있다. 상류에서 이어지는 물의 흐름이 없다."],
		"success": "상류에서 내려온 잎이 합류점에 닿는다. 수림 물길의 유입 방향을 기록했다.",
	},
}
var site: Node2D
var clues: Array[Node2D] = []
var correct_index := 0
var started := false
var solved := false
var config: Dictionary


class Clue:
	extends "res://scripts/npc/quest_npc.gd"
	var field: Node2D
	var index := 0

	func update_target() -> void:
		_available = can_interact()

	func can_interact() -> bool:
		return field.started and field.site.expects_interaction() and _can_interact()

	func interact() -> bool:
		return can_interact() and field.choose(index)

	func interaction_verb() -> String:
		return "흔적 대조"

	func _draw() -> void:
		var ink := Color("72d6d0")
		if field.solved and index == field.correct_index:
			ink = Color("8ee68a")
		draw_arc(Vector2.ZERO, 18, 0, TAU, 24, ink, 1.5)
		if field.site.npc_id == "marsh_route":
			for step in range(5):
				if index == 1 and step == 2:
					continue
				for side in [-1, 1]:
					var point := Vector2(side * 5, -12 + step * 6)
					if index == 0:
						draw_circle(point + Vector2(step % 2 * 3, 0), 2, ink)
					else:
						draw_line(point, point + Vector2(0, 6), ink, 2)
		else:
			var direction := -position.normalized() if index == 0 else position.normalized()
			if index == 2:
				draw_circle(Vector2.ZERO, 4, ink)
				return
			draw_line(-direction * 12, direction * 12, ink, 2)
			for side in [-1, 1]:
				draw_line(direction * 12, direction.rotated(side * 0.65) * 5, ink, 2)
			draw_colored_polygon(
				PackedVector2Array(
					[Vector2(-3, -2), Vector2(0, -6), Vector2(3, -2), Vector2(0, 2)]
				),
				ink
			)


func setup(owner_site: Node2D, selection: Node) -> void:
	site = owner_site
	config = CONFIG[site.npc_id]
	correct_index = config.correct
	var offsets := [Vector2(-96, 48), Vector2(0, 80), Vector2(96, 48)]
	for index in range(3):
		var clue := Clue.new()
		clue.field = self
		clue.index = index
		clue.npc_id = site.npc_id + "_clue_" + str(index)
		clue.position = offsets[index]
		var label := Label.new()
		label.name = "Name"
		label.text = config.labels[index]
		label.position = Vector2(-80, 22)
		label.size = Vector2(160, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clue.add_child(label)
		add_child(clue)
		clue.setup(site._player, site._controller, site._dialog, site._hud)
		clues.append(clue)
		selection.candidates.append(clue)
	site._controller.journal.changed.connect(refresh)
	refresh()


func begin() -> bool:
	if not site._dialog.open_notice(config.notice):
		return false
	started = true
	return true


func choose(index: int) -> bool:
	if index < 0 or index >= clues.size() or not clues[index].can_interact():
		return false
	if index != correct_index:
		var wrong_index := index if index < correct_index else index - 1
		return site._dialog.open_notice(config.wrong[wrong_index])
	if not site._dialog.open_notice(config.success):
		return false
	site._controller.journal.record_event(site.kind, site.npc_id, site.source, 0)
	return true


func refresh() -> void:
	solved = false
	var journal: QuestJournal = site._controller.journal
	var states := journal.export_state()
	for id in states:
		var definition: QuestData = journal.catalog.definitions[id]
		for index in definition.objective_targets.size():
			if (
				definition.objective_kinds[index] == site.kind
				and definition.objective_targets[index] == site.npc_id
				and definition.objective_sources[index] == site.source
				and states[id].counts[index] >= definition.objective_counts[index]
			):
				solved = true
	visible = solved or site.expects_interaction()
	queue_redraw()
	for clue in clues:
		clue.queue_redraw()


func _draw() -> void:
	if solved and not clues.is_empty():
		draw_line(Vector2.ZERO, clues[correct_index].position, Color("8ee68a"), 2)
