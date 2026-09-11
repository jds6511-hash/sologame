## 뿔토끼 (HitFeedback 약 대표) — m2-monster-spec.md 3-1장.
##
## 상태 전이 (spec 3-1장 원문 그대로):
##   [배회] --(플레이어가 인지범위 3타일 진입)--> [도주] (1.5초 지속, 4.0타일/초)
##   [도주] --(도주 시간 종료 & 플레이어와 거리 확보)--> [배회] 복귀
##   [도주] --(도주 중 플레이어에게 붙잡힘 — 벽·구석 등 도주 경로 없음)-->
##       [근접 스윙](박치기, 1회) --> [도주] 재시도
##   [HP 0] --> 사망 (드랍 판정)
##
## 구현 단순화(assumption): "붙잡힘" 판정은 벽 충돌 감지 대신, 도주 중 플레이어와의
## 거리가 근접 스윙 사거리(melee_range_tiles) 이내로 좁혀지는 순간으로 근사한다.
## "거리 확보" 판정은 인지범위(perception_range_tiles) 밖으로 벗어난 상태로 근사한다.
## 둘 다 spec에 정확한 판정 기준이 없어 ai-dev가 정한 임시 규칙 — systems-designer
## 확인 필요 시 조정 대상(디렉터 결정 사항은 아님).
##
## 행동 블록 조합(2개, combat.md 9-2 잡몹 규격 충족): 배회 → 도주 (근접 스윙은 도주의
## 서브 동작으로 취급, spec 3-1장 그대로).
class_name RabbitMonster
extends MonsterBase

enum State { WANDER, FLEE, MELEE_SWING }

var state: State = State.WANDER

var _wander_dir := Vector2.ZERO
var _wander_timer: float = 0.0
var _flee_timer: float = 0.0


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
	if target and is_target_in_range_tiles(stats.melee_range_tiles):
		_start_melee_swing()
		return
	velocity = (
		move_away_from_point(target.global_position, stats.combat_move_speed_tiles)
		if target
		else Vector2.ZERO
	)
	_play_animation("walk", velocity)
	var distance_secured := (
		target == null or not is_target_in_range_tiles(stats.perception_range_tiles)
	)
	if _flee_timer <= 0.0 and distance_secured:
		state = State.WANDER


func _start_melee_swing() -> void:
	state = State.MELEE_SWING
	_swing.start()
	_play_animation("attack")


func _on_swing_ended() -> void:
	if is_dead():
		return
	_start_flee()  ## spec: 근접 스윙 종료 후 도주 재시도
