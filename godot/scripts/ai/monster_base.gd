## 몬스터 공용 베이스 — HP/피격 스텁, 배회 이동 헬퍼, 근접 스윙 블록 연동을 제공한다.
##
## 뿔토끼(RabbitMonster)·들개 마수(WolfMonster)·균열 점액(RiftSlimeMonster)의 개별
## 상태머신(배회/추적/도주/근접 스윙/투사체 등, m2-monster-spec.md 3장 상태 전이 그대로)은
## 각 하위 클래스가 구현하며, 본 클래스는 3종이 공유하는 부품만 제공한다.
##
## CB-3 연동 지점: take_damage()는 "최종 데미지 값을 그대로 HP에서 뺀다"만 하는 스텁이다.
## 방어 감산·치명타·위치 보정 등 데미지 공식(combat.md 6장) 자체는 gameplay-dev(CB-3)가
## 공격자(플레이어) 쪽에서 계산해 이 메서드에 최종 값과 타격 등급(hit_grade)을 넘겨준다.
## hit_grade("약"/"중"/"강", combat.md 5-3 히트스톱 등급과 동일 표기)는 균열 점액의
## 코어 파괴 기믹(m2-monster-spec.md 3-3장) 분기에 쓰인다.
##
## attack_landed 시그널도 마찬가지로 CB-3 연동 지점이다 — 몬스터가 플레이어를 맞혔다는
## "판정 성립"만 알리고, 실제 플레이어 피해 적용은 gameplay-dev(CB-3/CB-4)가 담당한다.
##
## 몬스터(잡몹) 피격 경직·넉백 배선 (M2 후반 통합, mob_stagger_component.gd는 gameplay-dev가
## 구현한 공용 컴포넌트를 그대로 부착만 한다 — scripts/combat 수정 없음):
## 씬에 "MobStagger" 이름의 MobStaggerComponent 자식 노드를 두면(체급별 rules.tres는
## 뿔토끼=light/들개 마수=표준/균열 점액=heavy, m2-monster-spec.md 6장), take_damage()가
## 자동으로 register_hit()을 호출해 경직·넉백을 반영한다. is_heavy 판정은 hit_grade=="강"
## (combat.md 5-2 "강타·치명타" — 치명타뿐 아니라 차지 강타 등 설계상 강 등급 공격도
## 포함하므로, MobStaggerComponent 헤더 주석이 권장하는 is_critical 단독보다 더 정확하다).
## 넉백 방향은 공격자 반대편 수평 이동(combat.md 5-2-1), 벽 충돌 시 move_and_slide()가
## 자연히 정지시킨다(플레이어 take_hit()과 동일한 방식).
##
## 야간 스탯 배율 (G2-4, combat.md 2-3장 — 보스 제외): stats(MonsterStatsData)는 여러
## 몬스터 인스턴스가 공유하는 Resource이므로 max_hp/attack_power 필드 자체를 곱해 바꾸면
## 안 된다(모든 인스턴스가 오염되고, .tres에 그대로 저장되어 영구화될 위험도 있다). 대신
## 배율은 인스턴스별 변수(_night_multiplier)로만 들고, effective_max_hp()/
## effective_attack_power()가 그 값을 곱해 파생시킨다. GameClock.night_started/
## day_started를 구독해 전환 시 배율을 갱신하고, 그 시점의 hp는 "체력 비율 유지"로
## 재계산한다(예: 밤에 50% 남았다면 낮이 되어 최대 HP가 줄어도 50% 그대로).
##
## M3(C-8) 공용 추가 — 기본값이 M2 동작과 완전히 동일해 3종(뿔토끼·들개 마수·균열 점액)의
## 거동은 바뀌지 않는다(회귀 테스트로 확인):
##   - current_attack_multiplier: 실행 중인 행동 블록의 데미지 계수(도약 ×1.0·돌진 ×1.2 등,
##     m3-monster-spec 3장). MonsterAttackResolver(scripts/combat, 수정 금지 영역)가 스킬
##     계수 1.0으로 고정해 계산하므로, 블록별 계수는 effective_attack_power()에 곱해 넘긴다.
##   - _filter_incoming_damage()/_ignores_stagger(): 무법자 가드(정면 −60%·넉백 무효)와
##     정예 슈퍼아머(stats.is_elite, combat.md 5-2 정예 행)를 위한 훅. 기본 구현은 감쇄 없음.
##   - _play_animation_or(): 신규 상태 프레임(웅크림·돌진·가드·순간이동 등)이 아직 없는
##     C-9 이전 단계에서도 기존 4종 애니메이션으로 자동 폴백한다.
class_name MonsterBase
extends CharacterBody2D

