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
##
## 원거리(궁수, M3 C-4/C-5 · m3-archer-skills.md)도 같은 파이프라인을 쓴다: 판정 주체가
## ArcherAttackStep/ArcherSkillData이고 arrow(ArrowSpec)를 들고 있으면 부채꼴 히트박스 대신
## ArrowProjectile을 발사하고, 화살이 명중하면 그 판정 주체를 그대로 attack_hit에 실어
## 보낸다 — 근접/원거리 어느 쪽이든 리졸버 쪽 계약은 동일하다. 무기·회피·우클릭 동작 차이는
## 전부 데이터(전직 로드아웃)로 갈린다: 활 콤보(dodge_backward=true) → 후방 점프 회피,
## 우클릭 슬롯이 조준 스탠스(ArcherSkillData.is_aim_stance) → 차지 대신 조준 모드.
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

## 공격 편의(QoL) 튜닝 상수 — 디렉터 지시 4종(홀드 연타/자동 조준/재조준/이동 허용).
## 밸런스에 직접 영향을 주므로 하드코딩하지 않고 상수로 노출한다(combat.md 조작/QoL 절
## 갱신 필요, systems-designer 재검토 대상).
const AUTO_AIM_CONE_HALF_DEG := 35.0  ## 마우스 방향 기준 ±35° 안의 적만 자동 조준 스냅 대상
const AUTO_AIM_RANGE_TILES := 3.0  ## 자동 조준 스냅을 허용하는 최대 거리(타일)
## 공격 중 이동 속도 배율(평소의 45%). combat.md "정지 스윙 전제" 설계와 상충 가능 —
## 이 계수 조정으로 밸런스 재조율 가능하게 분리했다.
const ATTACK_MOVE_SPEED_MULTIPLIER := 0.45
const MONSTER_GROUP := "monsters"  ## 자동 조준 후보 우선 탐색 그룹

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

## 검투사 분노 게이지(충전·격노·감쇠·처형 일격 소모) 담당 모듈 — 검투사 로드아웃이 적용된
## 동안에만 활성이다(scripts/player/player_rage_module.gd). HUD가 게이지 시그널을 구독하므로
## 공개 상태로 둔다.
var rage := PlayerRageModule.new()

## 애니메이션 이름 결정·재생·직업 시트 교체 담당 모듈(scripts/player/player_visual_module.gd).
## 전직(PlayerJobTransition)이 직업 시트를 직접 넣으므로 rage와 같이 공개 상태로 둔다.
var visual := PlayerVisualModule.new()

var _move_input := Vector2.ZERO
var _last_move_direction := Vector2.DOWN  ## 대시 기본 방향(이동 입력 없을 시 마지막 방향 유지)
var _attack_step_index: int = -1
## 다음 _update_visual에서 공격 애니메이션을 프레임0부터 강제 재생하라는 1회성 요청.
## 각 스윙(공격 스텝 진입) 시 켜서, 콤보 내내 anim_name이 "attack_*"로 고정돼도 스윙마다
## 애니메이션이 프레임0부터 다시 재생되게 한다(재시작 가드 우회, 스윙 모션 표시 보장).
var _attack_anim_restart_requested: bool = false
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
## 자동 조준 후보 캐시(스윙 시작 시 1회 수집, 스윙 동안 재사용) — 스냅/재조준 공용.
var _aim_candidates: Array = []

## 스킬 슬롯 시전(입력·MP/쿨다운 게이트·선딜/판정/후딜 상태머신·쿨다운 장부) 담당 모듈
## (scripts/player/player_skill_module.gd). 공개 상태인 skill_state·active_skill은 컨트롤러에
## 남겨 두고 이 모듈이 갱신한다.
var _skills := PlayerSkillModule.new()

var _is_charging_secondary: bool = false
var _charge_hold_timer: float = 0.0

