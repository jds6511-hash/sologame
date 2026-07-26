## 전사 캐릭터 컨트롤러 (CB-1/CB-2) — 이동, 기본 공격(대검 2타 콤보), 회피 대시, 스킬 슬롯.
##
## 참조: docs/design/systems/combat.md 2~5장, docs/design/systems/m2-warrior-skills.md.
## 데미지 실적용(CB-3)·HP/MP 실체(PlayerStatsComponent)는 이 스크립트의 범위 밖이며,
## 시그널과 공개 상태만 노출해 다른 컴포넌트가 연동한다.
##
## 스킬 슬롯(CB-2)은 기본 공격 콤보와 동일한 히트박스(Facing/AttackHitbox)를 재사용한다 —
## 기본 공격과 스킬은 상호 배타적 행동(하나만 동시에 진행)이므로 히트박스를 공유해도
## 안전하다. 판정이 성립하면 attack_hit(step, target) 시그널에 "현재 판정 주체"(콤보의
## WarriorAttackStep 또는 스킬의 WarriorSkillData)를 그대로 실어 보낸다 — 두 리소스 모두
## damage_coefficient/hitstop_preset 필드를 노출하므로(duck typing) PlayerAttackResolver는
## 콤보인지 스킬인지 구분할 필요 없이 그대로 소비한다.
class_name PlayerController
extends CharacterBody2D

signal dash_started
signal dash_ended
signal attack_step_started(step_index: int, hitstop_preset: String)
## step: WarriorAttackStep(기본 콤보) 또는 WarriorSkillData(스킬) — 둘 다 damage_coefficient/
## hitstop_preset 필드를 노출하는 duck-typing 계약. 타입을 명시하지 않은 이유는 두 클래스
## 모두 받아야 하기 때문이다(스크립트 상단 주석 참조).
signal attack_hit(step, target: Node)
signal skill_used(skill_name: String)
signal player_hit_taken(is_heavy: bool)  ## CB-4: 피격 성립(경직 시작) 알림
signal player_invincibility_started
signal player_invincibility_ended

enum AttackState { NONE, STARTUP, ACTIVE, RECOVERY }

## 회피 대시 시작·플레이어 피격 SFX (SD-1).
const DODGE_SFX := preload("res://assets/audio/sfx/sfx_combat_dodge.wav")
const PLAYER_HIT_SFX := preload("res://assets/audio/sfx/sfx_combat_player_hit.wav")

@export var movement_data: PlayerMovementData
@export var combo_data: WarriorComboData
@export var hit_rules: PlayerHitRules  ## CB-4: combat.md 5-1장 피격 경직/무적 수치

@export_group("스킬 (CB-2, m2-warrior-skills.md 1~5장)")
@export var skill_slot_1: WarriorSkillData  ## 1키 — 강타
@export var skill_slot_2: WarriorSkillData  ## 2키 — 질주
@export var skill_slot_3: WarriorSkillData  ## 3키 — 응급 처치
@export var skill_slot_4: WarriorSkillData  ## 4키 — 분쇄 베기
@export var skill_slot_q: WarriorSkillData  ## Q키 — 돌격
@export var skill_slot_e: WarriorSkillData  ## E키 — 결의의 외침
@export var skill_ultimate: WarriorSkillData  ## R키 — 대지 분쇄(궁극기)
@export var skill_charge: WarriorSkillData  ## 우클릭(홀드) — 차지 강타

var attack_state: AttackState = AttackState.NONE
var skill_state: AttackState = AttackState.NONE
var is_dashing: bool = false
var is_dash_invincible: bool = false
var dash_charges: int = 0
var is_hit_stunned: bool = false  ## CB-4: 피격 경직 중
var is_hit_invincible: bool = false  ## CB-4: 피격 후 무적 중

var active_skill: WarriorSkillData = null