signal took_damage(amount: float, remaining_hp: float)
signal died
signal attack_landed(target: Node)  ## 근접 스윙 명중 — CB-3 연동 지점

const HOME_ARRIVAL_TOLERANCE_PX := 4.0  ## 귀환 도착 판정 허용 오차

@export var stats: MonsterStatsData

## 추적/감지 대상(보통 플레이어) 노드. scripts/player·scenes/world는 다른 에이전트가
## 동시 작업 중이라 그룹 자동 탐색 대신, 레벨/디버그 전투장/테스트가 이 필드에 직접
## 주입하는 방식을 쓴다(결합 지점을 외부 주입으로 남겨 통합은 후속 패스에서 처리).
var target: Node2D = null

var hp: float = 0.0
var home_position: Vector2 = Vector2.ZERO
var last_hit_grade: String = "약"
var last_attacker: Node2D = null

## 현재 실행 중인 공격 행동 블록의 데미지 계수(헤더 "M3 공용 추가" 참고). 블록이 판정
## 구간에 들어갈 때 하위 클래스가 설정하고, 판정이 끝나면 1.0으로 되돌린다.
var current_attack_multiplier: float = 1.0

var _swing: MeleeSwingBlock = null
var _facing_left: bool = false
var _knockback_velocity := Vector2.ZERO
var _night_multiplier: float = 1.0

@onready var _sprite: AnimatedSprite2D = get_node_or_null("Sprite")
@onready var _attack_hitbox: Area2D = get_node_or_null("AttackHitbox")
@onready
var _attack_hitbox_shape: CollisionShape2D = get_node_or_null("AttackHitbox/CollisionShape2D")
@onready var _stagger: MobStaggerComponent = get_node_or_null("MobStagger")


func _ready() -> void:
	_night_multiplier = GameClock.get_monster_stat_multiplier(stats.is_boss)
	hp = effective_max_hp()
	home_position = global_position
	_play_animation("idle")
	if not stats.is_boss:
		GameClock.night_started.connect(_on_night_started)
		GameClock.day_started.connect(_on_day_started)


## 야간 배율이 반영된 실제 최대 HP/공격력 (combat.md 2-3장 헤더 주석 참고).
func effective_max_hp() -> float:
	return stats.max_hp * _night_multiplier


func effective_attack_power() -> float:
	return stats.attack_power * _night_multiplier * current_attack_multiplier


func _on_night_started(_day_number: int) -> void:
	_apply_stat_multiplier(GameClock.get_monster_stat_multiplier(stats.is_boss))


func _on_day_started(_day_number: int) -> void:
	_apply_stat_multiplier(GameClock.get_monster_stat_multiplier(stats.is_boss))


## 배율 전환 시 hp를 "체력 비율 유지"로 재계산한다(만렙 HP가 줄거나 늘어도 즉사·풀피
## 회복이 발생하지 않게).
func _apply_stat_multiplier(new_multiplier: float) -> void:
	if is_dead():
		return
	var previous_max := effective_max_hp()
	var ratio := hp / previous_max if previous_max > 0.0 else 1.0
	_night_multiplier = new_multiplier
	hp = effective_max_hp() * ratio


# --- 피격/사망 (CB-3 연동 지점) ---


func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	if is_dead():
		return
	last_hit_grade = hit_grade
	if attacker:
		last_attacker = attacker
	var final_amount := _filter_incoming_damage(amount, hit_grade, attacker)
	hp = max(hp - final_amount, 0.0)
	took_damage.emit(final_amount, hp)
	if hp <= 0.0:
		_die()
		return
	if _ignores_stagger(hit_grade, attacker):
		return
	_register_stagger_hit(hit_grade, attacker)


## 피격 데미지 감쇄 훅 — 기본은 감쇄 없음. 무법자 가드(정면 ±60° −60%, m3-monster-spec
## 3-4장)처럼 방어 블록이 있는 종이 재정의한다.
func _filter_incoming_damage(amount: float, _hit_grade: String, _attacker: Node2D) -> float:
	return amount


## 경직·넉백 무시 훅 — 정예는 평시 슈퍼아머(combat.md 5-2 정예 행)라 경직이 발생하지
## 않는다. 그로기 게이지는 정예 공용 프레임 소관이라 C-8 범위 밖(m3-monster-spec 7-5장).
func _ignores_stagger(_hit_grade: String, _attacker: Node2D) -> bool:
	return stats.is_elite


func is_dead() -> bool:
	return hp <= 0.0


