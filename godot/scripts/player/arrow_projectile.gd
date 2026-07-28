## 궁수 화살 투사체 (M3 C-5) — m3-archer-skills.md 5·6장.
##
## M2에서 검증된 균열 점액 투사체(scripts/ai/rift_slime_projectile.gd) 구조를 그대로 계승한
## 플레이어측 투사체다. 재사용/신규 델타는 m3-archer-skills 6장 표를 따른다:
##
## [재사용 — 6-1장]
##   - 등속 직선 이동 + 사거리 소진 시 소멸(`global_position += _velocity*delta`)
##   - 중력 없음(탑다운 직선 근사 — 포물선 연출은 vfx-artist C-7 영역, 판정 밸런스 무영향)
##   - Area2D + body_entered 명중 판정
##   - configure() 주입 후 launch() 발사라는 2단 계약(스폰 주체가 파라미터를 주입)
##   - 타일 16px 변환 규칙
##
## [신규 델타 — 6-2장]
##   ① 충돌 레이어/마스크 반전: 몬스터(레이어 3)를 맞힌다 — 씬에서 collision_mask=4로 설정,
##      플레이어(레이어 2)는 마스크에 없어 자기 피격이 원천적으로 불가능하다.
##   ② 플레이어 데미지 계약: 직접 데미지를 계산하지 않고 arrow_hit_landed 시그널로 명중을
##      알린다 — PlayerController가 이를 attack_hit으로 중계해 PlayerAttackResolver(CB-3)가
##      계수·강화 배율·치명타·방어 감산·히트피드백을 일괄 처리한다(기존 근접 파이프라인 재사용).
##   ③ 치명타 판정: ②의 리졸버 경로에서 화살 명중 1회당 독립 굴림(속사 3발 = 3굴림,
##      관통 폭사는 관통한 적마다 굴림).
##   ④ 관통 파라미터: ArrowSpec.pierce_count(0=비관통 / N=최대 N체 / -1=무제한). 관통 중에는
##      queue_free 대신 이동을 지속하고 _hit_bodies로 같은 대상 재타격을 막는다.
##   ⑤ 사거리 소멸: target_point까지가 아니라 "방향 + 최대 사거리"로 발사한다.
##   ⑥ 투사체 속도 상향: 기본 16 / 정밀 20 / 궁극기 24 타일·초(ArrowSpec 데이터).
class_name ArrowProjectile
extends Area2D

## 화살이 대상에 명중했을 때 발신. action은 판정 주체 리소스(ArcherAttackStep 또는
## ArcherSkillData)로, PlayerController가 그대로 attack_hit에 실어 리졸버로 넘긴다.
signal arrow_hit_landed(action: Resource, body: Node)

var _velocity := Vector2.ZERO
var _remaining_distance: float = 0.0
var _speed_px: float = 0.0
## 판정 주체 리소스(계수·히트스톱 프리셋 보유) — 데미지 계산은 리졸버가 담당한다.
var _action: Resource = null
## 남은 명중 가능 대상 수. -1은 무제한 관통(관통 폭사).
var _pierce_remaining: int = 0
## 이미 명중한 대상 — 관통 중 같은 몸에 중복 판정이 나지 않게 한다(6-2장 명중 판정 상세).
var _hit_bodies: Array[Node] = []

@onready var _sprite: Sprite2D = get_node_or_null("Sprite")
@onready var _shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)


## 스폰 직후(launch 전)에 호출해 판정 주체·투사체 규격을 주입한다(RiftSlimeProjectile.configure와
## 동일 패턴). 히트박스 폭과 placeholder 색도 규격에서 적용한다.
func configure(action: Resource, spec: ArrowSpec, tile_size_px: float) -> void:
	_action = action
	if spec == null:
		return
	_pierce_remaining = spec.pierce_count
	_speed_px = spec.speed_px_per_sec(tile_size_px)
	_apply_hitbox_width(spec.width_tiles * tile_size_px)
	_apply_placeholder_sprite(spec.width_tiles * tile_size_px, spec.visual_color)


## direction 방향으로 range_px 만큼 등속 직선 이동한다. 사거리를 다 쓰면 명중이 없어도 소멸한다
## (6-2장 델타 ⑤). 방향이 0이거나 오염된 값이면 발사하지 않고 즉시 정리한다.
func launch(direction: Vector2, range_px: float) -> void:
	if not direction.is_finite() or direction.length_squared() <= 0.0001 or range_px <= 0.0:
		queue_free()
		return
	var unit := direction.normalized()
	_velocity = unit * _speed_px
	_remaining_distance = range_px
	rotation = unit.angle()


func _physics_process(delta: float) -> void:
	if _velocity == Vector2.ZERO:
		return  ## 아직 발사되지 않음(configure 직후 프레임) — 이동/소멸 판정 없음
	var step := _velocity * delta
	global_position += step
	_remaining_distance -= step.length()
	if _remaining_distance <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body in _hit_bodies:
		return  ## 관통 중 같은 대상 재타격 방지
	_hit_bodies.append(body)
	arrow_hit_landed.emit(_action, body)
	if _pierce_remaining < 0:
		return  ## 무제한 관통 — 사거리 만료로만 소멸(관통 폭사)
	## pierce_count 0(비관통)과 1은 모두 "1체 명중 후 소멸"이다.
	_pierce_remaining = maxi(_pierce_remaining - 1, 0)
	if _pierce_remaining <= 0:
		queue_free()


## 화살 폭(타일→px)을 원형 히트박스 반지름으로 반영한다. 씬의 공용 sub_resource를 그대로
## 수정하면 모든 화살 인스턴스가 함께 바뀌므로, 인스턴스마다 새 Shape를 만들어 대입한다.
func _apply_hitbox_width(width_px: float) -> void:
	if _shape_node == null or width_px <= 0.0:
		return
	var circle := CircleShape2D.new()
	circle.radius = width_px * 0.5
	_shape_node.shape = circle


# TODO(pixel-artist C-6 / vfx-artist C-7 완료 시 교체): 화살 스프라이트·궤적은 아트 영역이라
# 여기서는 균열 점액 투사체와 동일하게 색만 있는 절차적 placeholder를 쓴다
# (m3-archer-skills 6-3장 "초기 구현은 절차적 placeholder 허용").
func _apply_placeholder_sprite(width_px: float, color: Color) -> void:
	if _sprite == null:
		return
	var thickness := maxi(int(round(width_px)), 2)
	var length := thickness * 3  ## 화살은 길쭉한 형태 — 폭의 3배 길이로 근사
	var image := Image.create(length, thickness, false, Image.FORMAT_RGBA8)
	image.fill(color)
	_sprite.texture = ImageTexture.create_from_image(image)