var _move_input := Vector2.ZERO
var _last_move_direction := Vector2.DOWN  ## 대시 기본 방향(이동 입력 없을 시 마지막 방향 유지)
var _attack_step_index: int = -1
var _attack_phase_timer: float = 0.0
var _combo_window_timer: float = 0.0
var _queued_next_attack: bool = false
var _dash_timer: float = 0.0
var _dash_direction := Vector2.DOWN
var _dash_recharge_timers: Array[float] = []
var _hit_stun_timer: float = 0.0
var _hit_invincibility_timer: float = 0.0
var _knockback_velocity := Vector2.ZERO
## 위치 오염 복구용 마지막 유한 좌표 캐시(monster_base의 home_position 역할). 플레이어에는
## 스폰/home 개념이 없어 매 프레임 유한할 때 갱신해 두고, 오염 시 이 값으로 되돌린다.
var _last_finite_position := Vector2.ZERO
## 현재 히트박스 판정을 낸 주체(WarriorAttackStep 또는 WarriorSkillData) — attack_hit emit용.
var _current_action_step = null

var _skill_phase_timer: float = 0.0
var _skill_dash_direction := Vector2.ZERO
var _skill_cooldowns: Dictionary = {}  ## key: String(슬롯 이름) -> 남은 쿨다운(초)

var _is_charging_secondary: bool = false
var _charge_hold_timer: float = 0.0
var _cooldown_secondary: float = 0.0

## 슈퍼아머 — combat.md 5-1 "슈퍼아머 스킬 시전 중: 경직 무시, 무적은 아님(피해는 그대로)".
## 두 출처를 합산한다: ① 시전 중 슈퍼아머(차지 강타·대지 분쇄, self_superarmor_during_cast)
## ② 결의의 외침이 부여하는 시간제 버프(_buff_superarmor_timer).
var _cast_superarmor_active: bool = false
var _buff_superarmor_timer: float = 0.0

@onready var _facing: Node2D = $Facing
@onready var _attack_hitbox: Area2D = $Facing/AttackHitbox
@onready var _attack_collision: CollisionPolygon2D = $Facing/AttackHitbox/CollisionPolygon2D
@onready var _debug_hitbox_visual: Polygon2D = $Facing/DebugHitboxVisual
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _stats: PlayerStatsComponent = get_node_or_null("PlayerStats")


func _ready() -> void:
	dash_charges = movement_data.dash_charge_max
	_last_finite_position = global_position if global_position.is_finite() else Vector2.ZERO
	_attack_hitbox.monitoring = false
	_debug_hitbox_visual.visible = false
	_attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	## 위치가 유한한 동안 마지막 정상 좌표를 캐시해 둔다(오염 복구 기준점). 이미 오염된
	## 프레임에서는 갱신하지 않아 직전 정상값을 보존한다.
	if global_position.is_finite():
		_last_finite_position = global_position

	_move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _move_input.length_squared() > 0.0:
		_last_move_direction = _move_input.normalized()

	_update_dash_recharge(delta)
	_update_hit_reaction(delta)
	_update_superarmor_state(delta)
	_update_skill_cooldowns(delta)

	if is_hit_stunned:
		velocity = _knockback_velocity
		_guard_finite_before_move()
		move_and_slide()
		_update_visual()
		return

	_process_dodge_input()

	if is_dashing:
		_process_dash(delta)
	elif skill_state != AttackState.NONE:
		_process_skill_state(delta)
	elif _is_charging_secondary:
		_process_charge_hold(delta)
	else:
		_process_secondary_charge_start_input()
		_process_skill_slot_input()
		_process_potion_input()
		_process_attack_input()
		_process_attack_state(delta)
		if attack_state == AttackState.NONE:
			velocity = _move_input * movement_data.get_walk_speed_px_per_sec()
			_update_facing_to_mouse()
		else:
			velocity = Vector2.ZERO

	_guard_finite_before_move()
	move_and_slide()
	_update_visual()


# --- 이동/조준 ---


func _update_facing_to_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	if mouse_pos.distance_squared_to(global_position) > 0.01:
		_facing.look_at(mouse_pos)


