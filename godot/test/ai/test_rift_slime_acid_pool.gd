## M2 후반 통합 검증 — 균열 점액 자폭 웅덩이(RiftSlimeAcidPool)의 실제 지속 피해 판정
## (m2-monster-spec.md 3-3장: 예고 0.3초 후 판정 시작, 반경 1.5타일, 초당 몬스터 공격력의
## 50%)을 DamageCalculator(CB-3) 공식 그대로 재현하는지 확인한다.
##
## Area2D.get_overlapping_bodies()는 실제 물리 엔진이 한 스텝 진행해야 겹침 목록이
## 갱신되므로(단순히 _physics_process를 직접 호출하는 것만으로는 갱신되지 않음),
## GUT의 wait_physics_frames()로 실제 물리 프레임을 최소 1회 흘려보낸다.
extends GutTest

const FORMULA: DamageFormulaData = preload("res://data/combat/damage_formula.tres")

var _pool: RiftSlimeAcidPool
var _target: DummyPoolTarget


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/monsters/rift_slime_acid_pool.tscn")
	_pool = scene.instantiate()
	add_child_autofree(_pool)
	_pool.global_position = Vector2.ZERO

	_target = DummyPoolTarget.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	_target.add_child(shape)
	add_child_autofree(_target)
	_target.global_position = Vector2.ZERO


func test_deals_no_damage_during_telegraph() -> void:
	_pool.configure(37.0, 0.5, 0.3, 2.0, 1.5, 16.0, FORMULA)
	await wait_physics_frames(2)
	_pool._physics_process(0.1)  ## 예고(0.3초) 이내
	assert_eq(_target.damage_taken, 0.0, "예고 시간 중에는 피해가 없어야 함")


func test_deals_damage_after_telegraph_using_damage_calculator_formula() -> void:
	## 예고를 두고(0.3초) monitoring만 먼저 켜서 겹침 판정을 확보한 뒤, 틱 적용 자체는
	## _apply_tick_damage()를 직접 호출해 검증한다 — 실제 물리 프레임(엔진 자동 처리)과
	## 수동 _physics_process 호출을 함께 쓰면 같은 틱이 이중으로 잡혀 데미지가 배로
	## 계산되므로(엔진이 대기 중에도 자체적으로 _physics_process를 계속 호출한다), 겹침
	## 확보와 틱 적용을 분리한다.
	_pool.configure(37.0, 0.5, 0.3, 2.0, 1.5, 16.0, FORMULA)
	_pool.monitoring = true
	await wait_physics_frames(2)  ## Area2D 겹침 판정 갱신 대기
	_pool._apply_tick_damage(0.25)
	var expected_base := 37.0 * (0.5 * 0.25) * (100.0 / (100.0 + 0.0))
	assert_between(_target.damage_taken, expected_base * 0.95, expected_base * 1.05)


func test_skips_damage_when_target_is_invincible() -> void:
	_target.invincible = true
	_pool.configure(37.0, 0.5, 0.3, 2.0, 1.5, 16.0, FORMULA)
	_pool.monitoring = true
	await wait_physics_frames(2)
	_pool._apply_tick_damage(0.25)
	assert_eq(_target.damage_taken, 0.0, "무적 중인 대상은 피해를 받지 않아야 함")


func test_pool_frees_itself_after_telegraph_plus_duration() -> void:
	_pool.configure(37.0, 0.5, 0.1, 0.2, 1.5, 16.0, FORMULA)
	_pool._physics_process(0.1)  ## 예고 종료 -> 활성
	_pool._physics_process(0.2)  ## 지속 종료
	assert_true(not is_instance_valid(_pool) or _pool.is_queued_for_deletion())


func test_configure_applies_radius_to_collision_shape() -> void:
	_pool.configure(37.0, 0.5, 0.3, 2.0, 1.5, 16.0, FORMULA)
	var shape: CollisionShape2D = _pool.get_node("CollisionShape2D")
	assert_eq((shape.shape as CircleShape2D).radius, 1.5 * 16.0)
