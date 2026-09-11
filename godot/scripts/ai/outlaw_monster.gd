## 무법자 (인간형 / Lv14) — m3-monster-spec.md 4-2장. 아종: 노상강도(Lv20)·밀렵꾼(Lv36).
##
## 상태 전이 (spec 4-2장 원문 그대로):
##   [배회] --(인지범위 6타일 진입 또는 대열원 피격 — 어그로 공유)--> [추적]
##   [추적] --(사거리 & 돌진 쿨다운 준비 & 공격 토큰 보유)--> [돌진 예고](0.6초, 방향 고정)
##       --> [돌진](직선 6타일) --> [후딜](0.5초, 벽 충돌 시 +0.8초 경직) --> [추적]
##   [추적/대치] --(플레이어 공격 감지 & 가드 쿨다운 준비)--> [가드](진입 0.2초, 정면 −60%)
##       --(1.5초 경과 또는 1회 피격)--> [해제 후딜](0.4초) --> [추적]
##   [가드] --(강 등급 피격 = 치명타·차지 강타)--> [가드 브레이크](경직 1.0초, 딜찬스) --> [추적]
##   [추적] --(스폰 지점 10타일 이탈)--> [귀환](HP 완전 회복) --> [배회]
##   [HP 0] --> 사망 (드랍 판정, spec 5-2장)
##
## 행동 블록 조합(4개, 데미지 예고 패턴 1개): 배회 → 추적 → 돌진(ChargeBlock, 데미지) →
## 가드(GuardBlock, 무피해 방어). 무리는 어그로 공유 O + 공격 토큰 2(PackAggroCoordinator,
## M2 들개 마수와 동일 방식 — 그룹명만 outlaw_pack_<id>).
##
## 아종 처리 (spec 7장 — 신규 상태머신 없이 데이터/파라미터 차이로만):
##   - 노상강도(Lv20): highwayman_stats.tres — 스탯 재산출 + charge_cooldown_sec 4.0→3.5.
##     스크립트·블록 100% 동일(무리 3~4마리는 C-10 배치 몫).
##   - 밀렵꾼(Lv36): poacher_stats.tres — stats.uses_ranged_attack=true면 돌진 블록 대신
##     조준 사격 석궁(AimFireBlock, projectile_* 필드)을 데미지 예고 패턴으로 쓴다. 가드는 유지.
##
## 가드 발동 조건 (ai-dev 근사 — systems-designer 확인 대상, 디렉터 결정 아님):
##   spec 3-4는 "플레이어 공격 예비 동작 감지 시 또는 확률적 반응"이라고 하지만, 플레이어의
##   공격 예비 동작을 조회하는 공용 API가 없다(scripts/player는 본 태스크 범위 밖). 따라서
##   "피격되면 즉시 반응 가드"로 근사한다 — 가드 쿨다운 6.0초가 가동률을 제한하므로 상시
##   가드가 되지 않고, "때리면 막는" 반응형 개성(spec 3-4 설계 의도)은 그대로 성립한다.
class_name OutlawMonster
extends MonsterBase

signal charge_started(direction: Vector2)
signal charge_hit_wall
signal guard_broken

enum State { WANDER, CHASE, CHARGE, GUARD, RETURN }

## 무리 식별자 — 비어 있으면 솔로 개체(토큰 제한 없음, 어그로 공유 없음). C-10에서 부여한다.
@export var pack_id: String = ""

## 밀렵꾼 석궁 투사체 씬 — 미할당(null)이면 crossbow_fired 시그널만 발생(균열 점액과 동일 패턴)
@export var projectile_scene: PackedScene
## 석궁 직격 피해 계산용 공용 리소스(res://data/combat/damage_formula.tres)
@export var formula_data: DamageFormulaData

var state: State = State.WANDER

