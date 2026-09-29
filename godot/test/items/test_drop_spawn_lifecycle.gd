## 사망 콜백 중 드롭 예약과 월드 교체 수명 검증.
extends GutTest

const ITEM = preload("res://data/items/pot_hp_1.tres")
const SCENE = preload("res://scenes/items/world_item.tscn")


func test_drop_defers_collision_creation_and_preserves_payload() -> void:
	var world := Node2D.new()
	world.position = Vector2(40, 70)
	add_child_autofree(world)
	var drops := DropSystem.new()
	drops.world_item_scene = SCENE
	world.add_child(drops)
	watch_signals(drops)
	drops._spawn_item(ITEM, 2, Vector2(123, 234))
	assert_signal_emit_count(drops, "item_dropped", 1)
	assert_eq(world.get_child_count(), 1, "물리 콜백 안에서는 노드를 추가하지 않는다")
	await get_tree().process_frame
	assert_eq(world.get_child_count(), 2, "메시지 큐 처리 후 한 개만 생성")
	var item = world.get_child(1)
	assert_eq(item.item_data, ITEM)
	assert_eq(item.quantity, 2)
	assert_eq(item.global_position, Vector2(123, 234), "월드 변환이 있어도 처치 좌표 유지")


func test_world_removed_before_flush_does_not_spawn_in_next_world() -> void:
	var world := Node2D.new()
	add_child(world)
	var drops := DropSystem.new()
	drops.world_item_scene = SCENE
	world.add_child(drops)
	drops._spawn_item(ITEM, 1, Vector2(123, 234))
	world.free()
	var next_world := Node2D.new()
	add_child_autofree(next_world)
	await get_tree().process_frame
	assert_eq(next_world.get_child_count(), 0, "이전 월드 예약은 다음 월드에 유출되지 않는다")


func test_physics_body_entered_spawns_two_items_after_query() -> void:
	var world := Node2D.new()
	add_child_autofree(world)
	var drops := DropSystem.new()
	drops.world_item_scene = SCENE
	world.add_child(drops)
	var area := Area2D.new()
	var area_shape := CollisionShape2D.new()
	area_shape.shape = CircleShape2D.new()
	area.add_child(area_shape)
	var body := StaticBody2D.new()
	var body_shape := CollisionShape2D.new()
	body_shape.shape = CircleShape2D.new()
	body.add_child(body_shape)
	area.body_entered.connect(
		func(_body):
			drops._spawn_item(ITEM, 1, Vector2(123, 234))
			drops._spawn_item(ITEM, 2, Vector2(135, 234))
	)
	watch_signals(drops)
	world.add_child(area)
	world.add_child(body)
	await wait_physics_frames(5)
	assert_signal_emit_count(drops, "item_dropped", 2, "실제 물리 콜백에서 두 요청")
	var items := world.find_children("*", "WorldItem", false, false)
	assert_eq(items.size(), 2, "같은 콜백의 요청을 합치거나 중복 생성하지 않는다")
