extends RefCounted
## 지역 전환은 관문 대화가 담당한다. 열린 장식 길로 저장 가능 범위 밖에 나가지 못하게 한다.


static func install(world: Node2D, bounds: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "RegionBoundary"
	body.collision_layer = 1
	body.collision_mask = 0
	world.add_child(body)
	var thickness := 32.0
	for rect in [
		Rect2(
			bounds.position - Vector2(thickness, thickness),
			Vector2(bounds.size.x + thickness * 2, thickness)
		),
		Rect2(
			Vector2(bounds.position.x - thickness, bounds.end.y),
			Vector2(bounds.size.x + thickness * 2, thickness)
		),
		Rect2(
			Vector2(bounds.position.x - thickness, bounds.position.y),
			Vector2(thickness, bounds.size.y)
		),
		Rect2(Vector2(bounds.end.x, bounds.position.y), Vector2(thickness, bounds.size.y)),
	]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		body.add_child(collision)