# --- 기본 공격 콤보 (m2-warrior-skills.md 2장 "대검 2타 콤보") ---


func _process_attack_input() -> void:
	if not Input.is_action_just_pressed("attack"):
		return
	if attack_state == AttackState.NONE:
		_start_attack_step(0)
	elif _combo_window_timer > 0.0 and _attack_step_index < combo_data.steps.size() - 1:
		_queued_next_attack = true


func _start_attack_step(step_index: int) -> void:
	_attack_step_index = step_index
	attack_state = AttackState.STARTUP
	_attack_phase_timer = 0.0
	_combo_window_timer = 0.0
	_queued_next_attack = false
	var step: WarriorAttackStep = combo_data.steps[step_index]
	attack_step_started.emit(step_index, step.hitstop_preset)


func _process_attack_state(delta: float) -> void:
	if attack_state == AttackState.NONE:
		return
	_attack_phase_timer += delta
	var step: WarriorAttackStep = combo_data.steps[_attack_step_index]
	match attack_state:
		AttackState.STARTUP:
			if _attack_phase_timer >= step.startup_sec:
				attack_state = AttackState.ACTIVE
				_attack_phase_timer = 0.0
				_enable_attack_hitbox(step)
		AttackState.ACTIVE:
			if _attack_phase_timer >= step.active_sec:
				attack_state = AttackState.RECOVERY
				_attack_phase_timer = 0.0
				_disable_attack_hitbox()
				_combo_window_timer = combo_data.combo_window_sec
		AttackState.RECOVERY:
			_combo_window_timer = max(_combo_window_timer - delta, 0.0)
			if _attack_phase_timer >= step.recovery_sec:
				if _queued_next_attack and _attack_step_index < combo_data.steps.size() - 1:
					_start_attack_step(_attack_step_index + 1)
				else:
					_end_combo()


func _end_combo() -> void:
	attack_state = AttackState.NONE
	_attack_step_index = -1
	_combo_window_timer = 0.0
	_queued_next_attack = false


## 기본 콤보·스킬 공용 히트박스 활성화. step은 WarriorAttackStep 또는 WarriorSkillData —
## 둘 다 hitbox_range_tiles/hitbox_angle_deg 필드를 노출한다(duck typing).
func _enable_attack_hitbox(step) -> void:
	_current_action_step = step
	## step은 untyped(WarriorAttackStep/WarriorSkillData duck typing)라 곱셈 결과의 정적
	## 타입을 추론할 수 없다 — 명시적으로 float 타입을 지정한다.
	var radius_px: float = step.hitbox_range_tiles * movement_data.tile_size_px
	var angle_deg: float = step.hitbox_angle_deg
	var polygon := _build_sector_polygon(radius_px, angle_deg)
	_attack_collision.polygon = polygon
	_debug_hitbox_visual.polygon = polygon
	_attack_hitbox.monitoring = true
	_debug_hitbox_visual.visible = true


func _disable_attack_hitbox() -> void:
	_attack_hitbox.monitoring = false
	_debug_hitbox_visual.visible = false


## 부채꼴 판정 범위를 근사하는 다각형 생성(로컬 +X가 정면). segments가 클수록 매끄럽다.
func _build_sector_polygon(
	radius_px: float, angle_deg: float, segments: int = 8
) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	var half_angle := deg_to_rad(angle_deg) * 0.5
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var angle := -half_angle + t * (half_angle * 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * radius_px)
	return points


func _on_attack_hitbox_body_entered(body: Node) -> void:
	if body == self:
		return  ## 충돌 레이어로 이미 차단되지만, 이중 안전장치로 자기 자신은 명시적으로 제외한다.
	# 데미지 계산(CB-3)·히트스톱 연출(CB-7)은 이후 태스크 담당 — 여기서는 판정 성립만 알린다.
	attack_hit.emit(_current_action_step, body)