var _wander_dir := Vector2.ZERO
var _wander_timer: float = 0.0
var _charge: ChargeBlock
var _guard: GuardBlock
var _crossbow: AimFireBlock
var _charge_velocity := Vector2.ZERO
var _charge_hit_landed: bool = false
var _guard_reaction_pending: bool = false
var _last_hit_was_guarded: bool = false
var _crossbow_aim_point := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_init_guard()
	if stats.uses_ranged_attack:
		_init_crossbow()
	else:
		_init_charge()
		## 돌진 경로 접촉 판정은 근접 사거리(1.5타일)를 그대로 반경으로 쓴다
		## (spec 미기재 — 몸통 충돌 판정이라 근접 스윙과 같은 규격으로 근사).
		_setup_attack_hitbox(stats.melee_range_tiles)
		## spec 3-3 "경로 판정은 접촉 시 1회" — 히트박스를 끄는 것과 별개로 발신 자체를 잠근다
		## (MonsterBase.single_hit_per_activation 주석 참고). 이 잠금이 없으면 돌진 중 플레이어가
		## 판정을 나갔다 다시 들어올 때 MonsterAttackResolver가 두 번 피해를 적용한다.
		single_hit_per_activation = true
		attack_landed.connect(_on_charge_path_hit)
	_wander_dir = random_wander_direction()
	_wander_timer = randf_range(1.0, 2.5)
	if stats.shares_pack_aggro and not pack_id.is_empty():
		add_to_group(_pack_group_name())


func _init_charge() -> void:
	_charge = ChargeBlock.new()
	_charge.telegraph_sec = stats.charge_telegraph_sec
	_charge.charge_sec = _charge_travel_sec()
	_charge.recovery_sec = stats.charge_recovery_sec
	_charge.wall_stun_sec = stats.charge_wall_stun_sec
	_charge.cooldown_sec = stats.charge_cooldown_sec
	_charge.telegraph_started.connect(_on_charge_telegraph_started)
	_charge.charge_started.connect(_on_charge_started)
	_charge.charge_ended.connect(_on_charge_ended)
	_charge.ended.connect(_on_charge_pattern_ended)


## 돌진 이동 시간 = 돌진 거리 ÷ 돌진 속도 (spec 3-3: 6타일 ÷ 8타일/초 ≈ 0.75초)
func _charge_travel_sec() -> float:
	if stats.charge_speed_tiles <= 0.0:
		return 0.0
	return stats.charge_distance_tiles / stats.charge_speed_tiles


func _init_guard() -> void:
	_guard = GuardBlock.new()
	_guard.enter_sec = stats.guard_enter_sec
	_guard.duration_sec = stats.guard_duration_sec
	_guard.break_stun_sec = stats.guard_break_stun_sec
	_guard.recovery_sec = stats.guard_recovery_sec
	_guard.cooldown_sec = stats.guard_cooldown_sec
	_guard.guard_entered.connect(_on_guard_entered)
	_guard.guard_broken.connect(_on_guard_broken)
	_guard.guard_ended.connect(_on_guard_ended)


func _init_crossbow() -> void:
	_crossbow = AimFireBlock.new()
	_crossbow.telegraph_sec = stats.projectile_telegraph_sec
	_crossbow.cooldown_sec = stats.projectile_cooldown_sec
	_crossbow.aim_started.connect(_on_crossbow_aim_started)
	_crossbow.fired.connect(_on_crossbow_fired)


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	if is_staggered():
		_cancel_patterns()
		velocity = stagger_velocity()
		if _guard_finite_before_move():
			move_and_slide()
		return
	_guard.update(delta)
	if _charge:
		_charge.update(delta)
	if _crossbow:
		_crossbow.update(delta)
	if _guard_reaction_pending:
		_start_guard()
	match state:
		State.WANDER:
			_process_wander(delta)
			if is_target_in_range_tiles(stats.perception_range_tiles):
				_enter_chase(target)
		State.CHASE:
			_process_chase()
		State.CHARGE:
			_process_charge()
		State.GUARD:
			velocity = Vector2.ZERO
			if not _guard.is_busy():
				state = State.CHASE
		State.RETURN:
			if _return_to_home():
				state = State.WANDER
	if _guard_finite_before_move():
		move_and_slide()


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_dir = random_wander_direction()
		_wander_timer = randf_range(1.0, 2.5)
	velocity = _wander_dir * stats.tiles_to_px(stats.wander_speed_tiles)
	_play_animation("walk", velocity)


func _process_chase() -> void:
	if target == null:
		state = State.RETURN
		return
	if (
		stats.leash_range_tiles >= 0.0
		and distance_tiles_to(home_position) >= stats.leash_range_tiles
	):
		state = State.RETURN
		return
	if _try_start_damage_pattern():
		return
	velocity = _chase_velocity()
	_play_animation("walk", velocity)


