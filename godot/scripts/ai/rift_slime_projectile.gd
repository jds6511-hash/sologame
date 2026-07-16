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

@onready var _sprite: Sprite2D = get_node_or_null("Sprite")


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	_setup_placeholder_sprite()


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
	queue_free()


# TODO(vfx-artist AR-4 완료 시 교체): 투사체 자체는 타격 이펙트(AR-4) 범위라 CB-6에서는
# 색만 있는 절차적 placeholder로 대체한다.
func _setup_placeholder_sprite() -> void:
	if not _sprite or _sprite.texture != null:
		return
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.34, 0.85, 0.36, 1.0))
	_sprite.texture = ImageTexture.create_from_image(image)
