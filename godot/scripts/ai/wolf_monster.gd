## 들개 마수 (HitFeedback 중 대표) — m2-monster-spec.md 3-2장.
##
## 상태 전이 (spec 3-2장 원문 그대로):
##   [배회] --(인지범위 5타일 진입 또는 무리원 피격 — 무리 어그로 공유)--> [추적]
##   [추적] --(사거리 1.5타일 이내)--> [근접 스윙](물기, 공격 토큰 보유 시에만 실행)
##   [근접 스윙] --(스윙 종료)--> [추적] 복귀 (쿨다운 없이 재접근)
##   [추적] --(스폰 지점 기준 8타일 이탈)--> [귀환](스폰 지점 복귀, HP 완전 회복) --> [배회]
##   [HP 0] --> 사망 (드랍 판정)
##
## 무리 어그로 공유(combat.md 2-2)는 Godot 그룹으로 구현한다 — 같은 pack_id를 가진
## 개체들이 "wolf_pack_<id>" 그룹에 속하고, 한 마리가 피격되면 그룹 전체에
## _on_pack_member_aggroed()를 호출해 추적을 시작시킨다. 공격 토큰(최대 2마리)은
## PackAggroCoordinator가 pack_id 단위로 관리한다. 실제 무리 배치(같은 pack_id 부여)는
## MP-4(레벨 배치, level-designer+ai-dev)에서 처리한다 — 본 스크립트는 규칙만 제공한다.
##
## 행동 블록 조합(3개): 배회 → 추적 → 근접 스윙(+ 귀환).
class_name WolfMonster
extends MonsterBase

enum State { WANDER, CHASE, MELEE_SWING, RETURN }

const ARRIVAL_TOLERANCE_PX := 4.0

## 무리 식별자 — 비어 있으면 솔로 개체(토큰 제한 없음, 어그로 공유 없음).
## MP-4에서 같은 무리 개체에 동일 문자열을 부여한다.
@export var pack_id: String = ""

var state: State = State.WANDER

var _wander_dir := Vector2.ZERO
var _wander_timer: float = 0.0


func _ready() -> void:
	super._ready()
	_init_melee_swing()
	_swing.ended.connect(_on_swing_ended)
	_wander_dir = random_wander_direction()
	_wander_timer = randf_range(1.0, 2.5)
	if stats.shares_pack_aggro and not pack_id.is_empty():
		add_to_group(_pack_group_name())


func _physics_process(delta: float) -> void:
	if is_dead():
		return
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
		State.RETURN:
			_process_return()
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
	if is_target_in_range_tiles(stats.melee_range_tiles):
		if PackAggroCoordinator.try_acquire_attack_token(pack_id):
			_start_melee_swing()
		else:
			velocity = Vector2.ZERO  ## 공격 토큰 없음 — 포위 대기(combat.md 2-2)
		return
	velocity = move_toward_point(target.global_position, stats.combat_move_speed_tiles)
	_play_animation("walk", velocity)


func _process_return() -> void:
	if home_position.distance_to(global_position) <= ARRIVAL_TOLERANCE_PX:
		global_position = home_position
		hp = stats.max_hp  ## spec: 귀환 시 HP 완전 회복
		velocity = Vector2.ZERO
		state = State.WANDER
		return
	velocity = move_toward_point(home_position, stats.combat_move_speed_tiles)
	_play_animation("walk", velocity)


func _enter_chase(new_target: Node2D) -> void:
	if is_dead():
		return
	if new_target:
		target = new_target
	state = State.CHASE


func _start_melee_swing() -> void:
	state = State.MELEE_SWING
	_swing.start()
	_play_animation("attack")


func _on_swing_ended() -> void:
	PackAggroCoordinator.release_attack_token(pack_id)
	if is_dead():
		return
	state = State.CHASE  ## spec: 쿨다운 없이 재접근


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
	return "wolf_pack_%s" % pack_id
