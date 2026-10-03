## 기본 게임과 격리된 장 시작 준비 상태를 하나의 시작 화면에서 선택한다.
extends Node

const Content = preload("res://scripts/content/game_content.gd")
const START_REGIONS := [
	"eastern_frontier_start",
	"eastern_frontier_start",
	"novera_gate",
	"novera_commons",
	"novera_commons",
	"brantel",
	"arsel",
	"misran"
]
const START_EXP := [0, 0, 3820, 42828, 79291, 283297, 704457, 1674227]

var _starting := false
var _message: Label


func start_options() -> Array:
	var options := [
		{"label": "기본 게임 · 기존 저장은 F6에서 불러오기", "chapter": 0, "directory": "user://saves"}
	]
	for chapter in range(1, 8):
		options.append(
			{
				"label":
				(
					"%d장 시작 체험 · %s"
					% [chapter, "새 모험가" if chapter == 1 else "%d장까지 완료 준비" % (chapter - 1)]
				),
				"chapter": chapter,
				"directory": "user://product_chapter_preview"
			}
		)
	return options


func start_region(chapter: int) -> String:
	return START_REGIONS[chapter]


func preparation(catalog: QuestCatalog, chapter: int) -> Dictionary:
	var quests := {}
	for id in catalog.ordered_ids():
		if (
			(chapter >= 4 and Content.QUEST_REVISIONS[id] < chapter - 1)
			or (chapter == 2 and String(id).begins_with("MQ-01-"))
			or (
				chapter == 3
				and (
					String(id).begins_with("MQ-01-")
					or String(id).begins_with("MQ-02-")
					or String(id).begins_with("SQ-NOV-")
				)
			)
		):
			quests[id] = {
				"state": "completed", "counts": Array(catalog.definitions[id].objective_counts)
			}
	return {
		"quests": quests,
		"exp": START_EXP[chapter],
		"gold":
		40000 if chapter >= 4 else (1130 if chapter == 2 else (23628 if chapter == 3 else 0))
	}


func _ready() -> void:
	if "--product-smoke" in OS.get_cmdline_user_args():
		_start.call_deferred(0, "user://m6_product_test")
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color("131e2c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(780, 0)
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	var title := Label.new()
	title.text = "여울목에서 시작하는 이야기"
	UiStyle.apply_body_font(title, 40)
	column.add_child(title)
	_message = Label.new()
	_message.text = (
		"기본 게임: 실제 저장 사용\n장 시작 체험: 별도 QA 저장 · 매번 준비 상태로 시작\n"
		+ "4~7장 체험: 이전 의뢰 완료·성장 표본 EXP·4만 골드를 준비합니다."
	)
	UiStyle.apply_body_font(_message, 24)
	column.add_child(_message)
	for option in start_options():
		var button := Button.new()
		button.text = option.label
		button.custom_minimum_size.y = 64
		UiStyle.apply_action_button(button)
		button.pressed.connect(_start.bind(option.chapter, option.directory))
		column.add_child(button)
	var close := Button.new()
	close.text = "종료"
	close.custom_minimum_size.y = 64
	UiStyle.apply_action_button(close)
	close.pressed.connect(get_tree().quit)
	column.add_child(close)


func _start(chapter: int, directory: String) -> void:
	if _starting:
		return
	_starting = true
	var region := start_region(chapter)
	var world: Node = load("res://scripts/world/game_product.gd").instantiate_world(region)
	world.set_meta("save_directory", directory)
	get_tree().root.add_child(world)
	if String(world.get_meta("save_boot_error", "")) != "":
		if is_instance_valid(_message):
			_message.text = "시작하지 못했습니다: " + String(world.get_meta("save_boot_error"))
		world.queue_free()
		_starting = false
		return
	get_tree().current_scene = world
	if chapter > 0:
		var journal: QuestJournal = world.get_node("QuestController").journal
		var prepared := preparation(journal.catalog, chapter)
		var preparation_error := journal.restore_state(prepared.quests)
		if preparation_error != "":
			push_error("Chapter preparation failed: " + preparation_error)
			world.queue_free()
			_starting = false
			return
		world.get_node("Player/PlayerProgression").add_exp(prepared.exp)
		world.get_node("Player/Inventory").add_gold(prepared.gold)
		world.get_node("SaveSession")._report("장 시작 준비 상태 · 실제 저장과 분리됩니다. 이어 할 때는 F6에서 불러오세요.")
	print("PRODUCT_READY chapter=", chapter)
	queue_free()
