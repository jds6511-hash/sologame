## 숲거미 (벌레 / Lv10) — m3-monster-spec.md 4-1장.
##
## 상태 전이 (spec 4-1장 원문 그대로):
##   [배회] --(인지범위 6타일 진입)--> [추적/포지셔닝]
##   [추적] --(사거리 2~4타일 & 거미줄 쿨다운 준비)--> [거미줄 조준](0.6초)
##       --> [거미줄 발사](둔화 −40%/2.0초) --> 쿨다운(5.0초) --> [추적]
##   [추적] --(사거리 1~4타일 & 도약 쿨다운 준비)--> [도약 예고](0.5초, 착지 지점 고정)
##       --> [도약](0.35초) --> [착지 판정](0.15초) --> [후딜](0.4초) --> [추적]
##   [추적] --(스폰 지점 8타일 이탈)--> [귀환](HP 완전 회복) --> [배회]
##   [HP 0] --> 사망 (드랍 판정, spec 5-1장)
##
## 행동 블록 조합(4개, 데미지 예고 패턴 1개): 배회 → 추적 → 도약(LeapBlock, 데미지) →
## 거미줄 둔화(AimFireBlock 재사용, 무피해 제어). 무리는 어그로 공유 없는 개별 급습이라
## PackAggroCoordinator를 쓰지 않는다(spec 4-1 "솔로 규칙", pack_id 개념 없음).
##
## 거미줄 둔화 연동 지점(CB-3/gameplay-dev 계약과 동일 방식): 플레이어에 둔화를 적용하는
## 공용 API가 아직 없으므로, 명중 시 web_slow_applied 시그널로 "누구에게 몇 % 몇 초"만
## 알리고 duck-typing으로 apply_move_speed_slow(pct, sec)가 있으면 호출한다 — 실제 플레이어
## 이동속도 감소 처리는 gameplay-dev 후속 작업(scripts/player는 본 태스크 범위 밖).
##
## 투사체 씬(web_projectile_scene)은 미할당(null)이면 web_fired 시그널만 발생한다(균열 점액과
## 동일 패턴). C-9(스프라이트)·vfx 작업 전까지는 기존 rift_slime_projectile.tscn을 임시로
## 할당해도 무피해로 동작한다(configure()에 formula_data=null을 넘기므로 직격 피해 없음).
##
## ai-dev 구현 결정(spec 미기재 — systems-designer 확인 대상, 디렉터 결정 아님):
##   - 거미줄 최소 사거리 2타일(WEB_MIN_RANGE_TILES): spec 4-1 상태 전이도의 "사거리 2~4타일"
##     하한을 상수화했다(데이터화하지 않은 이유 = 상태 전이도에 고정된 값이라 종별 차이 없음).
##   - 도약 예고·거미줄 조준 중 피격 경직 시 해당 블록을 cancel()로 취소한다(spec 4-1 주석
##     "예고 캔슬 = 딜찬스"). 취소된 블록은 쿨다운으로 넘어간다(LeapBlock 헤더 참고).
class_name ForestSpiderMonster
extends MonsterBase

signal web_fired(aim_position: Vector2)
## 거미줄 명중 — 둔화 적용 연동 지점(헤더 참고)
signal web_slow_applied(target: Node, slow_pct: float, duration_sec: float)
signal leap_landed(land_position: Vector2)

enum State { WANDER, CHASE, WEB_AIM, LEAP, RETURN }

const WEB_MIN_RANGE_TILES := 2.0  ## spec 4-1 "사거리 2~4타일"의 하한

## 거미줄 투사체 씬 — 미할당(null)이면 판정 없이 web_fired 시그널만 발생(테스트/미배선 대응)
@export var web_projectile_scene: PackedScene

var state: State = State.WANDER

var _wander_dir := Vector2.ZERO
var _wander_timer: float = 0.0
var _leap: LeapBlock
var _web: AimFireBlock
var _leap_land_point := Vector2.ZERO
var _leap_velocity := Vector2.ZERO
var _web_aim_point := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_init_leap()
	_init_web()
	## 히트박스는 도약 착지 판정 전용이라 반경을 착지 반경(1.0타일)으로 맞춘다.
	_setup_attack_hitbox(stats.leap_land_radius_tiles)
	_wander_dir = random_wander_direction()
	_wander_timer = randf_range(1.0, 2.5)


func _init_leap() -> void:
	_leap = LeapBlock.new()
	_leap.telegraph_sec = stats.leap_telegraph_sec
	_leap.travel_sec = stats.leap_travel_sec
	_leap.active_sec = stats.leap_active_sec
	_leap.recovery_sec = stats.leap_recovery_sec
	_leap.cooldown_sec = stats.leap_cooldown_sec
	_leap.telegraph_started.connect(_on_leap_telegraph_started)
	_leap.leap_started.connect(_on_leap_started)
	_leap.became_active.connect(_on_leap_became_active)
	_leap.active_ended.connect(_on_leap_active_ended)


func _init_web() -> void:
	_web = AimFireBlock.new()
	_web.telegraph_sec = stats.web_telegraph_sec
	_web.cooldown_sec = stats.web_cooldown_sec
	_web.aim_started.connect(_on_web_aim_started)
	_web.fired.connect(_on_web_fired)


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	if is_staggered():
		_cancel_patterns()
		velocity = _knockback_velocity
		_guard_finite_before_move()
		move_and_slide()
		return
	## 쿨다운은 다른 상태에서도 계속 흐른다(도약 중에도 거미줄 쿨다운 진행 — spec 3-2
	## "도약 쿨다운과 어긋나게 두어 2단 압박이 간헐적으로만 성립").
	_leap.update(delta)
	_web.update(delta)
	match state:
		State.WANDER:
			_process_wander(delta)
			if is_target_in_range_tiles(stats.perception_range_tiles):
				_enter_chase(target)
		State.CHASE:
			_process_chase()
		State.WEB_AIM:
			velocity = Vector2.ZERO
			if not _web_is_aiming():
				state = State.CHASE
		State.LEAP:
			_process_leap()
		State.RETURN:
			if _return_to_home():
				state = State.WANDER
	_guard_finite_before_move()
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
	var distance := distance_tiles_to(target.global_position)
	if _web.phase == AimFireBlock.Phase.IDLE and _is_web_range(distance):
		_start_web()
		return
	if _leap.is_ready() and distance <= stats.leap_max_range_tiles:
		_start_leap()
		return
	velocity = move_toward_point(target.global_position, stats.combat_move_speed_tiles)
	_play_animation("walk", velocity)


