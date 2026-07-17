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

@export var item_data: ItemData
@export var quantity: int = 1

var _nearby_inventory: InventoryComponent = null

## ui-dev가 만들 근접 프롬프트("[F] 줍기") 노드 — 있으면 표시만 토글하고, 없으면 무시한다
## (UI 구현 자체는 범위 밖).
@onready var _prompt: Node = get_node_or_null("PickupPrompt")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_prompt_visible(false)


func _process(_delta: float) -> void:
	if _nearby_inventory != null and Input.is_action_just_pressed("interact"):
		_try_pickup()


func _on_body_entered(body: Node) -> void:
	var inv := _find_inventory(body)
	if inv:
		_nearby_inventory = inv
		_set_prompt_visible(true)


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
	if _nearby_inventory == null or item_data == null:
		return
	if _nearby_inventory.pickup(item_data, quantity):
		picked_up.emit(item_data, quantity)
		queue_free()


func _set_prompt_visible(value: bool) -> void:
	if _prompt and _prompt is CanvasItem:
		_prompt.visible = value
