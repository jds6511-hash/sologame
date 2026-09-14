## 임프 (균열 / Lv16) — m3-monster-spec.md 4-3장. 아종: 포효 임프장(정예, Lv16).
##
## 상태 전이 (spec 4-3장 원문 그대로):
##   [배회] --(인지범위 5타일 진입 또는 무리원 피격 — 어그로 공유)--> [추적]
##   [추적] --(전투 진입 시 & 포효 쿨다운 준비)--> [포효 예고](0.5초)
##       --> [포효](무리 버프 공격력·이속 +15%/6초) --> [추적]
##   [추적] --(플레이어와 거리 3타일 이상 = 카이팅 감지 & 순간이동 쿨다운 준비)
##       --> [순간이동 예고](0.3초) --> [순간이동](측면/후방 2~3타일) --> [등장 후딜](0.3초) --> [추적]
##   [추적] --(근접 사거리 1.5타일 이내 & 공격 토큰 보유)--> [근접 스윙](예고 0.5초) --> [추적]
##   [추적] --(스폰 지점 8타일 이탈)--> [귀환](HP 완전 회복) --> [배회]
##   [HP 0] --> 사망 (드랍 판정, spec 5-3장)
##
## 행동 블록 조합(5개, 데미지 예고 패턴 1개): 배회 → 추적 → 근접 스윙(M2 MeleeSwingBlock
## 재사용, 데미지) → 순간이동(BlinkBlock, 무피해 재배치) → 포효 버프(RoarBuffBlock, 무피해).
## 무리는 어그로 공유 O + 공격 토큰 2(PackAggroCoordinator, 그룹명 imp_pack_<id>).
##
## 포효 버프 적용 방식: 모든 임프가 ROAR_GROUP에 속하고, 포효한 개체가 반경(4타일, 정예
## 아종은 6타일) 내 그룹원에게 apply_roar_buff()를 호출한다 — 무리(pack_id) 배정과 무관하게
## "주변 균열 아군"이면 버프가 걸린다(spec 3-6 "반경 4타일 내 아군(임프 자신 포함)").
## 버프는 공격력(effective_attack_power)과 추적 이동속도에 각각 +15%로 반영되며, 지속
## 6.0초 < 쿨다운 12.0초라 가동률 50%가 유지된다.
##
## 아종 처리 (spec 7-4 포효 임프장 — 신규 상태머신 없이 데이터 차이로만):
##   imp_lord_stats.tres = 정예 배율(HP×6/공격력×1.5) + is_elite=true(평시 슈퍼아머,
##   combat.md 5-2) + 포효 강화(반경 6타일·+20%) + 순간이동 쿨다운 6.0초(지휘관이라 저빈도).
##   그로기 게이지는 정예 공용 프레임 소관이라 C-8 범위 밖이다(spec 7-5장 "정예 시스템 귀속").
class_name ImpMonster
extends MonsterBase

signal blinked(destination: Vector2)
signal roared(radius_tiles: float, atk_buff_pct: float)

enum State { WANDER, CHASE, MELEE_SWING, BLINK, ROAR, RETURN }

const ROAR_GROUP := "imp_roar_allies"  ## 포효 버프 대상(균열 아군) 그룹

## 무리 식별자 — 비어 있으면 솔로 개체(토큰 제한 없음, 어그로 공유 없음). C-10에서 부여한다.
@export var pack_id: String = ""

var state: State = State.WANDER

var _wander_dir := Vector2.ZERO
var _wander_timer: float = 0.0
var _blink: BlinkBlock
var _roar: RoarBuffBlock
var _blink_destination := Vector2.ZERO
var _buff_timer: float = 0.0
var _buff_atk_pct: float = 0.0
var _buff_speed_pct: float = 0.0


func _ready() -> void:
	super._ready()
	_init_melee_swing()
	_swing.ended.connect(_on_swing_ended)
	_init_blink()
	_init_roar()
	_wander_dir = random_wander_direction()
	_wander_timer = randf_range(1.0, 2.5)
	add_to_group(ROAR_GROUP)
	if stats.shares_pack_aggro and not pack_id.is_empty():
		add_to_group(_pack_group_name())