func _is_web_range(distance_tiles: float) -> bool:
	return distance_tiles >= WEB_MIN_RANGE_TILES and distance_tiles <= stats.web_range_tiles


# --- 도약 (spec 3-1장) ---


## 착지 지점은 예고 시작 시점의 플레이어 위치로 고정한다(spec 3-1 "예측이 아니라 반응").
## 이동 거리는 최소 1타일~최대 4타일로 제한해 근거리에서는 "짧은 도약 물기"가 된다.
func _start_leap() -> void:
	state = State.LEAP
	_leap_land_point = _resolve_land_point()
	_leap.start()


func _resolve_land_point() -> Vector2:
	if target == null:
		return global_position
	var to_target := target.global_position - global_position
	if to_target.is_zero_approx() or not to_target.is_finite():
		return global_position
	var distance_tiles := clampf(
		to_target.length() / stats.tile_size_px,
		stats.leap_min_range_tiles,
		stats.leap_max_range_tiles
	)
	return global_position + to_target.normalized() * stats.tiles_to_px(distance_tiles)


func _process_leap() -> void:
	if _leap.is_traveling():
		velocity = _leap_velocity
		_play_animation_or("leap", "walk", velocity)
		return
	velocity = Vector2.ZERO
	if not _leap.is_busy():
		state = State.CHASE


func _on_leap_telegraph_started() -> void:
	_play_animation_or("crouch", "attack", _leap_land_point - global_position)
	if _sprite:
		_sprite.modulate = Color(1.0, 0.3, 0.3)  ## 예고 표시 — vfx-artist 후속 작업 전까지 임시


func _on_leap_started() -> void:
	var travel := _leap_land_point - global_position
	_leap_velocity = Vector2.ZERO
	if stats.leap_travel_sec > 0.0 and travel.is_finite():
		_leap_velocity = travel / stats.leap_travel_sec


func _on_leap_became_active() -> void:
	_leap_velocity = Vector2.ZERO
	current_attack_multiplier = stats.leap_damage_mult
	_enable_attack_hitbox()
	_play_animation_or("land", "attack")
	leap_landed.emit(global_position)


func _on_leap_active_ended() -> void:
	_disable_attack_hitbox()
	current_attack_multiplier = 1.0


# --- 거미줄 둔화 (spec 3-2장 — AimFireBlock 재사용, 무피해) ---


func _start_web() -> void:
	if target:
		_web_aim_point = target.global_position  ## 조준 시작 시점의 착탄 지점 고정
	_web.start_aim()


func _on_web_aim_started() -> void:
	state = State.WEB_AIM
	_play_animation_or("web", "attack", _web_aim_point - global_position)


func _on_web_fired() -> void:
	state = State.CHASE
	web_fired.emit(_web_aim_point)
	_spawn_web_projectile(_web_aim_point)


func _web_is_aiming() -> bool:
	return _web.phase == AimFireBlock.Phase.AIMING


func _spawn_web_projectile(aim_point: Vector2) -> void:
	if web_projectile_scene == null:
		return
	var projectile := web_projectile_scene.instantiate() as Node2D
	get_tree().root.add_child(projectile)
	projectile.global_position = global_position
	if projectile.has_signal("hit_target"):
		projectile.connect("hit_target", _on_web_projectile_hit)
	## 무피해(spec 3-2 web_damage_mult=0.0) — formula_data를 넘기지 않아 직격 피해가 없다.
	if projectile.has_method("configure"):
		projectile.call("configure", 0.0, null)
	if projectile.has_method("launch"):
		projectile.call("launch", aim_point, stats.tiles_to_px(stats.web_speed_tiles))


## 거미줄 명중 — 이동속도 −40%(그림자 숲거미 아종은 지속 3.0초)를 대상에 요청한다.
func _on_web_projectile_hit(body: Node) -> void:
	web_slow_applied.emit(body, stats.web_slow_pct, stats.web_slow_duration_sec)
	if body.has_method("apply_move_speed_slow"):
		body.call("apply_move_speed_slow", stats.web_slow_pct, stats.web_slow_duration_sec)


# --- 공용 ---


func _enter_chase(new_target: Node2D) -> void:
	if is_dead():
		return
	if new_target:
		target = new_target
	state = State.CHASE


## 피격 경직 시 예고 중인 블록을 취소한다(spec 4-1 "예고 캔슬 = 딜찬스").
func _cancel_patterns() -> void:
	if _leap.is_busy():
		_leap.cancel()
		_disable_attack_hitbox()
		current_attack_multiplier = 1.0
	if _web_is_aiming():
		_web.reset()
	if state == State.LEAP or state == State.WEB_AIM:
		state = State.CHASE


## 어그로 공유가 없는 개별 급습 개체(spec 4-1)라 피격 시 자기 자신만 추적에 들어간다.
func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	super.take_damage(amount, hit_grade, attacker)
	if is_dead():
		return
	if state == State.WANDER:
		_enter_chase(attacker if attacker else target)
