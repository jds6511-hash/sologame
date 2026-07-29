## C-8 검증 — 무법자(OutlawMonster) 상태 전이가 m3-monster-spec.md 4-2장 상태 전이도대로
## 동작하는지, 그리고 아종 2종(노상강도 Lv20·밀렵꾼 Lv36)이 신규 상태머신 없이 데이터
## 차이만으로 성립하는지 확인한다.
extends GutTest

const STATS_PATH := "res://data/monsters/outlaw_stats.tres"
const HIGHWAYMAN_STATS_PATH := "res://data/monsters/highwayman_stats.tres"
const POACHER_STATS_PATH := "res://data/monsters/poacher_stats.tres"
const TILE := 16.0

var _outlaw: OutlawMonster
var _target: Node2D


func before_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()
	_target = Node2D.new()
	add_child_autofree(_target)
	_target.global_position = Vector2(10000, 0)
	_outlaw = _spawn_outlaw(STATS_PATH)
	_outlaw.target = _target


func after_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()


func _spawn_outlaw(stats_path: String, with_stagger: bool = false) -> OutlawMonster:
	var outlaw := OutlawMonster.new()
	outlaw.stats = load(stats_path)
	M3MonsterTestRig.attach_attack_hitbox(outlaw)
	if with_stagger:
		M3MonsterTestRig.attach_stagger(outlaw)  ## 표준 체급(spec 4-2 넉백 체급)
	add_child_autofree(outlaw)
	outlaw.global_position = Vector2.ZERO
	outlaw.home_position = Vector2.ZERO
	return outlaw


func _place_target_at_tiles(monster: OutlawMonster, tiles: float) -> void:
	_target.global_position = monster.global_position + Vector2(tiles * TILE, 0.0)


# --- 배회 → 추적 → 돌진 ---


func test_initial_state_is_wander() -> void:
	assert_eq(_outlaw.state, OutlawMonster.State.WANDER)


func test_enters_chase_within_perception_range() -> void:
	_place_target_at_tiles(_outlaw, 5.0)  ## 인지 6타일 이내
	_outlaw._physics_process(0.016)
	assert_eq(_outlaw.state, OutlawMonster.State.CHASE)


