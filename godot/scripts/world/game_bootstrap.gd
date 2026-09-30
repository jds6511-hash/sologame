## 기본 게임 시작점. 구버전 원본 검증기는 동결하고 M6/V5 실행만 선택한다.
extends Node


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	var world: Node = load("res://scripts/economy/economy_product.gd").instantiate_world()
	if "--product-smoke" in OS.get_cmdline_user_args():
		world.set_meta("save_directory", "user://m6_product_test")
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	if world.get_meta("save_boot_error", "") == "":
		print("M6_PRODUCT_READY")
	queue_free()