## 데미지 예고 패턴 진입 시도 — 무법자·노상강도는 돌진, 밀렵꾼(uses_ranged_attack)은 석궁.
## 둘 다 공격 토큰(최대 2마리, combat.md 2-2)을 보유해야 실행한다.
func _try_start_damage_pattern() -> bool:
	if _crossbow:
		return _try_start_crossbow()
	if not _charge.is_ready():
		return false
	if distance_tiles_to(target.global_position) > stats.charge_distance_tiles:
		return false
	if not PackAggroCoordinator.try_acquire_attack_token(pack_id):
		velocity = Vector2.ZERO  ## 토큰 없음 — 포위 대기(combat.md 2-2)
		return true
	_start_charge()
	return true


## 밀렵꾼은 원거리 견제형이라 사거리 안이면 조준 사격, 사거리 밖이면 접근한다.
func _try_start_crossbow() -> bool:
	if _crossbow.phase != AimFireBlock.Phase.IDLE:
		return false
	if distance_tiles_to(target.global_position) > stats.projectile_range_tiles:
		return false
	if not PackAggroCoordinator.try_acquire_attack_token(pack_id):
		velocity = Vector2.ZERO
		return true
	_start_crossbow()
	return true


func _chase_velocity() -> Vector2:
	return move_toward_point(target.global_position, stats.combat_move_speed_tiles)


# --- 돌진 (spec 3-3장) ---


func _start_charge() -> void:
	state = State.CHARGE
	_charge_hit_landed = false
	_charge.start()


## 예고 시작 시점의 플레이어 방향으로 고정한다(spec 3-3 "직선이라 측면 이동으로 회피").
func _on_charge_telegraph_started() -> void:
	_charge_velocity = Vector2.ZERO
	if target:
		var to_target := target.global_position - global_position
		if not to_target.is_zero_approx() and to_target.is_finite():
			_charge_velocity = (
				to_target.normalized() * stats.tiles_to_px(stats.charge_speed_tiles)
			)
	_play_animation_or("charge_telegraph", "attack", _charge_velocity)
	if _sprite:
		_sprite.modulate = Color(1.0, 0.3, 0.3)  ## 예고 표시 — vfx-artist 후속 작업 전까지 임시


func _on_charge_started() -> void:
	current_attack_multiplier = stats.charge_damage_mult
	_enable_attack_hitbox()
	_play_animation_or("charge", "walk", _charge_velocity)
	charge_started.emit(_charge_velocity.normalized())


func _on_charge_ended() -> void:
	_disable_attack_hitbox()
	current_attack_multiplier = 1.0


## 경로 판정은 "접촉 시 1회"(spec 3-3)라, 첫 명중 즉시 히트박스를 끈다. 이 함수는
## AttackHitbox의 body_entered 처리 중에 실행되므로 monitoring을 직접 끌 수 없다 —
## _disable_attack_hitbox_deferred()를 써야 한다(MonsterBase 해당 함수 주석 참고).
func _on_charge_path_hit(_body: Node) -> void:
	if _charge_hit_landed or not _charge.is_charging():
		return
	_charge_hit_landed = true
	_disable_attack_hitbox_deferred()


func _on_charge_pattern_ended() -> void:
	PackAggroCoordinator.release_attack_token(pack_id)
	if is_dead():
		return
	state = State.CHASE


## 근거리에서 플레이어가 붙어 있으면 예고 중 뒤로 물러나 활주로(최소 2타일)를 확보한다
## (spec 3-3 "근거리 시 최소 2타일 백스텝 후 돌진" — 항상 돌진이 성립하게).
func _process_charge() -> void:
	if _charge.is_charging():
		velocity = _charge_velocity
		if _is_blocked_by_wall():
			_charge.hit_wall()
			charge_hit_wall.emit()
		return
	if _charge.phase == ChargeBlock.Phase.TELEGRAPH and _needs_backstep():
		velocity = move_away_from_point(target.global_position, stats.wander_speed_tiles)
		return
	velocity = Vector2.ZERO


func _needs_backstep() -> bool:
	if target == null:
		return false
	return distance_tiles_to(target.global_position) < stats.charge_min_distance_tiles


func _is_blocked_by_wall() -> bool:
	return get_slide_collision_count() > 0 and is_on_wall()


# --- 가드 (spec 3-4장 — 무피해 방어) ---


func _start_guard() -> void:
	_guard_reaction_pending = false
	if not _guard.is_ready() or _charge_is_busy():
		return
	state = State.GUARD
	_guard.start()


func _charge_is_busy() -> bool:
	return _charge != null and _charge.is_busy()


func _on_guard_entered() -> void:
	_play_animation_or("guard", "idle")


