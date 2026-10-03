## 궁수 원거리 사격 모듈 (M3 C-5) — m3-archer-skills.md 4·5·6장.
##
## PlayerController에서 "원거리 전용" 상태만 떼어낸 헬퍼다. 담당 범위는 셋:
##   ① 조준 모드 스탠스(우클릭 홀드 — 이동 페널티·사격 사이클·관통 정밀 화살 교체, 5장)
##   ② 화살 발사 큐(속사 3연사 0.08초 간격을 포함한 투사체 스폰, 4-1·6장)
##   ③ 궁수 자기 버프 가산치(매의 눈 — 치명타·사거리·공격 속도, 4-3장)
##
## 컨트롤러의 판정 상태머신(선딜/판정/후딜·히트박스)은 근접과 공유하므로 그쪽에 남기고,
## 여기서는 "무엇을 어느 방향으로 몇 발 쏘는가"만 관리한다. RefCounted로 두어 씬 구조를
## 바꾸지 않고 컨트롤러가 내부에서 생성한다(밸런스 수치는 전부 ArrowSpec/ArcherSkillData
## .tres에 있으므로 씬에 노출할 @export가 없다).
class_name ArcherShotModule
extends RefCounted

## 발사한 화살이 명중했을 때 발신 — 컨트롤러가 attack_hit으로 중계해 PlayerAttackResolver가
## 계수·강화 배율·치명타·방어 감산·히트피드백을 처리한다(6-2장 델타 ②③).
signal arrow_hit_landed(action: Resource, body: Node)

const ARROW_SCENE := preload("res://scenes/player/arrow_projectile.tscn")
const FOCUS_MODEL := preload("res://scripts/player/sharpshooter_focus.gd")
const SHARPSHOOTER_SKILL := preload("res://scripts/player/sharpshooter_skill_data.gd")

var focus := FOCUS_MODEL.new()
var focus_enabled := false

## 우클릭 슬롯이 조준 스탠스인 경우 그 데이터, 아니면 null(전사 차지 강타 경로 유지).
var aim_stance: ArcherSkillData = null
var is_aiming: bool = false  ## 조준 모드 활성(우클릭 홀드 중)

## 매의 눈이 부여한 가산치 — 지속시간이 끝나면 0으로 되돌아간다.
var crit_chance_bonus: float = 0.0
var attack_range_bonus_tiles: float = 0.0
var attack_speed_bonus: float = 0.0

var _burst_cast_id := -1
var _burst_count := 0
var _burst_index := 0
var _resolving_cast_id := -1
var _resolving_projectile_index := -1
var _buff_timer: float = 0.0
var _burst_remaining: int = 0
var _burst_timer: float = 0.0
var _burst_interval: float = 0.0
var _burst_spec: ArrowSpec = null
var _burst_action: Resource = null
var _burst_direction := Vector2.RIGHT
## 화살 스폰 기준(플레이어) — 좌표와 씬 트리 접근에 쓴다.
var _shooter: Node2D = null
var _tile_size_px: float = 16.0


func save_block_reason() -> String:
	if is_aiming or _burst_remaining > 0:
		return "action_in_progress"
	return "cooldown_or_buff" if _buff_timer > 0.0 or focus.breathing_remaining > 0.0 else ""


func set_focus_enabled(enabled: bool) -> void:
	if enabled != focus_enabled:
		reset_focus()
	focus_enabled = enabled


func reset_focus() -> void:
	cancel_burst()
	focus.reset()
	_resolving_cast_id = -1
	_resolving_projectile_index = -1


## attack_hit의 동기 피해 판정 안에서 실제 HP 감소를 확인한 리졸버만 호출한다.
func confirm_valid_damage() -> void:
	if focus_enabled and _resolving_cast_id >= 0:
		focus.landed(_resolving_cast_id, _resolving_projectile_index)


func setup(shooter: Node2D, tile_size_px: float) -> void:
	_shooter = shooter
	_tile_size_px = tile_size_px


# --- 조준 모드 스탠스 (5장) ---


## 우클릭 슬롯이 궁수 조준 스탠스인지 판정해 캐시한다(전직 로드아웃 교체 시마다 호출).
func refresh_stance(secondary_slot: WarriorSkillData) -> void:
	var stance := secondary_slot as ArcherSkillData
	aim_stance = stance if stance != null and stance.is_aim_stance else null
	is_aiming = false