func _init_blink() -> void:
	_blink = BlinkBlock.new()
	_blink.telegraph_sec = stats.blink_telegraph_sec
	_blink.recovery_sec = stats.blink_recovery_sec
	_blink.cooldown_sec = stats.blink_cooldown_sec
	_blink.blink_telegraph_started.connect(_on_blink_telegraph_started)
	_blink.blinked.connect(_on_blinked)
	_blink.recovery_ended.connect(_on_blink_recovery_ended)


func _init_roar() -> void:
	_roar = RoarBuffBlock.new()
	_roar.telegraph_sec = stats.roar_telegraph_sec
	_roar.cooldown_sec = stats.roar_cooldown_sec
	_roar.roar_telegraph_started.connect(_on_roar_telegraph_started)
	_roar.roared.connect(_on_roared)


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	_advance_buff(delta)
	if is_staggered():
		_cancel_patterns()
		velocity = stagger_velocity()
		if _guard_finite_before_move():
			move_and_slide()
		return
	_blink.update(delta)
	_roar.update(delta)
	match state:
		State.WANDER:
			_process_wander(delta)
			if is_target_in_range_tiles(stats.perception_range_tiles):
				_enter_chase(target)
		State.CHASE:
			_process_chase()
		State.MELEE_SWING:
			velocity = Vector2.ZERO
			_swing.update(delta)
		State.BLINK:
			velocity = Vector2.ZERO
			if not _blink.is_busy():
				state = State.CHASE
		State.ROAR:
			velocity = Vector2.ZERO
			if not _roar.is_busy():
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


## 우선순위: 포효(전투 진입 시) → 근접 스윙(사거리 내) → 순간이동(카이팅 감지) → 접근.
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
	if _roar.is_ready():
		_start_roar()
		return
	var distance := distance_tiles_to(target.global_position)
	if distance <= stats.melee_range_tiles:
		if PackAggroCoordinator.try_acquire_attack_token(pack_id):
			_start_melee_swing()
		else:
			velocity = Vector2.ZERO  ## 공격 토큰 없음 — 포위 대기(combat.md 2-2)
		return
	if _blink.is_ready() and distance >= stats.blink_trigger_distance_tiles:
		_start_blink()
		return
	velocity = move_toward_point(target.global_position, _buffed_move_speed_tiles())
	_play_animation("walk", velocity)


func _buffed_move_speed_tiles() -> float:
	return stats.combat_move_speed_tiles * (1.0 + _buff_speed_pct)


# --- 근접 스윙 (M2 MeleeSwingBlock 재사용) ---


func _start_melee_swing() -> void:
	state = State.MELEE_SWING
	_begin_melee_swing(target.global_position if target else global_position)


func _on_swing_ended() -> void:
	PackAggroCoordinator.release_attack_token(pack_id)
	if is_dead():
		return
	state = State.CHASE


# --- 순간이동 (spec 3-5장 — 무피해 재배치) ---


func _start_blink() -> void:
	state = State.BLINK
	_blink_destination = _resolve_blink_destination()
	_blink.start()


## 목표 지점 = 플레이어 측면(좌/우 무작위) 2~3타일. 최대 이동 거리(5타일)를 넘으면 같은
## 방향으로 최대 거리까지만 이동한다(spec 3-5 "측면으로 돌아 카이팅 각을 무너뜨림").
func _resolve_blink_destination() -> Vector2:
	if target == null:
		return global_position
	var from_target := global_position - target.global_position
	if from_target.is_zero_approx() or not from_target.is_finite():
		from_target = Vector2.RIGHT * stats.tile_size_px
	var side_sign := 1.0 if randf() < 0.5 else -1.0
	var side := from_target.normalized().rotated(PI * 0.5) * side_sign
	var destination := (
		target.global_position + side * stats.tiles_to_px(stats.blink_target_offset_tiles)
	)
	var travel := destination - global_position
	var max_px := stats.tiles_to_px(stats.blink_max_range_tiles)
	if travel.length() > max_px and not travel.is_zero_approx():
		destination = global_position + travel.normalized() * max_px
	return destination