## 씬에 MobStagger 자식 노드가 있는 동안에만 true — 상태머신은 이 값이 true인 동안
## 자신의 배회/추적/공격 로직을 건너뛰고 넉백 이동만 적용해야 한다(각 하위 클래스
## _physics_process 최상단, is_dead() 다음 순서로 확인).
func is_staggered() -> bool:
	return _stagger != null and _stagger.is_staggered()


## 피격 경직 등록 + 넉백 속도 산출(combat.md 5-2·5-2-1장). 슈퍼아머 중이면
## MobStaggerComponent가 알아서 경직을 무시하므로 넉백도 발생하지 않는다.
func _register_stagger_hit(hit_grade: String, attacker: Node2D) -> void:
	if _stagger == null:
		return
	var is_heavy := hit_grade == "강"
	var result := _stagger.register_hit(is_heavy)
	if not result["staggered"]:
		return
	var rules := _stagger.rules
	var stagger_duration := rules.heavy_stagger_sec if is_heavy else rules.light_stagger_sec
	var knockback_tiles := rules.heavy_knockback_tiles if is_heavy else rules.light_knockback_tiles
	var direction := Vector2.ZERO
	if attacker:
		direction = global_position - attacker.global_position
	## 공격자 위치를 알 수 없거나(테스트 등) 이미 NaN 등으로 오염되어 있으면(2026-07-18
	## 경고 스팸 수정 — is_zero_approx()는 NaN에서 false를 반환해 그대로 normalized()로
	## 흘러가 "Vector2 cannot be normalized" 경고를 반복시킨다) 임의 대체 방향을 쓴다.
	if direction.is_zero_approx() or not direction.is_finite():
		direction = Vector2.DOWN
	var distance_px := stats.tiles_to_px(knockback_tiles)
	_knockback_velocity = (
		direction.normalized() * (distance_px / stagger_duration)
		if stagger_duration > 0.0
		else Vector2.ZERO
	)


## move_and_slide() 직전 트랜스폼·속도 유한성 가드 (2026-07-26 경고 스팸 근본 수정).
## 각 하위 클래스는 move_and_slide() 호출 앞에 반드시 이 함수를 붙인다.
##
## 근본 증상(재현 테스트로 확인): CharacterBody2D.global_position(트랜스폼)이 한번
## non-finite(NaN/Inf)가 되면, 그 이후 move_and_slide()는 velocity가 (0,0)이어도 매 물리
## 프레임 충돌 법선을 normalize하며 "Vector2 cannot be normalized" 경고를 무한 반복한다.
## 위치는 한번 오염되면 velocity를 고쳐도 스스로 낫지 않는다 — 이전 수정(b0a9d2a)이
## velocity만 ZERO로 눌러 증상을 못 잡은 이유가 바로 이것이다(경고 backtrace의 velocity가
## (0,0)이었던 것이 증거).
##
## 따라서 velocity뿐 아니라 global_position 자체의 유한성을 확인해, 오염 시 유한한
## 기준점(home_position, 그마저 오염됐으면 원점)으로 복구한다 — 어떤 경로로 오염됐든
## 개체가 스스로 1프레임 내 회복해 경고 스팸이 지속되지 않게 한다.
func _guard_finite_before_move() -> void:
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	if not global_position.is_finite():
		global_position = home_position if home_position.is_finite() else Vector2.ZERO
		velocity = Vector2.ZERO


func _die() -> void:
	died.emit()
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("death"):
		set_physics_process(false)
		if _attack_hitbox:
			_attack_hitbox.monitoring = false
		_play_animation("death")
		_sprite.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
	else:
		queue_free()


# --- 거리/이동 헬퍼 (배회·추적·도주 공용) ---


func distance_tiles_to(pos: Vector2) -> float:
	if stats.tile_size_px <= 0.0:
		return 0.0
	return global_position.distance_to(pos) / stats.tile_size_px


func is_target_in_range_tiles(range_tiles: float) -> bool:
	if target == null:
		return false
	return distance_tiles_to(target.global_position) <= range_tiles


func random_wander_direction() -> Vector2:
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()


## point가 NaN 등 비유한 좌표(예: 대상 쪽 좌표 오염)를 담고 있으면 is_zero_approx()가
## false를 반환해 그대로 normalized()에 들어가 "Vector2 cannot be normalized" 경고가
## 매 프레임 반복된다(2026-07-18 경고 스팸 수정) — 정지 상태(ZERO)로 대체해 방지한다.
func move_toward_point(point: Vector2, speed_tiles: float) -> Vector2:
	var to_point := point - global_position
	if to_point.is_zero_approx() or not to_point.is_finite():
		return Vector2.ZERO
	return to_point.normalized() * stats.tiles_to_px(speed_tiles)


