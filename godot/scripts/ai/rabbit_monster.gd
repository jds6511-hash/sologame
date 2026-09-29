## 뿔토끼 (HitFeedback 약 대표) — m2-monster-spec.md 3-1장.
##
## 상태 전이 (2026-09-28 디렉터 추격 피드백 반영):
##   [배회] --(플레이어가 인지범위 3타일 진입)--> [도주] (1.5초 지속, 4.0타일/초)
##   [도주] --(도주 시간 종료)--> [휴식] (0.8초 정지, 재도주·공격 없음)
##   [휴식 종료] --> 인지범위 안이면 도주, 밖이면 배회
##   [도주] --(도주 중 플레이어에게 붙잡힘 — 벽·구석 등 도주 경로 없음)-->
##       [근접 스윙](박치기, 1회) --> [도주] 재시도
##   [HP 0] --> 사망 (드랍 판정)
##
## 구현 단순화(assumption): "붙잡힘" 판정은 벽 충돌 감지 대신, 도주 중 플레이어와의
## 거리가 근접 스윙 사거리(melee_range_tiles) 이내로 좁혀지는 순간으로 근사한다.
## "붙잡힘"의 정확한 판정 기준이 없어 ai-dev가 정한 임시 규칙 — systems-designer
## 확인 필요 시 조정 대상(디렉터 결정 사항은 아님).
##
## 행동 블록 조합(2개, combat.md 9-2 잡몹 규격 충족): 배회 → 도주 (근접 스윙은 도주의
## 서브 동작으로 취급, spec 3-1장 그대로).
class_name RabbitMonster
extends MonsterBase

enum State { WANDER, FLEE, MELEE_SWING, REST }

var state: State = State.WANDER

var _wander_dir := Vector2.ZERO
var _wander_timer: float = 0.0
var _flee_timer: float = 0.0
var _rest_timer: float = 0.0


func blocks_save_from(position: Vector2, radius: float) -> bool:
	if not super.blocks_save_from(position, radius):
		return false
	# 인지 밖 평시 배회만 제외한다. 도주/휴식/박치기 또는 피격 중에는 거리 계약 유지.
	if state != State.WANDER or stats == null or is_staggered() or is_dead():
		return true
	return global_position.distance_to(position) <= stats.tiles_to_px(stats.perception_range_tiles)


func _ready() -> void:
	super._ready()
	_init_melee_swing()
	_swing.ended.connect(_on_swing_ended)
	_wander_dir = random_wander_direction()
	_wander_timer = randf_range(1.0, 2.5)


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	if is_staggered():
		velocity = stagger_velocity()
		if _guard_finite_before_move():
			move_and_slide()
		return
	match state:
		State.WANDER:
			_process_wander(delta)
			if is_target_in_range_tiles(stats.perception_range_tiles):
				_start_flee()
		State.FLEE:
			_process_flee(delta)
		State.REST:
			_process_rest(delta)
		State.MELEE_SWING:
			velocity = Vector2.ZERO
			_swing.update(delta)
	if _guard_finite_before_move():
		move_and_slide()


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_dir = random_wander_direction()
		_wander_timer = randf_range(1.0, 2.5)
	velocity = _wander_dir * stats.tiles_to_px(stats.wander_speed_tiles)
	_play_animation("walk", velocity)


func _start_flee() -> void:
	state = State.FLEE
	_flee_timer = stats.flee_duration_sec


func _process_flee(delta: float) -> void:
	_flee_timer -= delta
	if _flee_timer <= 0.0:
		state = State.REST
		_rest_timer = stats.flee_rest_duration_sec
		velocity = Vector2.ZERO
		_play_animation("idle", velocity)
		return
	if target and is_target_in_range_tiles(stats.melee_range_tiles):
		_start_melee_swing()
		return
	velocity = (
		move_away_from_point(target.global_position, stats.combat_move_speed_tiles)
		if target
		else Vector2.ZERO
	)
	_play_animation("walk", velocity)


func _process_rest(delta: float) -> void:
	velocity = Vector2.ZERO
	_play_animation("idle", velocity)
	_rest_timer -= delta
	if _rest_timer <= 0.0:
		if is_target_in_range_tiles(stats.perception_range_tiles):
			_start_flee()
		else:
			state = State.WANDER


func _start_melee_swing() -> void:
	state = State.MELEE_SWING
	_begin_melee_swing(target.global_position if target else global_position)


func _on_swing_ended() -> void:
	if is_dead():
		return
	_start_flee()  ## spec: 근접 스윙 종료 후 도주 재시도