## 궁수 원거리 사격(조준 스탠스·화살 발사·매의 눈 가산) 담당 모듈 — 원거리 전용 상태를
## 이 컨트롤러에서 분리했다(scripts/player/archer_shot_module.gd).
var _shots := ArcherShotModule.new()

## 이동 둔화 디버프(숲거미 거미줄 등) — 남은 지속시간과 감소 비율.
var _move_slow_percent: float = 0.0
var _move_slow_timer: float = 0.0

## 슈퍼아머 — combat.md 5-1 "슈퍼아머 스킬 시전 중: 경직 무시, 무적은 아님(피해는 그대로)".
## 두 출처를 합산한다: ① 시전 중 슈퍼아머(차지 강타·대지 분쇄, self_superarmor_during_cast)
## ② 결의의 외침이 부여하는 시간제 버프(_buff_superarmor_timer).
var _cast_superarmor_active: bool = false
var _buff_superarmor_timer: float = 0.0

@onready var _facing: Node2D = $Facing
@onready var _attack_hitbox: Area2D = $Facing/AttackHitbox
@onready var _attack_collision: CollisionPolygon2D = $Facing/AttackHitbox/CollisionPolygon2D
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _stats: PlayerStatsComponent = get_node_or_null("PlayerStats")
## 스킬 강화 배율 반영용(M3 B-3) — 버프·힐 효과 수치에 +8%/레벨을 곱한다(spec 6-2).
## 노드가 없는 씬/테스트에서는 null → 배율 1.0(하위 호환).
@onready var _skill_points: PlayerSkillPoints = get_node_or_null("PlayerSkillPoints")


func _ready() -> void:
	dash_charges = movement_data.dash_charge_max
	_last_finite_position = global_position if global_position.is_finite() else Vector2.ZERO
	_attack_hitbox.monitoring = false
	_attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	_shots.setup(self, movement_data.tile_size_px)
	_shots.arrow_hit_landed.connect(_on_arrow_hit_landed)
	_shots.refresh_stance(skill_charge)
	_skills.setup(self)
	visual.setup(self, _sprite, _shots)


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
	_update_move_slow(delta)
	_shots.update_stance()
	_shots.advance(delta)
	rage.advance(delta)

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
		_skills.process_slot_input()
		_process_potion_input()
		_process_attack_input()
		_process_attack_state(delta)
		if attack_state == AttackState.NONE:
			velocity = _move_input * _resolve_move_speed_px(false)
			_update_facing_to_mouse()
		else:
			## QoL④ 공격 중 이동 허용(속도 페널티) — 기본 공격 콤보 한정. 스킬/차지는
			## _process_skill_state·_process_charge_hold에서 정지·이동취소를 그대로 유지한다
			## (combat.md 3장 "캐스팅 스킬은 이동 시 취소" 규칙 불변).
			velocity = _move_input * _resolve_move_speed_px(true)
			## QoL③ 스윙 중 재조준 — 판정 발생(ACTIVE) 전 STARTUP까지만 방향을 갱신하고,
			## ACTIVE 진입 이후에는 고정한다(맞추는 각도가 판정 도중 바뀌지 않게).
			if attack_state == AttackState.STARTUP:
				_apply_attack_aim()

	_guard_finite_before_move()
	move_and_slide()
	_update_visual()


# --- 이동/조준 ---


func _update_facing_to_mouse() -> void:
	var mouse_pos := get_global_mouse_position()
	if mouse_pos.distance_squared_to(global_position) > 0.01:
		_facing.look_at(mouse_pos)


