## 드랍된 아이템의 월드 오브젝트 (IT-2/IT-3 공용) — 몬스터 사망 지점 등에 놓여 플레이어가
## 주울 수 있는 Area2D. onboarding.md 3-6장 제안("근접 + F 프롬프트")을 그대로 채택했다 —
## project.godot에 이미 "interact"(F 키) 입력 액션이 등록돼 있어 그대로 사용한다.
##
## 골드는 이 오브젝트로 만들지 않는다 — DropSystem.gold_dropped 시그널로 즉시 지급하는
## 것으로 가정했다(결과 보고의 "가정" 항목 참고, 디렉터 결정 사항은 아님).
##
## 연동 계약: 플레이어 루트 노드의 자식으로 이름이 "Inventory"인 InventoryComponent가
## 있어야 한다(scenes/player/player.tscn에 그렇게 배치하는 것을 전제로 설계했다 — 실제
## 씬 배선은 결과 보고 참고, 이 스크립트는 player.tscn을 직접 수정하지 않았다).
class_name WorldItem
extends Area2D

signal picked_up(item_data: ItemData, quantity: int)

const PICKUP_GROUP := "nearby_world_items"
const PICKUP_DISTANCE := 32.0

@export var item_data: ItemData
@export var quantity: int = 1

var _nearby_inventory: InventoryComponent = null

## ui-dev가 만들 근접 프롬프트("[F] 줍기") 노드 — 있으면 표시만 토글하고, 없으면 무시한다
## (UI 구현 자체는 범위 밖).
@onready var _prompt: Node = get_node_or_null("PickupPrompt")


func _ready() -> void:
	add_to_group(PICKUP_GROUP)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_prompt_visible(false)


func _process(_delta: float) -> void:
	if not _pickup_available():
		_set_prompt_visible(false)
		return
	var nearby := _pickup_candidates()
	var leader: bool = not nearby.is_empty() and nearby[0] == self
	_set_prompt_visible(leader)
	if leader and _prompt is Label:
		_prompt.text = "[F] 주변 줍기 (%d)" % nearby.size()
	if leader and Input.is_action_just_pressed("interact"):
		var player := _nearby_inventory.get_parent()
		if int(player.get_meta("pickup_consumed_frame", -1)) == Engine.get_process_frames():
			return
		player.set_meta("pickup_consumed_frame", Engine.get_process_frames())
		for item in nearby:
			item._try_pickup()


func _on_body_entered(body: Node) -> void:
	var inv := _find_inventory(body)
	if inv:
		_nearby_inventory = inv
		_set_prompt_visible(_pickup_available())


func _pickup_available() -> bool:
	return (
		not is_queued_for_deletion()
		and is_instance_valid(_nearby_inventory)
		and not get_tree().paused
		and not _nearby_inventory.get_parent().get("is_input_locked") == true
		and not _nearby_inventory.get_parent().get_meta("world_interaction_available", false)
		and (
			int(_nearby_inventory.get_parent().get_meta("world_interaction_consumed_frame", -2))
			< Engine.get_process_frames() - 1
		)
	)


func _pickup_candidates() -> Array:
	var result: Array = []
	var player := _nearby_inventory.get_parent() as Node2D
	for candidate in get_tree().get_nodes_in_group(PICKUP_GROUP):
		if candidate.get_parent() != get_parent() or not candidate._pickup_available():
			continue
		if candidate._nearby_inventory != _nearby_inventory:
			continue
		if player.global_position.distance_to(candidate.global_position) > PICKUP_DISTANCE:
			continue
		# 지형만 검사: 같은 칸의 다른 드롭/몬스터는 줍기 시야를 막지 않는다.
		var ray := PhysicsRayQueryParameters2D.create(
			player.global_position, candidate.global_position, 1
		)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		result.append(candidate)
	result.sort_custom(
		func(a, b):
			var da := player.global_position.distance_squared_to(a.global_position)
			var db := player.global_position.distance_squared_to(b.global_position)
			return a.get_instance_id() < b.get_instance_id() if da == db else da < db
	)
	return result


func _on_body_exited(body: Node) -> void:
	if _find_inventory(body) == _nearby_inventory:
		_nearby_inventory = null
		_set_prompt_visible(false)


func _find_inventory(body: Node) -> InventoryComponent:
	if body == null:
		return null
	var inv := body.get_node_or_null("Inventory")
	return inv if inv is InventoryComponent else null


func _try_pickup() -> void:
	if not _pickup_available() or item_data == null:
		return
	if _nearby_inventory.pickup(item_data, quantity):
		picked_up.emit(item_data, quantity)
		queue_free()


func _set_prompt_visible(value: bool) -> void:
	if _prompt and _prompt is CanvasItem:
		_prompt.visible = value