# --- 스킬 슬롯 (CB-2, m2-warrior-skills.md) ---


func _process_skill_slot_input() -> void:
	if Input.is_action_just_pressed("skill_slot_1"):
		_try_use_skill("slot1", skill_slot_1)
	elif Input.is_action_just_pressed("skill_slot_2"):
		_try_use_skill("slot2", skill_slot_2)
	elif Input.is_action_just_pressed("skill_slot_3"):
		_try_use_skill("slot3", skill_slot_3)
	elif Input.is_action_just_pressed("skill_slot_4"):
		_try_use_skill("slot4", skill_slot_4)
	elif Input.is_action_just_pressed("skill_slot_5"):  ## Q(돌격) — ux-foundation 슬롯5 매핑
		_try_use_skill("slot_q", skill_slot_q)
	elif Input.is_action_just_pressed("skill_slot_6"):  ## E(결의의 외침) — 슬롯6 매핑
		_try_use_skill("slot_e", skill_slot_e)
	elif Input.is_action_just_pressed("ultimate"):
		_try_use_skill("ultimate", skill_ultimate)


## 쿨다운·MP를 확인해 스킬 사용을 시도한다. 성공 시 true.
func _try_use_skill(key: String, skill: WarriorSkillData) -> bool:
	if skill == null:
		return false
	if float(_skill_cooldowns.get(key, 0.0)) > 0.0:
		return false
	var mp_cost := _skill_mp_cost(skill)
	if _stats and not _stats.has_mp(mp_cost):
		return false
	if _stats:
		_stats.spend_mp(mp_cost)
	_skill_cooldowns[key] = skill.cooldown_sec
	_start_skill(skill)
	return true


func _skill_mp_cost(skill: WarriorSkillData) -> float:
	if _stats == null or _stats.stats == null:
		return 0.0
	return _stats.stats.max_mp * skill.mp_cost_percent


func _start_skill(skill: WarriorSkillData) -> void:
	active_skill = skill
	skill_state = AttackState.STARTUP
	_skill_phase_timer = 0.0
	skill_used.emit(skill.skill_name)


## 차지 강타처럼 홀드 단계가 이미 시전(startup)을 대신한 경우, ACTIVE부터 바로 시작한다.
func _begin_skill_active(skill: WarriorSkillData) -> void:
	active_skill = skill
	skill_state = AttackState.ACTIVE
	_skill_phase_timer = 0.0
	skill_used.emit(skill.skill_name)
	_activate_skill_effect(skill)


func _process_skill_state(delta: float) -> void:
	_skill_phase_timer += delta
	match skill_state:
		AttackState.STARTUP:
			velocity = Vector2.ZERO
			if _skill_phase_timer >= active_skill.startup_sec:
				skill_state = AttackState.ACTIVE
				_skill_phase_timer = 0.0
				_activate_skill_effect(active_skill)
		AttackState.ACTIVE:
			if active_skill.skill_type == WarriorSkillData.SkillType.DASH:
				## max()는 인자 타입에 따라 가변 반환 타입을 갖는 엔진 내장 함수라 :=로는
				## 정적 타입을 추론할 수 없다 — 명시적으로 float 타입을 지정한다.
				var safe_duration_sec: float = maxf(active_skill.dash_duration_sec, 0.0001)
				var speed_px: float = (
					movement_data.tile_size_px
					* active_skill.dash_distance_tiles
					/ safe_duration_sec
				)
				velocity = _skill_dash_direction * speed_px
			else:
				velocity = Vector2.ZERO
			if _skill_phase_timer >= active_skill.get_active_duration_sec():
				skill_state = AttackState.RECOVERY
				_skill_phase_timer = 0.0
				_deactivate_skill_effect(active_skill)
		AttackState.RECOVERY:
			velocity = Vector2.ZERO
			if _skill_phase_timer >= active_skill.recovery_sec:
				_end_skill()