## 조준 모드는 홀드 중에만 활성이고 떼면 즉시 해제된다(MP 없음, 슈퍼아머 없음 — 비용은
## 이동 페널티와 무방비라는 포지셔닝 리스크로 지불한다).
func update_stance() -> void:
	is_aiming = aim_stance != null and Input.is_action_pressed("skill_secondary")


## 조준 중 이동 속도 배율(×0.4). 조준 중이 아니면 1.0.
func move_speed_multiplier() -> float:
	if is_aiming and aim_stance != null:
		if focus_enabled and focus.breathing_remaining > 0.0:
			return 0.8
		return aim_stance.aim_move_speed_multiplier
	return 1.0


## 기본 공격 진행 속도 배율. 매의 눈 공격 속도 +15%(4-3장)와 조준 모드 사격 사이클
## 0.65초(5장)를 함께 반영한다 — 콤보 규격이 정한 총 모션 시간(base_cycle_sec)과 목표
## 사이클의 비로 계산해 규격 수치를 코드에 중복하지 않는다.
func attack_rate(base_cycle_sec: float) -> float:
	var rate := 1.0 + attack_speed_bonus
	if (
		is_aiming
		and aim_stance != null
		and aim_stance.aim_shot_cycle_sec > 0.0
		and base_cycle_sec > 0.0
	):
		rate *= base_cycle_sec / aim_stance.aim_shot_cycle_sec
	return rate


# --- 자기 버프 (매의 눈, 4-3장) ---


## 궁수 전용 가산치를 주는 버프를 적용한다. mult는 스킬 강화 배율(+8%/레벨)이며,
## 궁수 버프가 아니면(다른 직업의 버프·힐) 아무것도 하지 않는다.
func apply_buff(skill: ArcherSkillData, mult: float) -> void:
	if skill is SHARPSHOOTER_SKILL and skill.grants_breathing:
		if focus_enabled:
			focus.start_breathing()
		return
	if skill == null or skill.buff_duration_sec <= 0.0:
		return
	_buff_timer = skill.buff_duration_sec * mult
	crit_chance_bonus = skill.crit_chance_bonus * mult
	attack_range_bonus_tiles = skill.attack_range_bonus_tiles * mult
	attack_speed_bonus = skill.attack_speed_bonus_percent * mult


# --- 화살 발사 (4-1·6장) ---


## 이 판정 주체가 발사할 화살 규격(없으면 null → 근접 판정 스킬). 조준 모드 중의 기본
## 공격은 관통·장사거리 정밀 화살로 대체된다(5장).
func arrow_spec_for(action: Resource) -> ArrowSpec:
	if action is ArcherAttackStep:
		if is_aiming and aim_stance != null and aim_stance.aimed_arrow != null:
			return aim_stance.aimed_arrow
		return (action as ArcherAttackStep).arrow
	if action is ArcherSkillData:
		return (action as ArcherSkillData).arrow
	return null


## 매의 눈 가산을 반영한 실제 사거리(타일).
func effective_range_tiles(spec: ArrowSpec) -> float:
	return spec.range_tiles + attack_range_bonus_tiles


## 발사를 시작한다 — 1발째는 즉시, 나머지는 연사 간격마다(속사 3발 0.08초 간격).
func can_fire(action: Resource, spec: ArrowSpec, direction: Vector2) -> bool:
	if spec == null or not is_instance_valid(_shooter) or not _shooter.is_inside_tree():
		return false
	if not direction.is_finite() or direction.length_squared() <= 0.0001:
		return false
	var distance := effective_range_tiles(spec) * _tile_size_px
	var speed := spec.speed_px_per_sec(_tile_size_px)
	if not is_finite(distance) or distance <= 0.0 or not is_finite(speed) or speed <= 0.0:
		return false
	if action is SHARPSHOOTER_SKILL and action.focus_cost > 0:
		return focus_enabled and focus.value >= float(action.focus_cost)
	return true


func fire(action: Resource, spec: ArrowSpec, direction: Vector2) -> bool:
	if not can_fire(action, spec, direction):
		return false
	cancel_burst()
	var count := 1
	var interval := 0.0
	var archer_skill := action as ArcherSkillData
	if archer_skill != null:
		count = maxi(archer_skill.projectile_count, 1)
		interval = archer_skill.projectile_interval_sec
	_burst_action = action
	_burst_spec = spec
	_burst_direction = direction
	_burst_remaining = count
	_burst_count = count
	_burst_index = 0
	_burst_interval = interval
	_burst_timer = 0.0
	return _fire_one()


