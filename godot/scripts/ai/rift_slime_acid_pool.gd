## 균열 점액 자폭 산성 웅덩이 — m2-monster-spec.md 3-3장 "약/중" 등급 마무리 사망 시
## 생성되는 지속 피해 판정(M2 후반 통합, 2026-07-17. rift_slime_monster.gd가 사망 지점에
## 스폰하고 configure()로 파라미터를 주입한다).
##
## 상태 전이(spec 3-3장 그대로):
##   [스폰] --(예고 self_destruct_telegraph_sec, 판정 없음)--> [활성] --(active_sec 동안
##   반경 self_destruct_radius_tiles 내 지속 피해)--> [소멸]
##
## CB-3/CB-4 연동: MonsterAttackResolver(scripts/combat, 수정 없음 — 계약만 그대로 따름)와
## 동일하게 "대상이 is_invincible()이면 무시, 아니면 take_damage() 호출" 계약을 쓴다.
## 데미지 계산은 DamageCalculator(CB-3)를 그대로 재사용하되, skill_coefficient 자리에
## "이번 틱 길이(초) x 초당 피해 비율(self_destruct_dps_ratio)"을 넣어 지속 피해가
## delta에 비례하게 만든다 — 몬스터 공격력 자체(attack_power)는 그대로 두고 계수만
## 시간 조각으로 스케일링하는 방식.
##
## 구현 단순화(assumption, ai-dev): spec에 틱 간격 수치가 없어 TICK_INTERVAL_SEC(0.25초)를
## 임시로 정했다. 또한 지속 피해는 "위험지대 접촉 피해"로 보고 take_hit()(경직·무적 부여)은
## 호출하지 않는다 — 웅덩이 위에 서 있을 때마다 매 틱 강제 경직이 걸리면 조작감을 해치고,
## combat.md에도 웅덩이의 경직 여부가 명시되어 있지 않다. 대신 대상의 is_invincible()은
## 그대로 확인해(회피·피격 무적 중에는 피해 없음) 기존 무적 규칙과 일관되게 동작한다.
## 두 값 모두 systems-designer 확인 시 조정 대상(디렉터 결정 사항 아님).
class_name RiftSlimeAcidPool
extends Area2D

const TICK_INTERVAL_SEC := 0.25

var _monster_attack_power: float = 0.0
var _dps_ratio: float = 0.5
var _telegraph_sec: float = 0.3
var _duration_sec: float = 2.0
var _formula_data: DamageFormulaData

var _telegraph_timer: float = 0.0
var _active_timer: float = 0.0
var _tick_timer: float = 0.0
var _is_active: bool = false

@onready var _shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var _sprite: Sprite2D = get_node_or_null("Sprite")


func _ready() -> void:
	monitoring = false
	_telegraph_timer = _telegraph_sec
	_setup_placeholder_sprite()


## 스폰 직후(add_child 전 또는 직후, _ready 이전이라도 무방)에 호출해 파라미터를 주입한다.
func configure(
	monster_attack_power: float,
	dps_ratio: float,
	telegraph_sec: float,
	duration_sec: float,
	radius_tiles: float,
	tile_size_px: float,
	formula_data: DamageFormulaData
) -> void:
	_monster_attack_power = monster_attack_power
	_dps_ratio = dps_ratio
	_telegraph_sec = telegraph_sec
	_duration_sec = duration_sec
	_formula_data = formula_data
	_telegraph_timer = telegraph_sec
	if _shape and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = radius_tiles * tile_size_px


func _physics_process(delta: float) -> void:
	if not _is_active:
		_telegraph_timer -= delta
		if _telegraph_timer <= 0.0:
			_activate()
		return

	_active_timer -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += TICK_INTERVAL_SEC
		_apply_tick_damage(TICK_INTERVAL_SEC)
	if _active_timer <= 0.0:
		queue_free()


func _activate() -> void:
	_is_active = true
	_active_timer = _duration_sec
	monitoring = true
	if _sprite:
		_sprite.modulate = Color(0.3, 0.9, 0.3, 0.85)


func _apply_tick_damage(tick_sec: float) -> void:
	if _formula_data == null:
		return
	for body in get_overlapping_bodies():
		if not body.has_method("take_damage"):
			continue
		if body.has_method("is_invincible") and body.is_invincible():
			continue
		var target_defense := _resolve_target_defense(body)
		var damage := DamageCalculator.calculate_damage(
			_monster_attack_power,
			_dps_ratio * tick_sec,
			target_defense,
			_formula_data,
			false,
			false
		)
		body.take_damage(damage, "약", self)


## PlayerAttackResolver/MonsterAttackResolver와 동일한 duck-typing 계약(방향만 "웅덩이가
## 대상 방어력을 읽는" 쪽) — get_combat_defense()가 있으면 그것을, 없으면 stats.defense를 쓴다.
func _resolve_target_defense(target: Node) -> float:
	if target.has_method("get_combat_defense"):
		return target.get_combat_defense()
	var target_stats: Variant = target.get("stats")
	if target_stats:
		var defense_value: Variant = target_stats.get("defense")
		if defense_value != null:
			return defense_value
	return 0.0


# TODO(vfx-artist 후속 작업 완료 시 교체): 산성 웅덩이 자체는 이펙트 범위라 색만 있는
# 절차적 placeholder로 대체한다(rift_slime_projectile.gd와 동일 패턴).
func _setup_placeholder_sprite() -> void:
	if not _sprite or _sprite.texture != null:
		return
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.35, 0.75, 0.25, 0.5))
	_sprite.texture = ImageTexture.create_from_image(image)