func _activate_skill_effect(skill: WarriorSkillData) -> void:
	match skill.skill_type:
		WarriorSkillData.SkillType.DASH:
			_skill_dash_direction = _last_move_direction
			if skill.hitbox_range_tiles > 0.0:
				_enable_attack_hitbox(skill)
		WarriorSkillData.SkillType.BUFF_HEAL:
			_apply_self_buff(skill)
		_:  ## INSTANT · CHARGE · ULTIMATE
			if skill.hitbox_range_tiles > 0.0:
				_enable_attack_hitbox(skill)


func _deactivate_skill_effect(_skill: WarriorSkillData) -> void:
	_disable_attack_hitbox()


func _apply_self_buff(skill: WarriorSkillData) -> void:
	if _stats == null:
		return
	if skill.self_heal_percent > 0.0:
		_stats.heal(_stats.stats.max_hp * skill.self_heal_percent)
	if skill.grants_superarmor_sec > 0.0:
		_buff_superarmor_timer = skill.grants_superarmor_sec
	if skill.defense_buff_percent > 0.0:
		_stats.apply_defense_buff(skill.defense_buff_percent, skill.defense_buff_duration_sec)


func _cancel_skill() -> void:
	_disable_attack_hitbox()
	skill_state = AttackState.NONE
	active_skill = null


func _end_skill() -> void:
	skill_state = AttackState.NONE
	active_skill = null


func _update_skill_cooldowns(delta: float) -> void:
	for key in _skill_cooldowns.keys():
		if _skill_cooldowns[key] > 0.0:
			_skill_cooldowns[key] = max(_skill_cooldowns[key] - delta, 0.0)
	if _cooldown_secondary > 0.0:
		_cooldown_secondary = max(_cooldown_secondary - delta, 0.0)


func get_skill_cooldown_remaining(key: String) -> float:
	return float(_skill_cooldowns.get(key, 0.0))


# --- 차지 강타 (우클릭 홀드, m2-warrior-skills.md 3장) ---


func _process_secondary_charge_start_input() -> void:
	if not Input.is_action_just_pressed("skill_secondary"):
		return
	if skill_charge == null or _cooldown_secondary > 0.0:
		return
	if _stats and not _stats.has_mp(_skill_mp_cost(skill_charge)):
		return
	_is_charging_secondary = true
	_charge_hold_timer = 0.0


## 이동 시 취소(combat.md 3장 "캐스팅 스킬은 이동 시 취소") — 이동 자체는 막지 않는다.
func _process_charge_hold(delta: float) -> void:
	if _move_input.length_squared() > 0.0:
		_cancel_charge()
		velocity = _move_input * movement_data.get_walk_speed_px_per_sec()
		_update_facing_to_mouse()
		return

	velocity = Vector2.ZERO
	_charge_hold_timer = min(_charge_hold_timer + delta, skill_charge.charge_max_hold_sec)
	if (
		not Input.is_action_pressed("skill_secondary")
		or _charge_hold_timer >= skill_charge.charge_max_hold_sec
	):
		_release_charge()


func _cancel_charge() -> void:
	_is_charging_secondary = false
	_charge_hold_timer = 0.0


func _release_charge() -> void:
	_is_charging_secondary = false
	if _charge_hold_timer < skill_charge.charge_min_hold_sec:
		return  ## 최소 홀드 이전에 뗌 — 취소(비용 없음)

	var ratio := clampf(
		inverse_lerp(
			skill_charge.charge_min_hold_sec, skill_charge.charge_max_hold_sec, _charge_hold_timer
		),
		0.0,
		1.0
	)
	var mp_cost := _skill_mp_cost(skill_charge)
	if _stats and not _stats.has_mp(mp_cost):
		return
	if _stats:
		_stats.spend_mp(mp_cost)
	_cooldown_secondary = skill_charge.cooldown_sec
	## 차지 강타는 홀드 비율에 따라 계수·후딜이 달라진다(m2-warrior-skills.md 3장) — 공용
	## 리소스 필드를 이번 사용 값으로 덮어써 재사용한다(항상 사용 직전에 다시 계산되므로
	## 이전 값이 남는 부작용 없음).
	skill_charge.damage_coefficient = lerp(
		skill_charge.charge_min_coefficient, skill_charge.charge_max_coefficient, ratio
	)
	skill_charge.recovery_sec = lerp(
		skill_charge.charge_min_recovery_sec, skill_charge.charge_max_recovery_sec, ratio
	)
	_begin_skill_active(skill_charge)


