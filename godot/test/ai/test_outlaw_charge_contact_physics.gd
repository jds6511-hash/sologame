## 무법자 돌진 접촉의 실물리 회귀 검증 (2026-07-29 버그) — 실제 무법자 씬과 플레이어 레이어
## 바디를 배치해 물리 겹침으로 돌진 경로 판정을 성립시킨다.
##
## 원래 증상(level-designer C-10 보고): 돌진이 플레이어에 닿는 순간
## `ERROR: Function blocked during in/out signal. Use set_deferred("monitoring", ...)`.
## AttackHitbox의 body_entered 처리 중(Area2D가 in/out 시그널을 flush하는 동안) monitoring을
## 직접 끄려 했기 때문이다. 스텁 호출(_on_attack_hitbox_body_entered 직접 호출)로는 Area2D가
## 잠기지 않아 재현되지 않으므로, 이 테스트는 실제 물리 프레임으로 진입 시그널을 발생시킨다.
##
## 규격(spec 3-3 "경로 판정은 접촉 시 1회"): 접촉이 여러 프레임 이어지거나 대상이 판정을
## 나갔다 다시 들어와도 attack_landed는 돌진 1회당 1번만 발신돼야 한다(발신 = 피해 적용).
extends GutTest

const OUTLAW_SCENE := "res://scenes/monsters/outlaw.tscn"
const LAYER_PLAYER := 2

var _outlaw: OutlawMonster
var _victim: CharacterBody2D
var _hit_count: int = 0


func before_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()
	_hit_count = 0
	_outlaw = load(OUTLAW_SCENE).instantiate()
	add_child_autofree(_outlaw)
	_outlaw.global_position = Vector2.ZERO
	_outlaw.home_position = Vector2.ZERO
	_outlaw.attack_landed.connect(func(_body: Node) -> void: _hit_count += 1)
	_victim = _make_player_layer_body()
	_outlaw.target = _victim


func after_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()


## 플레이어 레이어(2)의 최소 바디 — AttackHitbox(mask=2)가 감지하는 조건만 갖춘다.
## scenes/player는 다른 도메인이라 실제 플레이어 씬 대신 같은 레이어의 바디로 대체한다.
func _make_player_layer_body() -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = LAYER_PLAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector2(4.0 * 16.0, 0.0)  ## 돌진 사거리(6타일) 안, 백스텝 불요 거리
	return body


func test_charge_contact_lands_exactly_once_under_real_physics() -> void:
	_outlaw._enter_chase(_victim)
	## 예고(0.6초) → 돌진 개시 → 대상까지 이동하며 경로 판정. 실제 물리 프레임을 돌려
	## AttackHitbox의 body_entered가 엔진에서 직접 발신되게 한다.
	await wait_physics_frames(60)
	assert_eq(_hit_count, 1, "spec 3-3: 돌진 경로 판정은 접촉 시 1회 (재진입에도 중복 판정 없음)")
	assert_false(_outlaw.get_node("AttackHitbox").monitoring, "첫 접촉 뒤 판정 히트박스가 꺼져 있어야 한다")
