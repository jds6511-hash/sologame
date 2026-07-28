## M3 C-5 검증 — m3-archer-skills.md 6장 화살 투사체의 재사용/신규
## 델타가 규격대로 동작하는지 확인한다: 등속 직선 이동(재사용), 사거리 소멸(델타 ⑤),
## 관통 파라미터·재타격 방지(델타 ④), 속도 변환(델타 ⑥), 명중 시 판정 주체를 실어 보내는
## arrow_hit_landed 계약(델타 ②③의 입구).
extends GutTest

const ARROW_SCENE: PackedScene = preload("res://scenes/player/arrow_projectile.tscn")
const TILE := 16.0
const TOL := 0.0001


func _make_spec(
	speed_tiles: float, range_tiles: float, pierce: int, width_tiles: float = 0.6
) -> ArrowSpec:
	var spec := ArrowSpec.new()
	spec.speed_tiles_per_sec = speed_tiles
	spec.range_tiles = range_tiles
	spec.pierce_count = pierce
	spec.width_tiles = width_tiles
	return spec


func _make_arrow(spec: ArrowSpec, action: Resource = null) -> ArrowProjectile:
	var arrow: ArrowProjectile = ARROW_SCENE.instantiate()
	add_child_autofree(arrow)
	arrow.configure(action, spec, TILE)
	return arrow


func _make_body() -> Node2D:
	var body := Node2D.new()
	add_child_autofree(body)
	return body


# --- 발사·이동·사거리 소멸 ---


func test_configure_converts_speed_tiles_to_px() -> void:
	var arrow := _make_arrow(_make_spec(16.0, 5.0, 0))
	assert_almost_eq(arrow._speed_px, 256.0, TOL, "16타일·초 x 16px")


func test_launch_sets_range_and_rotation() -> void:
	var arrow := _make_arrow(_make_spec(16.0, 5.0, 0))
	arrow.launch(Vector2.DOWN, 5.0 * TILE)
	assert_almost_eq(arrow._remaining_distance, 80.0, TOL)
	assert_almost_eq(arrow.rotation, Vector2.DOWN.angle(), TOL, "진행 방향으로 회전(연출)")


func test_moves_in_straight_line_at_constant_speed() -> void:
	var arrow := _make_arrow(_make_spec(16.0, 5.0, 0))
	arrow.global_position = Vector2.ZERO
	arrow.launch(Vector2.RIGHT, 5.0 * TILE)

	arrow._physics_process(0.1)  ## 256px/s x 0.1s = 25.6px

	assert_almost_eq(arrow.global_position.x, 25.6, TOL)
	assert_almost_eq(arrow.global_position.y, 0.0, TOL, "중력 없음 — 탑다운 직선")
	assert_almost_eq(arrow._remaining_distance, 80.0 - 25.6, TOL)


func test_expires_after_max_range_without_hitting() -> void:
	var arrow := _make_arrow(_make_spec(16.0, 5.0, 0))
	arrow.launch(Vector2.RIGHT, 5.0 * TILE)

	arrow._physics_process(0.4)  ## 102.4px 이동 > 사거리 80px

	assert_true(arrow.is_queued_for_deletion(), "명중이 없어도 사거리 만료 시 소멸")


func test_launch_with_zero_direction_is_discarded() -> void:
	var arrow := _make_arrow(_make_spec(16.0, 5.0, 0))
	arrow.launch(Vector2.ZERO, 5.0 * TILE)
	assert_true(arrow.is_queued_for_deletion())


# --- 명중 계약 (판정 주체를 그대로 실어 보낸다) ---


func test_hit_emits_signal_with_action_resource_and_body() -> void:
	var action := ArcherSkillData.new()
	action.skill_name = "속사"
	var arrow := _make_arrow(_make_spec(16.0, 5.5, 0), action)
	arrow.launch(Vector2.RIGHT, 5.5 * TILE)
	var body := _make_body()
	watch_signals(arrow)

	arrow._on_body_entered(body)

	assert_signal_emitted_with_parameters(arrow, "arrow_hit_landed", [action, body])


# --- 관통 파라미터 (델타 ④) ---


func test_non_piercing_arrow_dies_on_first_hit() -> void:
	var arrow := _make_arrow(_make_spec(16.0, 5.0, 0))
	arrow.launch(Vector2.RIGHT, 5.0 * TILE)

	arrow._on_body_entered(_make_body())

	assert_true(arrow.is_queued_for_deletion())


func test_pierce_three_hits_three_bodies_then_dies() -> void:
	var arrow := _make_arrow(_make_spec(20.0, 7.5, 3))
	arrow.launch(Vector2.RIGHT, 7.5 * TILE)
	watch_signals(arrow)

	arrow._on_body_entered(_make_body())
	assert_false(arrow.is_queued_for_deletion(), "1체 관통 — 계속 날아간다")
	arrow._on_body_entered(_make_body())
	assert_false(arrow.is_queued_for_deletion(), "2체 관통")
	arrow._on_body_entered(_make_body())

	assert_eq(get_signal_emit_count(arrow, "arrow_hit_landed"), 3, "최대 3체 명중")
	assert_true(arrow.is_queued_for_deletion(), "3체를 채우면 소멸")


func test_unlimited_pierce_survives_hits_and_dies_on_range() -> void:
	var arrow := _make_arrow(_make_spec(24.0, 12.0, -1))
	arrow.launch(Vector2.RIGHT, 12.0 * TILE)
	watch_signals(arrow)

	for _i in range(5):
		arrow._on_body_entered(_make_body())
	assert_false(arrow.is_queued_for_deletion(), "무제한 관통은 명중으로 소멸하지 않는다")
	assert_eq(get_signal_emit_count(arrow, "arrow_hit_landed"), 5)

	arrow._physics_process(1.0)  ## 384px 이동 > 사거리 192px
	assert_true(arrow.is_queued_for_deletion(), "사거리 만료로만 소멸")


func test_same_body_is_not_hit_twice_while_piercing() -> void:
	var arrow := _make_arrow(_make_spec(24.0, 12.0, -1))
	arrow.launch(Vector2.RIGHT, 12.0 * TILE)
	var body := _make_body()
	watch_signals(arrow)

	arrow._on_body_entered(body)
	arrow._on_body_entered(body)

	assert_eq(get_signal_emit_count(arrow, "arrow_hit_landed"), 1, "같은 대상 재타격 방지")


# --- 히트박스 폭 (4-4장 관통 폭사 1.0타일) ---


func _hitbox_radius(arrow: ArrowProjectile) -> float:
	var shape_node: CollisionShape2D = arrow.get_node("CollisionShape2D")
	var circle := shape_node.shape as CircleShape2D
	return circle.radius if circle != null else -1.0


func test_hitbox_radius_follows_spec_width() -> void:
	var arrow := _make_arrow(_make_spec(24.0, 12.0, -1, 1.0))
	assert_almost_eq(_hitbox_radius(arrow), 8.0, TOL, "폭 1.0타일(16px) → 반지름 8px")


func test_hitbox_shape_is_unique_per_instance() -> void:
	var narrow := _make_arrow(_make_spec(16.0, 5.0, 0, 0.6))
	var wide := _make_arrow(_make_spec(24.0, 12.0, -1, 1.0))
	assert_almost_eq(_hitbox_radius(narrow), 4.8, TOL)
	assert_almost_eq(_hitbox_radius(wide), 8.0, TOL, "인스턴스마다 독립 Shape여야 함")
