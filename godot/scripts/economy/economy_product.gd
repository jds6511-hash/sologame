## 이전 기본 실행 API의 호환 진입점. 제품 구현은 통합 월드 한 곳에 있다.
extends RefCounted


static func instantiate_world(region: String = "eastern_frontier_start") -> Node:
	return load("res://scripts/world/game_product.gd").instantiate_world(region)
