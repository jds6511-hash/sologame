## C-8 검증 — 임프의 포효 버프 블록(m3-monster-spec.md 3-6·4-3장)과 정예 아종
## "포효 임프장"(spec 7-4)이 **신규 상태머신 없이** ImpMonster + 데이터 차이만으로
## 성립하는지 확인한다(정예 슈퍼아머는 combat.md 5-2 정예 행).
extends GutTest

const STATS_PATH := "res://data/monsters/imp_stats.tres"
const LORD_STATS_PATH := "res://data/monsters/imp_lord_stats.tres"
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


# --- 포효 버프 (무피해, 반경 4타일 / 공격력·이속 +15% / 6초) ---


func test_roars_on_combat_entry() -> void:
	_place_target_at_tiles(_imp, 4.0)
	_imp._enter_chase(_target)
	_imp._physics_process(0.016)
	assert_eq(_imp.state, ImpMonster.State.ROAR, "spec 4-3: 전투 진입 시 포효")


func test_roar_applies_self_buff_after_telegraph() -> void:
	watch_signals(_imp)
	_place_target_at_tiles(_imp, 4.0)
	_imp._enter_chase(_target)
	_imp._physics_process(0.016)
	assert_false(_imp.is_buffed(), "예고 0.5초 동안은 버프가 걸리지 않는다")
	_imp._physics_process(0.5)
	assert_signal_emitted(_imp, "roared")
	assert_true(_imp.is_buffed(), "포효는 자신도 대상(spec 3-6 '임프 자신 포함')")
	assert_almost_eq(_imp.effective_attack_power(), 76.0 * 1.15, 0.01, "공격력 +15%")
	assert_eq(_imp.state, ImpMonster.State.CHASE, "포효 후 곧바로 추적 복귀")


func test_roar_buff_expires_after_duration() -> void:
	_finish_initial_roar(_imp)
	assert_true(_imp.is_buffed())
	_imp._physics_process(5.9)
	assert_true(_imp.is_buffed(), "지속 6.0초 이내에는 유지")
	_imp._physics_process(0.2)
	assert_false(_imp.is_buffed())
	assert_almost_eq(_imp.effective_attack_power(), 76.0, 0.01, "버프 종료 후 원래 공격력")


func test_roar_buffs_ally_inside_radius_only() -> void:
	var near_ally := _spawn_imp(STATS_PATH)
	near_ally.global_position = Vector2(3.0 * TILE, 0.0)  ## 반경 4타일 내
	var far_ally := _spawn_imp(STATS_PATH)
	far_ally.global_position = Vector2(5.0 * TILE, 0.0)  ## 반경 4타일 밖
	_place_target_at_tiles(_imp, 4.0)
	_imp._enter_chase(_target)
	_imp._physics_process(0.016)
	_imp._physics_process(0.5)
	assert_true(near_ally.is_buffed(), "반경 4타일 내 아군은 버프")
	assert_false(far_ally.is_buffed(), "반경 밖 아군은 버프되지 않음")


func test_roar_buff_speeds_up_chase_movement() -> void:
	_finish_initial_roar(_imp)
	## 순간이동 트리거(3타일)와 근접 사거리(1.5타일) 사이 = 순수 추적 이동 구간
	_place_target_at_tiles(_imp, 2.0)
	_imp._physics_process(0.016)
	var buffed_speed := _imp.velocity.length()
	assert_almost_eq(
		buffed_speed,
		_imp.stats.tiles_to_px(_imp.stats.combat_move_speed_tiles) * 1.15,
		0.5,
		"이동속도 +15%"
	)


func test_roar_uptime_is_capped_by_cooldown() -> void:
	_finish_initial_roar(_imp)
	_place_target_at_tiles(_imp, 4.0)
	_imp._physics_process(6.0)  ## 버프 종료(지속 6초) — 쿨다운은 아직 6초 남음
	assert_false(_imp.is_buffed())
	assert_false(_imp._roar.is_ready(), "가동률 50% — 버프가 끊긴 뒤에도 곧바로 재포효 불가")


# --- 정예 아종: 포효 임프장 (spec 7-4 — 신규 상태머신 없음) ---


func test_imp_lord_reuses_same_state_machine() -> void:
	var lord := _spawn_imp(LORD_STATS_PATH)
	lord.target = _target
	_place_target_at_tiles(lord, 4.0)
	lord._enter_chase(_target)
	lord._physics_process(0.016)
	assert_eq(lord.state, ImpMonster.State.ROAR, "임프와 동일한 5블록 조합(파라미터만 상향)")


func test_imp_lord_roar_is_stronger() -> void:
	var lord := _spawn_imp(LORD_STATS_PATH)
	lord.target = _target
	var ally := _spawn_imp(STATS_PATH)
	ally.global_position = Vector2(5.0 * TILE, 0.0)  ## 일반 반경(4타일) 밖, 정예 반경(6타일) 안
	_place_target_at_tiles(lord, 4.0)
	lord._enter_chase(_target)
	lord._physics_process(0.016)
	lord._physics_process(0.5)
	assert_true(ally.is_buffed(), "spec 7-4: 포효 반경 4 → 6타일")
	assert_almost_eq(lord.effective_attack_power(), 114.0 * 1.2, 0.01, "공격력 버프 +20%")


func test_imp_lord_blink_cooldown_is_longer() -> void:
	var lord := _spawn_imp(LORD_STATS_PATH)
	assert_eq(lord.stats.blink_cooldown_sec, 6.0, "spec 7-4: 순간이동 쿨다운 4.5 → 6.0초(저빈도)")
	assert_eq(lord._blink.cooldown_sec, 6.0, "블록에도 데이터 값이 그대로 주입돼야 함")


func test_imp_lord_has_superarmor_instead_of_stagger() -> void:
	var lord := _spawn_imp(LORD_STATS_PATH, true)
	lord.target = _target
	assert_true(lord.stats.is_elite)
	lord.take_damage(100.0, "강", _target)
	assert_false(lord.is_staggered(), "combat.md 5-2 정예: 평시 슈퍼아머(경직·넉백 없음)")
	assert_almost_eq(lord.hp, 5040.0 - 100.0, 0.01, "피해 자체는 그대로 들어간다")