func _on_guard_ended() -> void:
	_play_animation("idle")


func _on_guard_broken() -> void:
	_play_animation_or("hit", "idle")
	guard_broken.emit()


## 정면(±60°) 일반 피격은 −60% 감쇄 + 1회 흘림, 강 등급(치명타·차지 강타)은 가드 브레이크.
func _filter_incoming_damage(amount: float, hit_grade: String, attacker: Node2D) -> float:
	_last_hit_was_guarded = false
	if not _guard.is_guarding() or not _is_frontal_attacker(attacker):
		return amount
	if hit_grade == "강":
		_guard.notify_guard_break()  ## 감쇄 없이 그대로 맞고 경직 1.0초(딜찬스)
		return amount
	_last_hit_was_guarded = true
	_guard.notify_absorbed_hit()
	return amount * (1.0 - stats.guard_damage_reduction_pct)


## 가드로 흘린 정면 일반 피격은 넉백·경직이 무효다(spec 3-4). 정예 슈퍼아머 판정은
## MonsterBase 기본 구현을 그대로 유지한다.
func _ignores_stagger(hit_grade: String, attacker: Node2D) -> bool:
	return _last_hit_was_guarded or super._ignores_stagger(hit_grade, attacker)


func _is_frontal_attacker(attacker: Node2D) -> bool:
	if attacker == null:
		return false
	var to_attacker := attacker.global_position - global_position
	if to_attacker.is_zero_approx() or not to_attacker.is_finite():
		return false
	var facing := Vector2.LEFT if _facing_left else Vector2.RIGHT
	return absf(rad_to_deg(facing.angle_to(to_attacker))) <= stats.guard_frontal_arc_deg * 0.5


# --- 석궁 조준 사격 (spec 7-3 밀렵꾼 아종 — AimFireBlock 재사용, 데미지 있음) ---


func _start_crossbow() -> void:
	if target:
		_crossbow_aim_point = target.global_position
	_crossbow.start_aim()


func _on_crossbow_aim_started() -> void:
	_play_animation_or("aim", "attack", _crossbow_aim_point - global_position)
	if _sprite:
		_sprite.modulate = Color(1.0, 0.3, 0.3)


func _on_crossbow_fired() -> void:
	PackAggroCoordinator.release_attack_token(pack_id)
	if _sprite:
		_sprite.modulate = Color(1.0, 1.0, 1.0)
	_play_animation("idle")
	_spawn_crossbow_bolt(_crossbow_aim_point)


func _spawn_crossbow_bolt(aim_point: Vector2) -> void:
	if projectile_scene == null:
		return
	var bolt := projectile_scene.instantiate() as Node2D
	_world_spawn_parent().add_child(bolt)
	bolt.global_position = global_position
	if bolt.has_method("configure"):
		bolt.call("configure", effective_attack_power(), formula_data)
	if bolt.has_method("launch"):
		bolt.call("launch", aim_point, stats.tiles_to_px(stats.projectile_speed_tiles))


# --- 공용 ---


func _enter_chase(new_target: Node2D) -> void:
	if is_dead():
		return
	if new_target:
		target = new_target
	state = State.CHASE


func _cancel_patterns() -> void:
	if _charge_is_busy():
		_charge.cancel()
		PackAggroCoordinator.release_attack_token(pack_id)
	if _crossbow and _crossbow.phase == AimFireBlock.Phase.AIMING:
		_crossbow.reset()
		PackAggroCoordinator.release_attack_token(pack_id)
	if state == State.CHARGE:
		state = State.CHASE


# --- 무리 어그로 공유 + 가드 반응 (CB-3 연동 지점: 실제 피해 계산은 gameplay-dev) ---


func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	super.take_damage(amount, hit_grade, attacker)
	if is_dead():
		return
	var aggro_target: Node2D = attacker if attacker else target
	if state == State.WANDER and aggro_target:
		_enter_chase(aggro_target)
	if _guard.is_ready() and not _charge_is_busy():
		_guard_reaction_pending = true  ## 헤더 "가드 발동 조건" 참고
	if stats.shares_pack_aggro and not pack_id.is_empty() and aggro_target:
		get_tree().call_group(_pack_group_name(), "_on_pack_member_aggroed", aggro_target)


func _on_pack_member_aggroed(shared_target: Node2D) -> void:
	if is_dead() or state != State.WANDER:
		return
	_enter_chase(shared_target)


func _pack_group_name() -> String:
	return "outlaw_pack_%s" % pack_id
