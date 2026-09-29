extends GutTest

const Regions = preload("res://scripts/world/region_registry.gd")


func test_region_edges_block_player_without_closing_internal_gate() -> void:
	for id in Regions.SCENES:
		var world = load(Regions.SCENES[id]).instantiate()
		world.set_meta("save_directory", "user://region_boundary_test")
		add_child(world)
		await wait_process_frames(8)
		await wait_physics_frames(2)
		var player: CharacterBody2D = world.get_node("Player")
		var bounds: Rect2 = Regions.BOUNDS[id]
		# 테스트 이동 질의만 한다. 플레이어 좌표나 저장 파일은 변경하지 않는다.
		var transform := player.global_transform
		transform.origin = Vector2(bounds.end.x - 24, 440)
		assert_true(player.test_move(transform, Vector2(64, 0)), id + " 동쪽 출구 외부 이탈 차단")
		transform.origin = Regions.ARRIVALS[id]
		assert_false(player.test_move(transform, Vector2(8, 0)), id + " 귀환 위치 통행 유지")
		world.free()
	BgmManager.reset()
	GameClock.reset()
