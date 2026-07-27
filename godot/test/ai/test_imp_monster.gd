## C-8 검증 — 임프(ImpMonster) 상태 전이가 m3-monster-spec.md 4-3장 상태 전이도대로
## 동작하는지 확인한다(배회 → 추적 → 순간이동/근접 스윙 → 귀환).
## 포효 버프와 정예 아종(포효 임프장)은 test_imp_roar_and_elite.gd에서 다룬다.
extends GutTest

const STATS_PATH := "res://data/monsters/imp_stats.tres"
const TILE := 16.0

var _imp: ImpMonster
var _target: Node2D


func before_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()
	_target = Node2D.new()
	add_child_autofree(_target)
	_target.global_position = Vector2(10000, 0)
	_imp = _spawn_imp(STATS_PATH)
	_imp.target = _target


func after_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()


func _spawn_imp(stats_path: String, with_stagger: bool = false) -> ImpMonster:
	var imp := ImpMonster.new()
	imp.stats = load(stats_path)
	M3MonsterTestRig.attach_attack_hitbox(imp)
	if with_stagger:
		M3MonsterTestRig.attach_stagger(imp, true)  ## 경량 체급(spec 4-3 넉백 체급)
	add_child_autofree(imp)
	imp.global_position = Vector2.ZERO
	imp.home_position = Vector2.ZERO
	return imp


func _place_target_at_tiles(monster: ImpMonster, tiles: float) -> void:
	_target.global_position = monster.global_position + Vector2(tiles * TILE, 0.0)


## 전투 진입 시 1회 포효(spec 4-3)를 소화시켜 추적 상태로 되돌린다 — 순간이동·근접 스윙
## 검증은 포효 쿨다운(12초) 구간을 전제로 한다.
func _finish_initial_roar(monster: ImpMonster) -> void:
	monster._enter_chase(_target)
	monster._physics_process(0.016)
	monster._physics_process(0.5)


# --- 배회 → 추적 ---


func test_initial_state_is_wander() -> void:
	assert_eq(_imp.state, ImpMonster.State.WANDER)


func test_enters_chase_when_target_within_perception_range() -> void:
	_place_target_at_tiles(_imp, 4.0)  ## 인지 범위 5타일 이내
	_imp._physics_process(0.016)
	assert_eq(_imp.state, ImpMonster.State.CHASE)


func test_stays_wandering_outside_perception_range() -> void:
	_place_target_at_tiles(_imp, 6.0)
	_imp._physics_process(0.016)
	assert_eq(_imp.state, ImpMonster.State.WANDER)


# --- 순간이동 (카이팅 감지 3타일 / 예고 0.3초 / 등장 후딜 0.3초) ---


func test_blink_triggers_when_target_kites_away() -> void:
	_finish_initial_roar(_imp)
	_place_target_at_tiles(_imp, 4.0)  ## 트리거 거리 3타일 이상 = 카이팅
	_imp._physics_process(0.016)
	assert_eq(_imp.state, ImpMonster.State.BLINK)


func test_blink_does_not_trigger_within_trigger_distance() -> void:
	_finish_initial_roar(_imp)
	_place_target_at_tiles(_imp, 2.0)  ## 3타일 미만 — 순간이동 불필요
	_imp._physics_process(0.016)
	assert_ne(_imp.state, ImpMonster.State.BLINK)


func test_blink_teleports_beside_target_within_max_range() -> void:
	watch_signals(_imp)
	_finish_initial_roar(_imp)
	_place_target_at_tiles(_imp, 4.0)
	_imp._physics_process(0.016)
	var origin := _imp.global_position
	_imp._physics_process(0.3)  ## 예고 종료 → 순간이동
	assert_signal_emitted(_imp, "blinked")
	var travelled := origin.distance_to(_imp.global_position) / TILE
	assert_lt(travelled, 5.01, "최대 이동 거리 5타일 이내")
	var offset_from_target := _imp.global_position.distance_to(_target.global_position) / TILE
	assert_almost_eq(offset_from_target, 2.5, 0.05, "플레이어 측면/후방 2~3타일 지점에 재등장")