func test_chase_starts_charge_within_charge_distance() -> void:
	_place_target_at_tiles(_outlaw, 5.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	assert_eq(_outlaw.state, OutlawMonster.State.CHARGE)


func test_charge_direction_is_locked_at_telegraph_start() -> void:
	watch_signals(_outlaw)
	_place_target_at_tiles(_outlaw, 4.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)  ## 예고 시작 — 이 시점 방향으로 고정
	_target.global_position = _outlaw.global_position + Vector2(0.0, 4.0 * TILE)  ## 측면으로 회피
	_outlaw._physics_process(0.6)  ## 예고 종료 → 돌진 개시
	var emitted: Array = get_signal_parameters(_outlaw, "charge_started")
	var direction: Vector2 = emitted[0]
	assert_almost_eq(direction.x, 1.0, 0.01, "예고 시점의 방향(오른쪽)으로 고정 — 측면 회피 가능")
	assert_almost_eq(direction.y, 0.0, 0.01)


func test_charge_applies_damage_multiplier_only_while_charging() -> void:
	_place_target_at_tiles(_outlaw, 4.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	assert_eq(_outlaw.current_attack_multiplier, 1.0, "예고 중에는 계수 적용 없음")
	_outlaw._physics_process(0.6)
	assert_eq(_outlaw.current_attack_multiplier, 1.2, "spec 3-3 돌진 데미지 계수 ×1.2")
	assert_almost_eq(_outlaw.effective_attack_power(), 65.0 * 1.2, 0.01)
	_outlaw._physics_process(0.75)  ## 돌진 이동 종료
	assert_eq(_outlaw.current_attack_multiplier, 1.0, "돌진이 끝나면 계수 복귀")
	assert_almost_eq(_outlaw.effective_attack_power(), 65.0, 0.01)


func test_charge_opens_path_hitbox_only_while_charging() -> void:
	var hitbox: Area2D = _outlaw.get_node("AttackHitbox")
	_place_target_at_tiles(_outlaw, 4.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	assert_false(hitbox.monitoring)
	_outlaw._physics_process(0.6)
	assert_true(hitbox.monitoring, "돌진 경로 판정 구간")
	_outlaw._physics_process(0.75)
	assert_false(hitbox.monitoring)


## spec 3-3 "경로 판정은 접촉 시 1회" — 첫 접촉 후에는 대상이 판정을 나갔다 다시 들어와도
## attack_landed가 다시 발신되지 않아야 한다(발신이 곧 피해 적용 = MonsterAttackResolver).
## 히트박스 monitoring은 body_entered 처리 중 직접 끌 수 없어 한 프레임 뒤에 꺼지므로
## (monster_base.gd _disable_attack_hitbox_deferred), 1회 보장은 발신 잠금이 담당한다.
func test_charge_path_hit_lands_only_once() -> void:
	watch_signals(_outlaw)
	_place_target_at_tiles(_outlaw, 4.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	_outlaw._physics_process(0.6)
	_outlaw._on_attack_hitbox_body_entered(_target)
	_outlaw._on_attack_hitbox_body_entered(_target)  ## 재진입 — 판정이 또 성립해선 안 된다
	assert_signal_emit_count(_outlaw, "attack_landed", 1, "spec 3-3 경로 판정은 접촉 시 1회")


## 돌진 접촉 처리는 AttackHitbox의 body_entered 안에서 실행되므로 monitoring을 직접 끄면
## 엔진 오류("Function blocked during in/out signal")가 난다 — set_deferred로 미뤄야 하고,
## 그래서 monitoring은 같은 프레임이 아니라 다음 프레임에 꺼진다(2026-07-29 수정).
func test_charge_path_hit_disables_hitbox_deferred_without_engine_error() -> void:
	var hitbox: Area2D = _outlaw.get_node("AttackHitbox")
	_place_target_at_tiles(_outlaw, 4.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	_outlaw._physics_process(0.6)
	_outlaw._on_attack_hitbox_body_entered(_target)
	await wait_frames(2)
	assert_false(hitbox.monitoring, "첫 접촉 뒤 판정 히트박스가 꺼져야 한다")


## 새 돌진이 시작되면 1회 잠금이 풀려 다시 판정이 성립해야 한다(쿨다운마다 재사용).
func test_new_charge_activation_unlocks_single_hit() -> void:
	watch_signals(_outlaw)
	_place_target_at_tiles(_outlaw, 4.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	_outlaw._physics_process(0.6)
	_outlaw._on_attack_hitbox_body_entered(_target)
	_outlaw._physics_process(0.75)  ## 돌진 이동 종료 → 후딜
	_outlaw._physics_process(0.5)  ## 후딜 종료 → 쿨다운
	_outlaw._physics_process(4.0)  ## 쿨다운 종료 → 재돌진 준비
	_outlaw._physics_process(0.016)  ## 두 번째 돌진 예고
	_outlaw._physics_process(0.6)  ## 두 번째 돌진 개시 = 새 판정 구간
	_outlaw._on_attack_hitbox_body_entered(_target)
	assert_signal_emit_count(_outlaw, "attack_landed", 2, "돌진마다 1회씩 판정이 성립해야 한다")


func test_charge_returns_to_chase_after_recovery_and_releases_token() -> void:
	_outlaw.pack_id = "road_a"
	_place_target_at_tiles(_outlaw, 4.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	assert_eq(PackAggroCoordinator.get_active_token_count("road_a"), 1, "돌진은 공격 토큰을 점유")
	_outlaw._physics_process(0.6)
	_outlaw._physics_process(0.75)
	_outlaw._physics_process(0.5)  ## 후딜 종료
	assert_eq(_outlaw.state, OutlawMonster.State.CHASE)
	assert_eq(PackAggroCoordinator.get_active_token_count("road_a"), 0)


func test_charge_waits_when_no_attack_token_available() -> void:
	_outlaw.pack_id = "road_b"
	PackAggroCoordinator.try_acquire_attack_token("road_b")
	PackAggroCoordinator.try_acquire_attack_token("road_b")  ## 토큰 2개 소모(다른 대열원 2마리)
	_place_target_at_tiles(_outlaw, 4.0)
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	assert_eq(_outlaw.state, OutlawMonster.State.CHASE, "토큰이 없으면 돌진 대신 포위 대기")


func test_close_range_backsteps_during_telegraph_to_secure_runway() -> void:
	_place_target_at_tiles(_outlaw, 1.0)  ## 최소 활주로 2타일 미만
	_outlaw._enter_chase(_target)
	_outlaw._physics_process(0.016)
	assert_eq(_outlaw.state, OutlawMonster.State.CHARGE)
	_outlaw._physics_process(0.1)
	assert_lt(_outlaw.velocity.x, 0.0, "플레이어(오른쪽) 반대로 백스텝해 활주로를 확보")


# --- 가드 (무피해 방어) ---


func test_guard_reacts_to_being_hit_and_reduces_frontal_damage() -> void:
	_place_target_at_tiles(_outlaw, 2.0)
	_outlaw._enter_chase(_target)
	_outlaw._update_facing(Vector2.RIGHT)
	_outlaw.take_damage(100.0, "약", _target)  ## 첫 타격은 감쇄 없음(반응 가드 시작)
	var hp_after_first := _outlaw.hp
	assert_almost_eq(hp_after_first, 740.0 - 100.0, 0.01, "반응 가드 진입 전 피격은 그대로 들어간다")
	_outlaw._physics_process(0.016)
	assert_eq(_outlaw.state, OutlawMonster.State.GUARD)
	_outlaw._physics_process(0.2)  ## 가드 자세 완성
	_outlaw.take_damage(100.0, "약", _target)
	assert_almost_eq(_outlaw.hp, hp_after_first - 40.0, 0.01, "정면 일반 피격 −60% 감쇄")


func test_guard_ignores_stagger_for_absorbed_hit() -> void:
	var outlaw := _spawn_outlaw(STATS_PATH, true)
	outlaw.target = _target
	_place_target_at_tiles(outlaw, 2.0)
	outlaw._enter_chase(_target)
	outlaw._update_facing(Vector2.RIGHT)
	outlaw.take_damage(10.0, "약", _target)  ## 첫 피격은 경직(0.15초) — 이 반응으로 가드가 예약된다
	var stagger: MobStaggerComponent = outlaw.get_node("MobStagger")
	assert_true(outlaw.is_staggered(), "가드 자세 이전의 피격은 잡몹 경직 규칙 그대로")
	stagger.advance_time(0.2)  ## 경직 종료(GUT에서는 _process가 돌지 않으므로 직접 진행)
	outlaw._physics_process(0.016)  ## 경직 종료 → 반응 가드 진입
	outlaw._physics_process(0.2)  ## 가드 자세 완성
	outlaw.take_damage(10.0, "약", _target)
	assert_false(outlaw.is_staggered(), "spec 3-4 가드로 흘린 정면 피격은 넉백·경직 무효")


func test_backside_hit_is_not_reduced_by_guard() -> void:
	_place_target_at_tiles(_outlaw, 2.0)
	_outlaw._enter_chase(_target)
	_outlaw._update_facing(Vector2.RIGHT)
	_outlaw.take_damage(0.0, "약", _target)
	_outlaw._physics_process(0.016)
	_outlaw._physics_process(0.2)
	var back_attacker := Node2D.new()
	add_child_autofree(back_attacker)
	back_attacker.global_position = _outlaw.global_position + Vector2(-100.0, 0.0)  ## 후방
	var hp_before := _outlaw.hp
	_outlaw.take_damage(100.0, "약", back_attacker)
	assert_almost_eq(_outlaw.hp, hp_before - 100.0, 0.01, "정면(±60°) 밖 피격은 감쇄 없음")


func test_strong_hit_breaks_guard_without_reduction() -> void:
	watch_signals(_outlaw)
	_place_target_at_tiles(_outlaw, 2.0)
	_outlaw._enter_chase(_target)
	_outlaw._update_facing(Vector2.RIGHT)
	_outlaw.take_damage(0.0, "약", _target)
	_outlaw._physics_process(0.016)
	_outlaw._physics_process(0.2)
	var hp_before := _outlaw.hp
	_outlaw.take_damage(100.0, "강", _target)  ## 치명타·차지 강타
	assert_almost_eq(_outlaw.hp, hp_before - 100.0, 0.01, "가드 브레이크는 감쇄 없이 그대로 피해")
	assert_signal_emitted(_outlaw, "guard_broken")
	_outlaw._physics_process(1.0)  ## 브레이크 경직 1.0초 종료
	assert_eq(_outlaw.state, OutlawMonster.State.CHASE, "경직 종료 후 추적 복귀(딜찬스 종료)")


# --- 무리 어그로 공유 / 귀환 ---


func test_pack_member_aggro_shared_when_one_member_hit() -> void:
	var mate := _spawn_outlaw(STATS_PATH)
	_outlaw.pack_id = "gang"
	mate.pack_id = "gang"
	_outlaw.add_to_group(_outlaw._pack_group_name())
	mate.add_to_group(mate._pack_group_name())
	mate.take_damage(10.0, "약", _target)
	assert_eq(_outlaw.state, OutlawMonster.State.CHASE, "대열원 1마리 피격 시 전체 전투 돌입")


func test_chase_returns_home_when_leash_exceeded() -> void:
	_outlaw._enter_chase(_target)
	_outlaw.global_position = Vector2(11.0 * TILE, 0.0)  ## 추적 한계 10타일 초과
	_target.global_position = _outlaw.global_position + Vector2(10000, 0)
	_outlaw._physics_process(0.016)
	assert_eq(_outlaw.state, OutlawMonster.State.RETURN)