## 매 프레임 호출 — 버프 지속시간과 연사 큐를 진행한다. 연사는 스킬 상태와 무관하게
## 큐가 남아 있으면 계속 쏘므로 후딜 진입 후에도 예정 발수가 보장된다(중단은 cancel_burst).
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if focus_enabled:
		focus.advance(delta)
	if _buff_timer > 0.0:
		_buff_timer = maxf(_buff_timer - delta, 0.0)
		if _buff_timer <= 0.0:
			crit_chance_bonus = 0.0
			attack_range_bonus_tiles = 0.0
			attack_speed_bonus = 0.0
	if _burst_remaining <= 0:
		return
	_burst_timer -= delta
	while _burst_remaining > 0 and _burst_timer <= 0.0:
		_fire_one()


## 남은 연사를 취소한다(피격 경직·전직 로드아웃 교체 시).
func cancel_burst() -> void:
	if _burst_cast_id >= 0:
		focus.cancel_unspawned(_burst_cast_id, _burst_index)
	_burst_remaining = 0
	_burst_timer = 0.0
	_burst_action = null
	_burst_spec = null
	_burst_cast_id = -1


func _fire_one() -> bool:
	if not can_fire(_burst_action, _burst_spec, _burst_direction):
		cancel_burst()
		return false
	var arrow := _spawn_arrow(_burst_action, _burst_spec, _burst_direction)
	if arrow == null:
		cancel_burst()
		return false
	if focus_enabled and _burst_index == 0:
		var cap := 15
		if _burst_action is SHARPSHOOTER_SKILL:
			cap = _burst_action.focus_charge_cap
			if _burst_action.focus_cost > 0 and not focus.spend():
				arrow.queue_free()
				cancel_burst()
				return false
		_burst_cast_id = focus.begin_cast(_burst_count, cap)
	var cast_id := _burst_cast_id
	var index := _burst_index
	arrow.arrow_hit_landed.connect(_on_arrow_hit_landed.bind(cast_id, index))
	if cast_id >= 0:
		arrow.flight_ended.connect(focus.end.bind(cast_id, index))
	arrow.launch(_burst_direction, effective_range_tiles(_burst_spec) * _tile_size_px)
	_burst_remaining -= 1
	_burst_index += 1
	_burst_timer += _burst_interval
	if _burst_remaining <= 0:
		cancel_burst()
	return true


## 화살 1발을 플레이어와 같은 필드에 스폰한다. 플레이어 이동과 독립적이며
## 필드가 제거되면 날아가는 화살도 함께 종료된다.
func _spawn_arrow(action: Resource, spec: ArrowSpec, _direction: Vector2) -> ArrowProjectile:
	if spec == null or _shooter == null or not _shooter.is_inside_tree():
		return null
	var arrow := ARROW_SCENE.instantiate() as ArrowProjectile
	# 플레이어와 같은 필드에 두어 필드 교체가 투사체 수명도 종료한다.
	_shooter.get_parent().add_child(arrow)
	arrow.global_position = shot_origin()
	arrow.configure(action, spec, _tile_size_px)
	return arrow


func _on_arrow_hit_landed(
	action: Resource, body: Node, cast_id: int = -1, projectile_index: int = -1
) -> void:
	var previous_cast := _resolving_cast_id
	var previous_index := _resolving_projectile_index
	_resolving_cast_id = cast_id
	_resolving_projectile_index = projectile_index
	arrow_hit_landed.emit(action, body)
	_resolving_cast_id = previous_cast
	_resolving_projectile_index = previous_index


## 발밑 대신 몸 중심에서 커서를 향한다. 근접 적의 발로 방향을 스냅하지 않는다.
func shot_origin() -> Vector2:
	var body := _shooter.get_node_or_null("CollisionShape2D") as Node2D
	return body.global_position if body != null else _shooter.global_position


func aim_direction(cursor: Vector2) -> Vector2:
	var offset := cursor - shot_origin()
	if offset.length_squared() > 0.01:
		return offset.normalized()
	var facing := _shooter.get_node_or_null("Facing") as Node2D
	return Vector2.RIGHT.rotated(facing.global_rotation) if facing != null else Vector2.RIGHT
