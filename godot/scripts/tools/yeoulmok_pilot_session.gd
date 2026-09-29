## 격리 실행기에만 설치하는 시제품 수명 관리자. 제품 월드/저장 포맷은 변경하지 않는다.
extends Node

const ART = preload("res://scripts/tools/yeoulmok_art_pilot.gd")
const KIT = preload("res://scripts/tools/yeoulmok_native_kit.gd")
const START_SCENE := "res://scenes/world/eastern_frontier_starting_area.tscn"
var save_directory := "user://yeoulmok_art_pilot"
var native_kit := true


func _ready() -> void:
	get_tree().root.child_entered_tree.connect(_entered)


func _entered(world: Node) -> void:
	if world.scene_file_path != START_SCENE:
		return
	if not world.is_node_ready():
		world.ready.connect(attach.bind(world), CONNECT_ONE_SHOT)
	else:
		attach(world)


func attach(world: Node) -> void:
	if world.scene_file_path != START_SCENE:
		return
	if world.get_meta("save_directory", "") != save_directory:
		return
	if world.has_node("ArtPilot"):
		return
	var art := ART.new()
	art.name = "ArtPilot"
	world.add_child(art)
	if native_kit:
		var result := KIT.install(art)
		if result.has("error"):
			push_error(result.error)


func _exit_tree() -> void:
	if get_tree().root.child_entered_tree.is_connected(_entered):
		get_tree().root.child_entered_tree.disconnect(_entered)