## 귀환(leash) 공용 처리 — 스폰 지점으로 이동하고, 도착하면 HP를 완전 회복한 뒤 true를
## 반환한다(combat.md 2-2, M2 들개 마수 _process_return과 동일 규칙). M3 신규 3종이 공유한다.
func _return_to_home() -> bool:
	if home_position.distance_to(global_position) <= HOME_ARRIVAL_TOLERANCE_PX:
		global_position = home_position
		hp = effective_max_hp()
		velocity = Vector2.ZERO
		return true
	velocity = move_toward_point(home_position, stats.combat_move_speed_tiles)
	_play_animation("walk", velocity)
	return false


func move_away_from_point(point: Vector2, speed_tiles: float) -> Vector2:
	var away := global_position - point
	if away.is_zero_approx() or not away.is_finite():
		return Vector2.ZERO
	return away.normalized() * stats.tiles_to_px(speed_tiles)


# --- 근접 스윙 블록 연동 (뿔토끼 박치기·들개 마수 물기 공용) ---


func _init_melee_swing() -> void:
	_swing = MeleeSwingBlock.new()
	_swing.telegraph_sec = stats.melee_telegraph_sec
	_swing.active_sec = stats.melee_active_sec
	_swing.recovery_sec = stats.melee_recovery_sec
	_swing.telegraph_started.connect(_on_swing_telegraph_started)
	_swing.became_active.connect(_enable_attack_hitbox)
	_swing.ended.connect(_disable_attack_hitbox)
	_setup_attack_hitbox(stats.melee_range_tiles)


## AttackHitbox의 판정 반경을 지정하고 body_entered를 연결한다. 근접 스윙(사거리)뿐 아니라
## M3 신규 블록(숲거미 도약 착지 반경·무법자 돌진 경로)도 같은 히트박스를 반경만 바꿔 쓴다.
func _setup_attack_hitbox(radius_tiles: float) -> void:
	if _attack_hitbox_shape:
		var circle := CircleShape2D.new()
		circle.radius = stats.tiles_to_px(radius_tiles)
		_attack_hitbox_shape.shape = circle
	if (
		_attack_hitbox
		and not _attack_hitbox.body_entered.is_connected(_on_attack_hitbox_body_entered)
	):
		_attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)


func _on_swing_telegraph_started() -> void:
	## 예고 모션 — 이펙트 없이 색 변조만 (vfx-artist 후속 작업 전까지 임시)
	if _sprite:
		_sprite.modulate = Color(1.0, 0.3, 0.3)


func _enable_attack_hitbox() -> void:
	if _attack_hitbox:
		_attack_hitbox.monitoring = true


func _disable_attack_hitbox() -> void:
	if _attack_hitbox:
		_attack_hitbox.monitoring = false
	if _sprite:
		_sprite.modulate = Color(1.0, 1.0, 1.0)


func _on_attack_hitbox_body_entered(body: Node) -> void:
	if body == self:
		return  ## 충돌 레이어로 이미 차단되지만, 이중 안전장치로 자기 자신은 명시적으로 제외한다.
	attack_landed.emit(body)


# --- 애니메이션 재생 (AR-2 스프라이트, 3방향 시트 중 "측면" 행만 사용) ---
# 단순화(assumption): 상하 이동 시에도 측면 프레임을 그대로 쓰고 좌우만 flip_h로
# 뒤집는다. 시트에는 하/상 방향 근사 프레임도 있으나(ASSET_SOURCES.md 참고),
# 방향별 프레임 전환 컨트롤러는 CB-6 범위를 넘어서므로 후속 작업으로 남긴다.


## direction.x의 부호로 좌우 반전을 갱신한다(0에 가까우면 이전 방향 유지).
func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > 0.001:
		_facing_left = direction.x < 0.0


func _play_animation(anim_name: String, direction: Vector2 = Vector2.ZERO) -> void:
	_update_facing(direction)
	if (
		not _sprite
		or not _sprite.sprite_frames
		or not _sprite.sprite_frames.has_animation(anim_name)
	):
		return
	_sprite.flip_h = _facing_left
	if _sprite.animation != anim_name or not _sprite.is_playing():
		_sprite.play(anim_name)


## preferred 애니메이션(예: 도약 예고 "crouch")이 스프라이트 시트에 없으면 fallback으로
## 재생한다 — 신규 상태 프레임이 C-9에서 추가되면 코드 수정 없이 자동으로 승격된다.
func _play_animation_or(
	preferred: String, fallback: String, direction: Vector2 = Vector2.ZERO
) -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(preferred):
		_play_animation(preferred, direction)
		return
	_play_animation(fallback, direction)