func test_blink_recovery_then_returns_to_chase() -> void:
	_finish_initial_roar(_imp)
	_place_target_at_tiles(_imp, 4.0)
	_imp._physics_process(0.016)
	_imp._physics_process(0.3)
	assert_true(_imp._blink.is_recovering(), "재등장 직후 0.3초는 무방비(딜찬스)")
	assert_eq(_imp.velocity, Vector2.ZERO, "등장 후딜 중에는 움직이지 않는다")
	_imp._physics_process(0.3)
	assert_eq(_imp.state, ImpMonster.State.CHASE)


func test_blink_is_cancelled_by_stagger() -> void:
	var imp := _spawn_imp(STATS_PATH, true)
	imp.target = _target
	_finish_initial_roar(imp)
	_target.global_position = imp.global_position + Vector2(4.0 * TILE, 0.0)
	imp._physics_process(0.016)
	assert_eq(imp.state, ImpMonster.State.BLINK)
	imp.take_damage(10.0, "약", _target)  ## 예고 중 피격 → 경직
	imp._physics_process(0.016)
	assert_eq(imp.state, ImpMonster.State.CHASE, "예고 캔슬 = 딜찬스")
	assert_false(imp._blink.is_ready(), "캔슬된 순간이동도 쿨다운을 소모")


# --- 근접 스윙 (M2 MeleeSwingBlock 재사용, 공격 토큰 2) ---


func test_melee_swing_starts_in_range_and_releases_token() -> void:
	_imp.pack_id = "rift_a"
	_finish_initial_roar(_imp)
	_place_target_at_tiles(_imp, 1.0)  ## 근접 사거리 1.5타일 이내
	_imp._physics_process(0.016)
	assert_eq(_imp.state, ImpMonster.State.MELEE_SWING)
	assert_eq(PackAggroCoordinator.get_active_token_count("rift_a"), 1)
	_imp._physics_process(0.5)  ## 예고 → 판정
	_imp._physics_process(0.12)  ## 판정 → 후딜
	_imp._physics_process(0.3)  ## 후딜 종료 → 추적 복귀
	assert_eq(_imp.state, ImpMonster.State.CHASE)
	assert_eq(PackAggroCoordinator.get_active_token_count("rift_a"), 0)


func test_melee_swing_waits_when_no_attack_token_available() -> void:
	_imp.pack_id = "rift_b"
	PackAggroCoordinator.try_acquire_attack_token("rift_b")
	PackAggroCoordinator.try_acquire_attack_token("rift_b")  ## 토큰 2개 소모(무리원 2마리)
	_finish_initial_roar(_imp)
	_place_target_at_tiles(_imp, 1.0)
	_imp._physics_process(0.016)
	assert_eq(_imp.state, ImpMonster.State.CHASE, "토큰이 없으면 포위 대기(combat.md 2-2)")


# --- 무리 어그로 공유 / 귀환 ---


func test_pack_member_aggro_shared_when_one_member_hit() -> void:
	var mate := _spawn_imp(STATS_PATH)
	_imp.pack_id = "swarm"
	mate.pack_id = "swarm"
	_imp.add_to_group(_imp._pack_group_name())
	mate.add_to_group(mate._pack_group_name())
	mate.take_damage(10.0, "약", _target)
	assert_eq(_imp.state, ImpMonster.State.CHASE, "무리원 1마리 피격 시 전체 전투 돌입")


func test_chase_returns_home_when_leash_exceeded() -> void:
	_finish_initial_roar(_imp)
	_imp.global_position = Vector2(9.0 * TILE, 0.0)  ## 추적 한계 8타일 초과
	_target.global_position = _imp.global_position + Vector2(10000, 0)
	_imp._physics_process(0.016)
	assert_eq(_imp.state, ImpMonster.State.RETURN)


func test_return_restores_hp_and_goes_to_wander_on_arrival() -> void:
	_imp.hp = 1.0
	_imp.state = ImpMonster.State.RETURN
	_imp.global_position = Vector2(1.0, 0.0)  ## 도착 허용 오차 이내
	_imp._physics_process(0.016)
	assert_eq(_imp.state, ImpMonster.State.WANDER)
	assert_eq(_imp.hp, _imp.effective_max_hp(), "귀환 시 HP 완전 회복")


func test_normal_imp_still_staggers() -> void:
	var imp := _spawn_imp(STATS_PATH, true)
	imp.target = _target
	imp.take_damage(10.0, "약", _target)
	assert_true(imp.is_staggered(), "잡몹 임프는 기존 잡몹 경직 규칙 그대로")
