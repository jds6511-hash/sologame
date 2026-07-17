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
class_name MonsterBase
extends CharacterBody2D

signal took_damage(amount: float, remaining_hp: float)
signal died
signal attack_landed(target: Node)  ## 근접 스윙 명중 — CB-3 연동 지점

@export var stats: MonsterStatsData

## 추적/감지 대상(보통 플레이어) 노드. scripts/player·scenes/world는 다른 에이전트가
## 동시 작업 중이라 그룹 자동 탐색 대신, 레벨/디버그 전투장/테스트가 이 필드에 직접
## 주입하는 방식을 쓴다(결합 지점을 외부 주입으로 남겨 통합은 후속 패스에서 처리).
var target: Node2D = null

var hp: float = 0.0
var home_position: Vector2 = Vector2.ZERO
var last_hit_grade: String = "약"
var last_attacker: Node2D = null

var _swing: MeleeSwingBlock = null
var _facing_left: bool = false
var _knockback_velocity := Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = get_node_or_null("Sprite")
@onready var _attack_hitbox: Area2D = get_node_or_null("AttackHitbox")
@onready
var _attack_hitbox_shape: CollisionShape2D = get_node_or_null("AttackHitbox/CollisionShape2D")
@onready var _stagger: MobStaggerComponent = get_node_or_null("MobStagger")


func _ready() -> void:
	hp = stats.max_hp
	home_position = global_position
	_play_animation("idle")


# --- 피격/사망 (CB-3 연동 지점) ---


func take_damage(amount: float, hit_grade: String = "약", attacker: Node2D = null) -> void:
	if is_dead():
		return
	last_hit_grade = hit_grade
	if attacker:
		last_attacker = attacker
	hp = max(hp - amount, 0.0)
	took_damage.emit(amount, hp)
	if hp <= 0.0:
		_die()
		return
	_register_stagger_hit(hit_grade, attacker)


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
	if direction.is_zero_approx():
		direction = Vector2.DOWN  ## 공격자 위치를 알 수 없을 때(예: 테스트)의 임의 대체 방향
	var distance_px := stats.tiles_to_px(knockback_tiles)
	_knockback_velocity = (
		direction.normalized() * (distance_px / stagger_duration)
		if stagger_duration > 0.0
		else Vector2.ZERO
	)


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


func move_toward_point(point: Vector2, speed_tiles: float) -> Vector2:
	var to_point := point - global_position
	if to_point.is_zero_approx():
		return Vector2.ZERO
	return to_point.normalized() * stats.tiles_to_px(speed_tiles)


func move_away_from_point(point: Vector2, speed_tiles: float) -> Vector2:
	var away := global_position - point
	if away.is_zero_approx():
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
	if _attack_hitbox_shape:
		var circle := CircleShape2D.new()
		circle.radius = stats.tiles_to_px(stats.melee_range_tiles)
		_attack_hitbox_shape.shape = circle
	if _attack_hitbox:
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