# --- 포션 (CB-5, combat.md 5-4장) ---


func _process_potion_input() -> void:
	if Input.is_action_just_pressed("quickslot_1") and _stats:
		_stats.use_potion()


# --- 피격 반응 (CB-4, combat.md 5-1장) ---


## 몬스터 등 공격자가 판정 성립 시 호출하는 공개 API.
## is_heavy: 강공격/보스 공격 여부(넉다운). knockback_direction: 밀려나는 방향(정규화 불필요).
## 무적 중(회피 무적 포함)이거나 슈퍼아머 중에는 무시한다 — 데미지 적용 여부는 호출자가
## 이 함수 호출 전에 is_invincible()로 먼저 확인해야 한다(경직/무적 갱신과 데미지 적용을
## 분리). 슈퍼아머는 "경직 무시, 피해는 그대로"이므로 데미지(take_damage)는 별도로 계속
## 정상 적용된다 — 여기서 무시하는 것은 경직·넉백 반응뿐이다.
func take_hit(is_heavy: bool, knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_invincible():
		return
	if is_superarmor():
		return
	if is_dashing:
		is_dashing = false
		is_dash_invincible = false
	if attack_state != AttackState.NONE:
		_disable_attack_hitbox()
		_end_combo()
	if skill_state != AttackState.NONE:
		_cancel_skill()

	is_hit_stunned = true
	is_hit_invincible = true
	_hit_stun_timer = hit_rules.heavy_knockdown_sec if is_heavy else hit_rules.light_stun_sec
	_hit_invincibility_timer = (
		hit_rules.heavy_invincibility_sec if is_heavy else hit_rules.light_invincibility_sec
	)

	## 넉백 소(0.5타일)는 "일반 피격"에만 명시되어 있다(combat.md 5-1장) — 넉다운(강공격)은
	## 넉백 거리 수치가 없어 밀려나지 않는다(경직/무적 타이머만 적용).
	## _hit_stun_timer가 0 이하면(경직 시간 0 설정 등) 나눗셈이 Infinity/NaN을 만들고,
	## knockback_direction 자체가 이미 NaN 등으로 오염되어 있으면(공격자 쪽 좌표 오염 등)
	## `!= Vector2.ZERO` 비교를 그대로 통과해 normalized()가 "Vector2 cannot be normalized"
	## 경고를 반복시킨다(2026-07-18 경고 스팸 수정) — monster_base.gd의 넉백 가드와
	## 동일하게 둘 다 확인한다.
	if (
		not is_heavy
		and knockback_direction != Vector2.ZERO
		and knockback_direction.is_finite()
		and _hit_stun_timer > 0.0
	):
		var distance_px := hit_rules.light_knockback_tiles * movement_data.tile_size_px
		_knockback_velocity = knockback_direction.normalized() * (distance_px / _hit_stun_timer)
	else:
		_knockback_velocity = Vector2.ZERO

	player_hit_taken.emit(is_heavy)
	player_invincibility_started.emit()
	HitFeedback.play_sfx(PLAYER_HIT_SFX, global_position)


## 몬스터 등 공격자가 실제 HP 피해를 적용할 때 호출하는 공개 API(MonsterAttackResolver
## 연동 지점) — HP 차감·사망(임시 리스폰) 자체는 PlayerStats 컴포넌트가 담당한다.
func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	if _stats:
		_stats.take_damage(amount, hit_grade, attacker)


## PlayerAttackResolver 등 공격자 쪽이 조회하는 방어력 duck-typing 계약.
func get_combat_defense() -> float:
	return _stats.get_combat_defense() if _stats else 0.0


func is_dead() -> bool:
	return _stats.is_dead() if _stats else false


## 회피 무적(대시)과 피격 후 무적을 합친 통합 판정 — 공격자 쪽이 데미지 적용 전 확인용.
func is_invincible() -> bool:
	return is_dash_invincible or is_hit_invincible


## 슈퍼아머 — 경직은 무시하지만 무적은 아니다(피해는 그대로 받는다, combat.md 5-1장).
func is_superarmor() -> bool:
	return _cast_superarmor_active or _buff_superarmor_timer > 0.0


func _update_superarmor_state(delta: float) -> void:
	_cast_superarmor_active = (
		skill_state != AttackState.NONE
		and skill_state != AttackState.RECOVERY
		and active_skill != null
		and active_skill.self_superarmor_during_cast
	)
	if _buff_superarmor_timer > 0.0:
		_buff_superarmor_timer = max(_buff_superarmor_timer - delta, 0.0)


## move_and_slide() 직전 트랜스폼·속도 유한성 가드 — monster_base.gd의
## _guard_finite_before_move()와 동일한 근본 수정(2026-07-26 경고 스팸).
##
## CharacterBody2D.global_position이 한번 non-finite(NaN/Inf)가 되면 그 이후
## move_and_slide()는 velocity가 (0,0)이어도 매 프레임 충돌 법선을 normalize하며
## "Vector2 cannot be normalized" 경고를 무한 반복한다 — 위치는 스스로 낫지 않으므로
## velocity만 ZERO로 눌러선 잡히지 않는다. 따라서 velocity뿐 아니라 global_position
## 자체의 유한성을 확인해, 오염 시 마지막 유한 좌표로 복구한다(플레이어는 home이 없어
## _last_finite_position을 기준점으로 쓴다).
func _guard_finite_before_move() -> void:
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	if not global_position.is_finite():
		global_position = (
			_last_finite_position if _last_finite_position.is_finite() else Vector2.ZERO
		)
		velocity = Vector2.ZERO


func _update_hit_reaction(delta: float) -> void:
	if is_hit_stunned:
		_hit_stun_timer -= delta
		if _hit_stun_timer <= 0.0:
			is_hit_stunned = false
			_knockback_velocity = Vector2.ZERO
	if is_hit_invincible:
		_hit_invincibility_timer -= delta
		if _hit_invincibility_timer <= 0.0:
			is_hit_invincible = false
			player_invincibility_ended.emit()


# --- 회피 대시 (combat.md 4장) ---


func _process_dodge_input() -> void:
	if not Input.is_action_just_pressed("dodge"):
		return
	if is_dashing or dash_charges <= 0:
		return
	_start_dash()


func _start_dash() -> void:
	if attack_state != AttackState.NONE:
		_disable_attack_hitbox()
		_end_combo()
	if skill_state != AttackState.NONE:
		_cancel_skill()
	dash_charges -= 1
	_dash_recharge_timers.append(movement_data.dash_recharge_sec)
	_dash_direction = _last_move_direction
	is_dashing = true
	is_dash_invincible = false
	_dash_timer = 0.0
	dash_started.emit()
	HitFeedback.play_sfx(DODGE_SFX, global_position)


func _process_dash(delta: float) -> void:
	_dash_timer += delta
	is_dash_invincible = (
		_dash_timer >= movement_data.dash_invincibility_start_sec
		and _dash_timer <= movement_data.get_dash_invincibility_end_sec()
	)
	if _dash_timer >= movement_data.dash_duration_sec:
		is_dashing = false
		is_dash_invincible = false
		velocity = Vector2.ZERO
		dash_ended.emit()
		return
	velocity = _dash_direction * movement_data.get_dash_speed_px_per_sec()


func _update_dash_recharge(delta: float) -> void:
	for i in range(_dash_recharge_timers.size() - 1, -1, -1):
		_dash_recharge_timers[i] -= delta
		if _dash_recharge_timers[i] <= 0.0:
			_dash_recharge_timers.remove_at(i)
			dash_charges = mini(dash_charges + 1, movement_data.dash_charge_max)


# --- 비주얼(애니메이션) 갱신 — pixel-artist AR-1 신규 스프라이트(16x32, 3방향) 배선 ---
# 시트는 idle/walk/attack/hit/death 각각 정면(front)/측면(side)/후면(back) 3방향으로
# 구성되어 있다(STYLE_GUIDE.md 3-3장). 좌우는 별도 프레임 없이 측면 애니메이션의
# flip_h로 근사한다(문서 "좌우는 미러 허용" 원칙).


## 현재 재생해야 할 상태(동작) 이름 — 애니메이션 이름의 앞부분(예: "walk")이 된다.
func _current_action_name() -> String:
	if is_dead():
		return "death"
	if is_hit_stunned:
		return "hit"
	if (
		attack_state != AttackState.NONE
		or skill_state != AttackState.NONE
		or _is_charging_secondary
	):
		return "attack"
	if _move_input.length_squared() > 0.0:
		return "walk"
	return "idle"


## 애니메이션 방향 판정에 쓸 기준 벡터. 공격/스킬 중에는 Facing 노드가 이미 마우스를
## 조준한 각도로 고정돼 있으므로(공격 시작 시점 이후 갱신되지 않음, _physics_process
## 참고) 그 각도를 그대로 쓰고, 그 외에는 이동 입력(없으면 마지막 이동 방향)을 쓴다.
func _current_facing_vector() -> Vector2:
	if (
		attack_state != AttackState.NONE
		or skill_state != AttackState.NONE
		or _is_charging_secondary
	):
		return Vector2.RIGHT.rotated(_facing.rotation)
	if _move_input.length_squared() > 0.0:
		return _move_input
	return _last_move_direction


## 방향 벡터를 3방향 시트 행 이름으로 근사한다 — 상하 성분이 더 크면 정면/후면,
## 아니면 측면(좌우는 flip_h로 구분).
func _facing_suffix(direction: Vector2) -> String:
	if direction == Vector2.ZERO:
		return "front"
	if absf(direction.y) >= absf(direction.x):
		return "back" if direction.y < 0.0 else "front"
	return "side"


func _update_visual() -> void:
	if not _sprite or not _sprite.sprite_frames:
		return
	var direction := _current_facing_vector()
	var suffix := _facing_suffix(direction)
	_sprite.flip_h = suffix == "side" and direction.x < 0.0
	var anim_name := "%s_%s" % [_current_action_name(), suffix]
	if _sprite.sprite_frames.has_animation(anim_name) and _sprite.animation != anim_name:
		_sprite.play(anim_name)


# --- 디버그 HUD 연동용 상태 조회 ---


func get_debug_state_text() -> String:
	var text := "대기"
	if _move_input.length_squared() > 0.0:
		text = "이동"
	match attack_state:
		AttackState.STARTUP:
			text = "공격 %d타 - 선딜" % (_attack_step_index + 1)
		AttackState.ACTIVE:
			text = "공격 %d타 - 판정" % (_attack_step_index + 1)
		AttackState.RECOVERY:
			text = "공격 %d타 - 후딜" % (_attack_step_index + 1)
	if skill_state != AttackState.NONE and active_skill:
		text = "스킬: %s%s" % [active_skill.skill_name, " (슈퍼아머)" if is_superarmor() else ""]
	if _is_charging_secondary:
		text = "차지 강타 홀드 중 (%.2fs)" % _charge_hold_timer
	if is_dashing:
		text = "회피 대시%s" % (" (무적)" if is_dash_invincible else "")
	if is_hit_stunned:
		text = "피격 경직%s" % (" (무적)" if is_hit_invincible else "")
	return text
