## 기존 M6 조작기를 기본 제품 배선과 별도 저장 경로에서 실행한다.
extends "res://../docs/qa/tools/m6_combat_probe.gd"


func _initialize() -> void:
	super._initialize()
	save_root = "user://m6_product_combat"


func _instantiate_onboarding_world() -> Node:
	return load("res://scripts/economy/economy_product.gd").instantiate_world()