func _on_blink_telegraph_started() -> void:
	_play_animation_or("vanish", "idle")


func _on_blinked() -> void:
	if _blink_destination.is_finite():
		global_position = _blink_destination
	_play_animation_or("appear", "idle")
	blinked.emit(global_position)


func _on_blink_recovery_ended() -> void:
	_play_animation("idle")


# --- 포효 버프 (spec 3-6장 — 무피해, 반경 내 아군 강화) ---


func _start_roar() -> void:
	state = State.ROAR
	_roar.start()


func _on_roar_telegraph_started() -> void:
	_play_animation_or("roar", "attack")


func _on_roared() -> void:
	roared.emit(stats.roar_radius_tiles, stats.roar_atk_buff_pct)
	var radius_px := stats.tiles_to_px(stats.roar_radius_tiles)
	for node in get_tree().get_nodes_in_group(ROAR_GROUP):
		var ally := node as Node2D
		if ally == null or not ally.has_method("apply_roar_buff"):
			continue
		if ally.global_position.distance_to(global_position) > radius_px:
			continue
		ally.apply_roar_buff(
			stats.roar_atk_buff_pct, stats.roar_speed_buff_pct, stats.roar_buff_duration_sec
		)


## 포효 버프 수신 — 공격력·이동속도 증가율과 남은 지속 시간을 갱신한다(중첩하지 않고
## 더 강한 버프·더 긴 지속으로 갱신 — spec에 중첩 규칙이 없어 폭주 방지 쪽으로 근사했다).
func apply_roar_buff(atk_pct: float, speed_pct: float, duration_sec: float) -> void:
	if is_dead():
		return
	_buff_atk_pct = maxf(_buff_atk_pct, atk_pct)
	_buff_speed_pct = maxf(_buff_speed_pct, speed_pct)
	_buff_timer = maxf(_buff_timer, duration_sec)


func is_buffed() -> bool:
	return _buff_timer > 0.0


func _advance_buff(delta: float) -> void:
	if _buff_timer <= 0.0:
		return
	_buff_timer -= delta
	if _buff_timer <= 0.0:
		_buff_timer = 0.0
		_buff_atk_pct = 0.0
		_buff_speed_pct = 0.0


## 포효 버프 공격력 +15%(정예 아종 +20%)를 야간 배율·블록 계수 위에 곱한다.
func effective_attack_power() -> float:
	return super.effective_attack_power() * (1.0 + _buff_atk_pct)


# --- 공용 ---


func _enter_chase(new_target: Node2D) -> void:
	if is_dead():
		return
	if new_target:
		target = new_target
	state = State.CHASE


func _cancel_patterns() -> void:
	if _blink.is_busy():
		_blink.cancel()
	if _roar.is_busy():
		_roar.cancel()
	if state == State.BLINK or state == State.ROAR:
		state = State.CHASE


# --- 무리 어그로 공유 (CB-3 연동 지점: 실제 피해 계산은 gameplay-dev) ---


func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	super.take_damage(amount, hit_grade, attacker)
	if is_dead():
		return
	var aggro_target: Node2D = attacker if attacker else target
	if aggro_target == null:
		return
	if state == State.WANDER:
		_enter_chase(aggro_target)
	if stats.shares_pack_aggro and not pack_id.is_empty():
		get_tree().call_group(_pack_group_name(), "_on_pack_member_aggroed", aggro_target)


func _on_pack_member_aggroed(shared_target: Node2D) -> void:
	if is_dead() or state != State.WANDER:
		return
	_enter_chase(shared_target)


func _pack_group_name() -> String:
	return "imp_pack_%s" % pack_id