## 현재 상태의 최종 이동 속도(px/초).
##
## 조준 모드(궁수 우클릭 스탠스, m3-archer-skills 5장)는 자체 페널티(×0.4)가 공격 중 이동
## 페널티(×0.45)를 대체한다 — 두 페널티를 곱하면 ×0.18로 사실상 정지가 되어 "느리지만
## 멈추지는 않음" 규격에서 벗어나기 때문이다. 둔화 디버프는 그 위에 곱해진다.
## 조준 중이 아니고 둔화도 없으면 기존 전사 동작과 동일하다.
func _resolve_move_speed_px(is_attacking: bool) -> float:
	var speed := movement_data.get_walk_speed_px_per_sec() * (1.0 - _move_slow_percent)
	var aim_multiplier := _shots.move_speed_multiplier()
	if aim_multiplier < 1.0:
		return speed * aim_multiplier
	if is_attacking:
		return speed * ATTACK_MOVE_SPEED_MULTIPLIER
	return speed


## 몬스터(숲거미 거미줄 등)가 호출하는 이동 둔화 공개 API — 걷기 속도를 percent 비율만큼
## duration_sec초 동안 낮춘다. 중첩은 "더 강한 값·더 긴 지속으로 갱신"(포효 버프와 동일
## 규약)이라 각각 최대값을 취한다. 회피 대시는 무적 이동기라 둔화 대상이 아니다.
func apply_move_speed_slow(percent: float, duration_sec: float) -> void:
	if percent <= 0.0 or duration_sec <= 0.0:
		return
	_move_slow_percent = maxf(_move_slow_percent, clampf(percent, 0.0, 1.0))
	_move_slow_timer = maxf(_move_slow_timer, duration_sec)


func _update_move_slow(delta: float) -> void:
	if _move_slow_timer <= 0.0:
		return
	_move_slow_timer = maxf(_move_slow_timer - delta, 0.0)
	if _move_slow_timer <= 0.0:
		_move_slow_percent = 0.0


# --- 자동 조준 보정(QoL②) · 스윙 중 재조준(QoL③) ---


## 스윙 STARTUP 동안 매 프레임 호출된다 — 마우스 방향 기준 자동 조준 대상이 있으면 그
## 적으로, 없으면 순수 마우스 방향으로 Facing을 갱신한다.
##
## range_tiles는 자동 조준 스냅을 허용하는 최대 거리다. 근접 스윙은 기본값(3타일)을 쓰고,
## 원거리 사격은 그 화살의 유효 사거리를 넘겨 사거리 전체에서 스냅이 걸리게 한다
## (m3-archer-skills 4-1장 "3발은 자동 조준 대상에 집속").
func _apply_attack_aim(range_tiles: float = AUTO_AIM_RANGE_TILES) -> void:
	var aim_pos := _resolve_aim_position(range_tiles)
	if aim_pos.distance_squared_to(global_position) > 0.01:
		_facing.look_at(aim_pos)


## 조준이 향할 월드 좌표 — 자동 조준 대상이 있으면 그 위치, 없으면 마우스 위치.
func _resolve_aim_position(range_tiles: float = AUTO_AIM_RANGE_TILES) -> Vector2:
	var mouse_pos := get_global_mouse_position()
	var aim_vec := mouse_pos - global_position
	if aim_vec.length_squared() <= 0.01:
		return mouse_pos
	var target := _find_auto_aim_target(aim_vec.normalized(), range_tiles)
	return target.global_position if target != null else mouse_pos


## 마우스 방향(aim_dir) 기준 ±AUTO_AIM_CONE_HALF_DEG 콘 안, range_tiles 사거리
## 안에서 가장 가까운 "살아있는" 몬스터를 반환한다. 조건을 만족하는 적이 없으면 null(→
## 순수 마우스 방향 유지). 스냅 각도/기본 사거리는 상단 상수로 튜닝한다.
func _find_auto_aim_target(aim_dir: Vector2, range_tiles: float = AUTO_AIM_RANGE_TILES) -> Node2D:
	var range_px := range_tiles * movement_data.tile_size_px
	var range_sq := range_px * range_px
	var cos_limit := cos(deg_to_rad(AUTO_AIM_CONE_HALF_DEG))
	var best: Node2D = null
	var best_dist_sq := INF
	for candidate in _aim_candidates:
		if not is_instance_valid(candidate):
			continue
		if candidate.has_method("is_dead") and candidate.is_dead():
			continue
		var to_candidate: Vector2 = candidate.global_position - global_position
		var dist_sq := to_candidate.length_squared()
		if dist_sq > range_sq or dist_sq <= 0.01:
			continue
		if to_candidate.normalized().dot(aim_dir) < cos_limit:
			continue  ## 콘(원뿔) 각도 밖
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = candidate
	return best


