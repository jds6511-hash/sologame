## 기본 실행 배선. 후보의 검증된 경제 모델을 재사용한다.
extends RefCounted

const Candidate = preload("res://scripts/economy/economy_environment.gd")


static func instantiate_world(region: String = "eastern_frontier_start") -> Node:
	var world: Node = Candidate.instantiate_world(region)
	world.set_script(ProductWorld)
	world.map_id = region
	world.set_meta("save_directory", "user://saves")
	return world


class ProductSession:
	extends Candidate.CandidateSession

	func _allows_directory(directory: String) -> bool:
		# 정식 저장과 명시한 QA 경로만 허용한다. 후보 접두사를 열지 않는다.
		return (
			directory
			in [
				"user://saves",
				"user://m6_product_test",
				"user://m6_product_process",
				"user://m6_product_combat"
			]
		)

	func _instantiate_world() -> Node:
		return load("res://scripts/economy/economy_product.gd").instantiate_world(_destination)


class ProductWorld:
	extends Candidate.CandidateWorld

	func _create_save_session() -> Node:
		return ProductSession.new()

	func _install_session_hint(_panel: Node) -> void:
		# 테스트 준비 상태 안내는 기본 제품에 표시하지 않는다.
		pass
