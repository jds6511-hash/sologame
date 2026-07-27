## C-8 검증 — 무법자 아종 2종(노상강도 Lv20 · 밀렵꾼 Lv36, m3-monster-spec.md 7-2·7-3장)이
## **신규 상태머신 없이** OutlawMonster 스크립트 + 데이터 차이만으로 성립하는지 확인한다
## (spec 7장 물량 통제 원칙: 아종은 신규 행동 블록 0).
extends GutTest

const HIGHWAYMAN_STATS_PATH := "res://data/monsters/highwayman_stats.tres"
const POACHER_STATS_PATH := "res://data/monsters/poacher_stats.tres"
const TILE := 16.0

var _target: Node2D


func before_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()
	_target = Node2D.new()
	add_child_autofree(_target)
	_target.global_position = Vector2(10000, 0)


func after_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()


func _spawn_outlaw(stats_path: String) -> OutlawMonster:
	var outlaw := OutlawMonster.new()
	outlaw.stats = load(stats_path)
	M3MonsterTestRig.attach_attack_hitbox(outlaw)
	add_child_autofree(outlaw)
	outlaw.global_position = Vector2.ZERO
	outlaw.home_position = Vector2.ZERO
	outlaw.target = _target
	return outlaw


func _place_target_at_tiles(monster: OutlawMonster, tiles: float) -> void:
	_target.global_position = monster.global_position + Vector2(tiles * TILE, 0.0)


# --- 노상강도 (Lv20 — 블록 구성 100% 동일, 파라미터만 조정) ---


func test_highwayman_reuses_same_state_machine_with_faster_charge() -> void:
	var highwayman := _spawn_outlaw(HIGHWAYMAN_STATS_PATH)
	assert_eq(highwayman.stats.charge_cooldown_sec, 3.5, "spec 7-2: 돌진 쿨다운 4.0 → 3.5초")
	assert_eq(highwayman.stats.max_hp, 1030.0, "Lv20 잡몹 앵커 HP")
	_place_target_at_tiles(highwayman, 4.0)
	highwayman._enter_chase(_target)
	highwayman._physics_process(0.016)
	assert_eq(highwayman.state, OutlawMonster.State.CHARGE, "블록 구성은 무법자와 100% 동일")


# --- 밀렵꾼 (Lv36 — 돌진 → 석궁 조준 사격 교체, 가드 유지) ---


func test_poacher_uses_crossbow_instead_of_charge() -> void:
	var poacher := _spawn_outlaw(POACHER_STATS_PATH)
	assert_true(poacher.stats.uses_ranged_attack, "spec 7-3: 돌진 → 조준 사격 조합 스위치")
	_place_target_at_tiles(poacher, 5.0)  ## 석궁 사거리 6타일 이내
	poacher._enter_chase(_target)
	poacher._physics_process(0.016)
	assert_ne(poacher.state, OutlawMonster.State.CHARGE, "밀렵꾼은 돌진 블록을 쓰지 않는다")
	assert_eq(poacher._crossbow.phase, AimFireBlock.Phase.AIMING, "조준 사격(석궁) 진입")
	poacher._physics_process(0.7)  ## 조준 예고 0.7초
	assert_eq(poacher._crossbow.phase, AimFireBlock.Phase.COOLDOWN, "발사 후 쿨다운 3.5초")


func test_poacher_approaches_when_target_is_out_of_crossbow_range() -> void:
	var poacher := _spawn_outlaw(POACHER_STATS_PATH)
	_place_target_at_tiles(poacher, 6.5)  ## 석궁 사거리(6타일) 밖
	poacher._enter_chase(_target)
	poacher._physics_process(0.016)
	assert_eq(poacher._crossbow.phase, AimFireBlock.Phase.IDLE, "사거리 밖에서는 조준하지 않는다")
	assert_gt(poacher.velocity.x, 0.0, "사거리 안으로 접근")


func test_poacher_keeps_guard_block() -> void:
	var poacher := _spawn_outlaw(POACHER_STATS_PATH)
	_place_target_at_tiles(poacher, 2.0)
	poacher._enter_chase(_target)
	poacher._update_facing(Vector2.RIGHT)
	poacher.take_damage(0.0, "약", _target)
	poacher._physics_process(0.016)
	assert_eq(poacher.state, OutlawMonster.State.GUARD, "spec 7-3: 가드는 유지")
