## 균열 점액 투사체(산성 방울) — m2-monster-spec.md 3-3장.
##
## 등속 직선 이동으로 조준 지점까지 날아가 판정한다. spec은 "포물선(회피 가능)"으로
## 서술하지만, 궤적 곡선 자체는 vfx-artist 후속 작업 영역이라 이동 판정은 등속
## 직선으로 근사한다(도달까지 걸리는 시간은 동일하게 유지되므로 회피 타이밍 밸런스에는
## 영향이 없다).
class_name RiftSlimeProjectile
extends Area2D

signal hit_target(body: Node)  ## CB-3 연동 지점 — 실제 데미지 계산은 gameplay-dev 담당

var _velocity := Vector2.ZERO
var _remaining_distance: float = 0.0

## 직격 피해 계산 파라미터(스폰 시 RiftSlimeMonster가 configure()로 주입). _formula_data가
## null이면 기존처럼 hit_target 시그널만 발신하고 실피해는 적용하지 않는다(미배선·테스트 대응).
var _attack_power: float = 0.0
var _formula_data: DamageFormulaData

@onready var _sprite: Sprite2D = get_node_or_null("Sprite")


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_setup_placeholder_sprite()


## 스폰 직후(launch 전)에 호출해 직격 피해 계산 파라미터를 주입한다(RiftSlimeAcidPool.configure와
## 동일 패턴). attack_power는 야간 배율이 반영된 값(effective_attack_power)을 넘겨받는다.
func configure(attack_power: float, formula_data: DamageFormulaData) -> void:
	_attack_power = attack_power
	_formula_data = formula_data


## target_point까지 speed_px_per_sec 속도로 직선 이동을 시작한다.
func launch(target_point: Vector2, speed_px_per_sec: float) -> void:
	var to_target := target_point - global_position
	_remaining_distance = to_target.length()
	if _remaining_distance > 0.0:
		_velocity = to_target.normalized() * speed_px_per_sec
	else:
		_velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	var step := _velocity * delta
	global_position += step
	_remaining_distance -= step.length()
	if _remaining_distance <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	hit_target.emit(body)
	_apply_hit(body)
	queue_free()


## 투사체 직격은 "직접 타격"이므로 MonsterAttackResolver(근접 스윙)와 동일하게 take_hit
## (경직·무적·넉백) 후 DamageCalculator로 실피해를 적용한다 — 산성 웅덩이는 "위험지대 접촉"이라
## take_hit을 부르지 않지만(rift_slime_acid_pool.gd 헤더), 투사체는 근접 스윙과 같은 직격이다.
func _apply_hit(body: Node) -> void:
	if _formula_data == null or not body.has_method("take_hit"):
		return
	if body.has_method("is_invincible") and body.is_invincible():
		return
	var knockback_direction := Vector2.ZERO
	if body is Node2D:
		knockback_direction = body.global_position - global_position
	body.take_hit(false, knockback_direction)
	if not body.has_method("take_damage"):
		return
	var damage := DamageCalculator.calculate_damage(
		_attack_power, 1.0, _resolve_target_defense(body), _formula_data, false, false
	)
	body.take_damage(damage, "약", self)


## PlayerAttackResolver/MonsterAttackResolver와 동일한 duck-typing 계약 — get_combat_defense()가
## 있으면 그것을, 없으면 stats(Resource).defense 필드를 읽는다.
func _resolve_target_defense(target: Node) -> float:
	if target.has_method("get_combat_defense"):
		return target.get_combat_defense()
	var target_stats: Variant = target.get("stats")
	if target_stats:
		var defense_value: Variant = target_stats.get("defense")
		if defense_value != null:
			return defense_value
	return 0.0


# TODO(vfx-artist AR-4 완료 시 교체): 투사체 자체는 타격 이펙트(AR-4) 범위라 CB-6에서는
# 색만 있는 절차적 placeholder로 대체한다.
func _setup_placeholder_sprite() -> void:
	if not _sprite or _sprite.texture != null:
		return
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.34, 0.85, 0.36, 1.0))
	_sprite.texture = ImageTexture.create_from_image(image)