## 자동 조준 후보 수집 — "monsters" 그룹을 우선 사용하고, 그룹이 비어 있으면 씬 트리에서
## MonsterBase를 직접 탐색한다(현재 스포너는 그룹 등록을 하지 않으므로 실동작 경로는 후자).
func _gather_aim_candidates() -> void:
	_aim_candidates = get_tree().get_nodes_in_group(MONSTER_GROUP)
	if _aim_candidates.is_empty():
		var found: Array = []
		_collect_monster_bases(get_tree().root, found)
		_aim_candidates = found


func _collect_monster_bases(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is MonsterBase:
			out.append(child)
		else:
			_collect_monster_bases(child, out)


# --- 기본 공격 콤보 (m2-warrior-skills.md 2장 "대검 2타 콤보") ---


func _process_attack_input() -> void:
	_advance_attack_from_input(Input.is_action_pressed("attack"))


## QoL① 홀드 연타 — attack을 누르고 있는 동안 콤보를 자동 지속한다. 기본 공격은 쿨다운이
## 없으므로 콤보 윈도우·스윙 타이밍만 존중하면 된다: STARTUP/ACTIVE(윈도우 0) 중에는 아무
## 일도 하지 않고, RECOVERY(윈도우 > 0)에서만 다음 타를 예약하며, 콤보가 끝나(NONE) 여전히
## 눌려 있으면 첫 타부터 다시 시작한다. 단발 클릭도 이 경로로 처리된다(누른 프레임에 진입).
func _advance_attack_from_input(attack_held: bool) -> void:
	if not attack_held:
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
	_attack_anim_restart_requested = true  ## 이 스윙의 공격 애니메이션을 프레임0부터 강제 재생
	_gather_aim_candidates()  ## QoL②③ 스냅·재조준용 후보를 스윙 시작 시 1회 수집
	var step: WarriorAttackStep = combo_data.steps[step_index]
	attack_step_started.emit(step_index, step.hitstop_preset)


func _process_attack_state(delta: float) -> void:
	if attack_state == AttackState.NONE:
		return
	var step: WarriorAttackStep = combo_data.steps[_attack_step_index]
	_attack_phase_timer += delta * _attack_rate_for_step(step)
	match attack_state:
		AttackState.STARTUP:
			if _attack_phase_timer >= step.startup_sec:
				attack_state = AttackState.ACTIVE
				_attack_phase_timer = 0.0
				## 화살 규격이 있으면 투사체 발사, 없으면 기존 근접 부채꼴 판정(전사).
				if not _try_fire_arrows(step):
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


## 기본 공격 진행 속도 배율(1.0 = 규격 그대로) — 궁수 매의 눈 공격 속도와 조준 모드 사격
## 사이클이 여기에 반영된다. 전사는 두 값이 모두 비어 있어 항상 1.0(기존 동작과 동일).
func _attack_rate_for_step(step: WarriorAttackStep) -> float:
	return _shots.attack_rate(step.get_total_motion_sec())


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
	_attack_hitbox.monitoring = true


func _disable_attack_hitbox() -> void:
	_attack_hitbox.monitoring = false


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


# --- 스킬 슬롯 (CB-2 — 상세는 player_skill_module.gd) ---
#
# 슬롯 입력·사용 게이트(쿨다운/MP)·시전 상태머신·쿨다운 장부는 모듈이 담당하고, 아래
# 함수들은 다른 도메인(테스트·디버그 HUD)이 쓰는 종전 진입점을 그대로 유지하는 위임이다.


func _try_use_skill(key: String, skill: WarriorSkillData) -> bool:
	return _skills.try_use(key, skill)


func _process_skill_state(delta: float) -> void:
	_skills.process_state(delta)


func _apply_self_buff(skill: WarriorSkillData) -> void:
	## 버프·힐도 스킬 강화 레벨만큼 효과 수치(회복%·버프%·지속)가 오른다(spec 6-2 구현 규약).
	## Lv1이면 배율 1.0이라 값이 그대로다.
	var mult := 1.0
	if _skill_points != null:
		mult = _skill_points.effective_multiplier(StringName(skill.skill_name))
	## 궁수 버프(매의 눈)는 HP/MP를 건드리지 않으므로 PlayerStats 없이도 적용된다.
	_shots.apply_buff(skill as ArcherSkillData, mult)
	if _stats == null:
		return
	## 검투사 버프(혈투의 함성 — 흡혈·분노 가속)는 흡혈 총량 상한 계산에 최대 HP가 필요하다.
	rage.apply_buff(skill as GladiatorSkillData, mult, _stats.stats.max_hp)
	if skill.self_heal_percent > 0.0:
		_stats.heal(_stats.stats.max_hp * skill.self_heal_percent * mult)
	if skill.grants_superarmor_sec > 0.0:
		_buff_superarmor_timer = skill.grants_superarmor_sec * mult
	if skill.defense_buff_percent > 0.0:
		_stats.apply_defense_buff(
			skill.defense_buff_percent * mult, skill.defense_buff_duration_sec * mult
		)


func _cancel_skill() -> void:
	_skills.cancel()


func _end_skill() -> void:
	_skills.finish()


func _update_skill_cooldowns(delta: float) -> void:
	_skills.advance_cooldowns(delta)


func get_skill_cooldown_remaining(key: String) -> float:
	return _skills.remaining(key)


# --- 궁수 원거리 사격 연결 (M3 C-4/C-5 — 상세는 archer_shot_module.gd) ---


## PlayerAttackResolver가 치명타 확률에 더하는 가산 보너스(매의 눈 +15%p). 상한 40%
## (combat.md 6장)은 리졸버 쪽에서 적용한다.
func get_crit_chance_bonus() -> float:
	return _shots.crit_chance_bonus


## 매의 눈이 부여한 사거리 가산(타일) — 화살 사거리·자동 조준 스냅 거리에 함께 더해진다.
func get_attack_range_bonus_tiles() -> float:
	return _shots.attack_range_bonus_tiles


## action(기본 공격 스텝 또는 스킬)에 화살 규격이 있으면 발사하고 true를 돌려준다.
## 없으면 false — 호출자가 기존 근접 히트박스 경로를 유지한다(전사 회귀 방지).
func _try_fire_arrows(action: Resource) -> bool:
	var spec := _shots.arrow_spec_for(action)
	if spec == null:
		return false
	_current_action_step = action
	## 발사 직전에 조준을 확정한다(자동 조준 스냅 사거리 = 화살 유효 사거리).
	_gather_aim_candidates()
	_apply_attack_aim(_shots.effective_range_tiles(spec))
	_shots.fire(action, spec, Vector2.RIGHT.rotated(_facing.rotation))
	return true


## 화살 명중을 근접 판정과 동일한 attack_hit 계약으로 중계한다 — PlayerAttackResolver가
## 계수(스킬 강화 포함)·치명타 굴림·방어 감산·히트피드백을 그대로 처리한다(6-2장 델타 ②③).
func _on_arrow_hit_landed(action: Resource, body: Node) -> void:
	attack_hit.emit(action, body)


# --- 전직 로드아웃 교체 (M3 B-5, 승계형 교체 — m3-warrior-tier2-skills.md 1장) ---


## 전직 시 활성 스킬 슬롯과 기본 공격 콤보를 교체한다(PlayerJobTransition이 호출).
## slots는 슬롯 이름("slot_1"~"slot_3"·"slot_4"·"slot_q"·"slot_e"·"ultimate"·"charge") ->
## WarriorSkillData 사전이며, 값이 없거나 null이면 해당 슬롯은 미개방으로 둔다(승계형 교체 —
## 새 키를 만들지 않고 같은 슬롯을 직업 스킬로 채운다). combo가 주어지면 기본 공격 무기를
## 교체한다(대검 -> 활 등). 진행 중 콤보/스킬/차지와 쿨다운을 초기화해 이전 직업의 잔여
## 상태가 남지 않게 한다.
func apply_transition_loadout(slots: Dictionary, combo: WarriorComboData = null) -> void:
	skill_slot_1 = slots.get("slot_1") as WarriorSkillData
	skill_slot_2 = slots.get("slot_2") as WarriorSkillData
	skill_slot_3 = slots.get("slot_3") as WarriorSkillData
	skill_slot_4 = slots.get("slot_4") as WarriorSkillData
	skill_slot_q = slots.get("slot_q") as WarriorSkillData
	skill_slot_e = slots.get("slot_e") as WarriorSkillData
	skill_ultimate = slots.get("ultimate") as WarriorSkillData
	skill_charge = slots.get("charge") as WarriorSkillData
	if combo != null:
		combo_data = combo
	_shots.refresh_stance(skill_charge)
	## 우클릭 격노 파생 슬롯(검투사 처형 일격) — 있으면 분노 게이지가 켜진다(2차 전직).
	rage.refresh_job(slots.get("rage_finisher") as WarriorSkillData)
	_reset_action_state()


## 진행 중인 콤보·스킬·차지와 쿨다운을 초기화한다(전직 슬롯 교체 시 잔여 상태 제거).
func _reset_action_state() -> void:
	if attack_state != AttackState.NONE:
		_disable_attack_hitbox()
		_end_combo()
	if skill_state != AttackState.NONE:
		_cancel_skill()
	if _is_charging_secondary:
		_cancel_charge()
	_shots.cancel_burst()
	_skills.clear_cooldowns()


# --- 차지 강타 (우클릭 홀드, m2-warrior-skills.md 3장) ---


func _process_secondary_charge_start_input() -> void:
	if _shots.aim_stance != null:
		return  ## 우클릭이 궁수 조준 스탠스 — 차지가 아니라 ArcherShotModule이 처리한다
	if not Input.is_action_just_pressed("skill_secondary"):
		return
	## 분노 ≥ 50이면 우클릭이 차지 강타 대신 처형 일격으로 대체된다(2-3·4-4장 조건부 파생 —
	## 신규 키를 만들지 않는다). 게이지가 하한 미달이거나 검투사가 아니면 기존 차지 경로.
	if rage.can_use_finisher():
		_use_rage_finisher()
		return
	if skill_charge == null or not _skills.secondary_ready():
		return
	if _stats and not _stats.has_mp(_skills.mp_cost(skill_charge)):
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
	var mp_cost := _skills.mp_cost(skill_charge)
	if _stats and not _stats.has_mp(mp_cost):
		return
	if _stats:
		_stats.spend_mp(mp_cost)
	_skills.set_secondary_cooldown(skill_charge.cooldown_sec)
	## 차지 강타는 홀드 비율에 따라 계수·후딜이 달라진다(m2-warrior-skills.md 3장) — 공용
	## 리소스 필드를 이번 사용 값으로 덮어써 재사용한다(항상 사용 직전에 다시 계산되므로
	## 이전 값이 남는 부작용 없음).
	skill_charge.damage_coefficient = lerp(
		skill_charge.charge_min_coefficient, skill_charge.charge_max_coefficient, ratio
	)
	skill_charge.recovery_sec = lerp(
		skill_charge.charge_min_recovery_sec, skill_charge.charge_max_recovery_sec, ratio
	)
	_skills.begin_active(skill_charge)


# --- 분노 게이지 연결 (M3 C-1 — 상세는 player_rage_module.gd) ---


## 처형 일격 발동 — 보유 분노를 전량 소모하고, 소모량에 선형 비례하는 계수(3.5~5.0)를
## 리소스에 써넣은 뒤 일반 스킬 경로로 시전한다(차지 강타가 홀드 비율로 계수를 덮어쓰는
## 것과 동일 방식 — 항상 발동 직전에 다시 계산되므로 이전 값이 남지 않는다).
## MP·쿨다운은 없다(분노 게이지가 곧 재사용 제한 — 4-4장).
func _use_rage_finisher() -> bool:
	var finisher := rage.finisher
	var consumed := rage.consume_for_finisher()
	if consumed <= 0.0:
		return false
	finisher.damage_coefficient = rage.finisher_coefficient(consumed)
	_skills.start(finisher)
	return true


## PlayerAttackResolver가 전 데미지에 곱하는 배율 — 격노 중 공격력 +12%(2-3장).
func get_attack_power_multiplier() -> float:
	return rage.attack_multiplier()


## 공격 판정이 성립해 데미지가 적용된 뒤 PlayerAttackResolver가 호출한다 — 분노 충전과
## 혈투의 함성 흡혈을 처리한다. 분노 게이지가 없는 직업에서는 모듈이 전부 무시한다.
func on_attack_landed(action: Resource, damage: float, is_critical: bool) -> void:
	rage.add_from_attack(action, is_critical)
	var healed := rage.lifesteal_heal(damage)
	if healed > 0.0 and _stats:
		_stats.heal(healed)


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
	rage.add_from_hit_taken()  ## 피격 +12 — 분노의 최대 단일 충전원(2-2장)
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
	_dash_direction = _resolve_dodge_direction()
	is_dashing = true
	is_dash_invincible = false
	_dash_timer = 0.0
	dash_started.emit()
	HitFeedback.play_sfx(DODGE_SFX, global_position)


## 회피 방향 — 기본은 입력 방향(전사 대시, combat.md 4장). 무기(콤보)가 후방 회피를 쓰는
## 궁수 활이면 조준 반대 방향으로 튀는 후방 점프 회피가 된다(m3-archer-skills 2-2장 —
## "궁수 회피는 카이팅 그 자체"). 조준 방향이 없거나 오염되면 입력 방향으로 안전 복귀한다.
func _resolve_dodge_direction() -> Vector2:
	if combo_data == null or not combo_data.dodge_backward:
		return _last_move_direction
	var aim_dir := Vector2.RIGHT.rotated(_facing.rotation)
	if not aim_dir.is_finite() or aim_dir.length_squared() <= 0.0001:
		return _last_move_direction
	return -aim_dir


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


# --- 비주얼(애니메이션) 갱신 — 상세는 player_visual_module.gd ---


func _update_visual() -> void:
	visual.update(
		_attack_anim_restart_requested,
		_is_charging_secondary,
		_move_input,
		_last_move_direction,
		_facing.rotation,
		_attack_step_index
	)
	_attack_anim_restart_requested = false


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
	if _shots.is_aiming:
		text = "조준 모드 (%s)" % ("사격" if attack_state != AttackState.NONE else "대기")
	if is_dashing:
		text = "회피 대시%s" % (" (무적)" if is_dash_invincible else "")
	if is_hit_stunned:
		text = "피격 경직%s" % (" (무적)" if is_hit_invincible else "")
	if rage.is_active():
		var enrage := " 격노!" if rage.is_enraged() else ""
		text += " | 분노 %d/%d%s" % [int(rage.current_rage), int(rage.max_rage()), enrage]
	return text
