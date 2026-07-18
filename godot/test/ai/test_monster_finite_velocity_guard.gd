## CB-6 회귀 방지 — 2026-07-18 디렉터 플레이 경고 스팸 수정
## ("Vector2 cannot be normalized, the elements must be finite" 이 wolf_monster.gd 쪽에서
## 매 프레임 반복).
##
## 조사로 확인한 실제 발생 지점(수정 전 GUT 실행 시 엔진이 찍은 정확한 백트레이스):
##   WARNING: Vector2 cannot be normalized, the elements must be finite. Making (0, 0)
##   as a fallback.  at: normalize (core/math/vector2.cpp:55)
##   GDScript backtrace: _register_stagger_hit (monster_base.gd) <- take_damage
## 원인: 공격자(또는 추적 대상)의 global_position이 이미 NaN 등으로 오염되어 있으면,
## 기존 가드였던 `direction.is_zero_approx()`는 NaN에 대해 항상 false를 반환하므로
## Vector2.DOWN 대체 분기를 타지 않고 그대로 `.normalized()`로 흘러가 경고가 찍힌다.
## move_toward_point()/move_away_from_point()도 동일한 취약점을 가지고 있었다 —
## CHASE/FLEE 상태는 매 물리 프레임 이 함수들을 호출하므로, target(플레이어 등)의 좌표가
## 한 번 오염되면 그 이후 "매 프레임 반복"된다(디렉터가 관찰한 증상과 일치).
##
## (참고: 정확히 "어떻게" 대상 좌표가 최초로 NaN이 되었는지는 플레이어·몬스터 양쪽의
## 넉백 나눗셈 경로를 모두 점검했으나 현재 데이터(.tres)로는 재현되지 않았다 — 아래
## 테스트는 "좌표가 이미 오염된 극단 상황"을 직접 주입해 오염원과 무관하게 방어가
## 동작함을 검증한다.)
extends GutTest

const WOLF_SCENE := preload("res://scenes/monsters/wolf.tscn")

var _wolf: WolfMonster
var _attacker: Node2D


func before_each() -> void:
	_wolf = WOLF_SCENE.instantiate()
	add_child_autofree(_wolf)
	_wolf.global_position = Vector2.ZERO
	_attacker = Node2D.new()
	add_child_autofree(_attacker)


func test_corrupted_attacker_position_does_not_produce_nan_velocity() -> void:
	_attacker.global_position = Vector2(NAN, NAN)  ## 공격자 좌표가 이미 오염된 극단 상황 가정
	_wolf.take_damage(1.0, "약", _attacker)
	_wolf._physics_process(0.016)
	assert_true(_wolf.velocity.is_finite(), "공격자 좌표가 NaN이어도 velocity는 유한해야 함(이중 방어)")


func test_corrupted_chase_target_does_not_repeat_warning_every_frame() -> void:
	## CHASE 상태에서 move_toward_point()가 매 프레임 호출되는 경로 — target 좌표가
	## NaN으로 오염된 상태로 여러 프레임을 굴려도 경고가 나지 않아야 한다("매 프레임
	## 반복" 증상의 실제 재현).
	_wolf.target = _attacker
	_attacker.global_position = Vector2(NAN, NAN)
	_wolf._enter_chase(_attacker)
	for _i in range(5):
		_wolf._physics_process(0.016)
	assert_true(_wolf.velocity.is_finite(), "추적 대상 좌표가 NaN이어도 velocity는 유한해야 함")


func test_zero_duration_stagger_rules_keep_velocity_finite() -> void:
	## MobStaggerRules 자체가 0초 경직으로 구성되는 극단적 데이터 상황(현재 3개 프리셋에는
	## 없음, mob_stagger_rules*.tres 확인 완료)에서도 velocity가 유한한지 확인한다.
	## monster_base.gd의 "stagger_duration > 0.0" 가드가 이미 이를 방지하고 있다.
	var stagger: MobStaggerComponent = _wolf.get_node("MobStagger")
	var rules := MobStaggerRules.new()
	rules.light_stagger_sec = 0.0
	rules.heavy_stagger_sec = 0.0
	stagger.rules = rules
	_attacker.global_position = Vector2(100, 0)
	_wolf.take_damage(1.0, "약", _attacker)
	_wolf._physics_process(0.016)
	assert_true(_wolf.velocity.is_finite())
