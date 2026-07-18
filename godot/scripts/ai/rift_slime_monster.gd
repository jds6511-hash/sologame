## 균열 점액 (HitFeedback 강 대표) — m2-monster-spec.md 3-3장.
##
## 상태 전이 (spec 3-3장 원문 그대로):
##   [배회] --(인지범위 4타일 진입)--> [조준](예고 0.7초, 바닥 착탄 지점 표시) --> [투사체 발사]
##   [투사체 발사] --(쿨다운 1.2초)--> [조준] 재시도 (사거리 5타일 이내인 한 반복)
##   [조준/투사체] --(사거리 이탈)--> [배회] 복귀
##   [HP 0, 직전 피격이 "강" 등급] --> [핵 파괴] : 자폭 없음 + 재료 드랍 100% 확정
##   [HP 0, 직전 피격이 "약/중" 등급] --> [자폭] : 산성 웅덩이 생성(예고 0.3초 후 판정)
##
## CB-3/CB-4 연동 지점: 코어 파괴(core_broken)·자폭(self_destructed) 시그널은
## "어느 분기로 죽었는가"만 알린다. 재료 100% 드랍(economy IT-2, MAT-SLIME-CORE 지급)은
## 아이템/드랍 시스템(scripts/items, 본 태스크 범위 밖) 몫이라 시그널만 제공한다.
##
## 산성 웅덩이 실제 지속 피해(M2 후반 통합, 2026-07-17): self_destructed 분기에서
## RiftSlimeAcidPool(scripts/ai/rift_slime_acid_pool.gd) 씬을 사망 지점에 스폰한다.
## DamageCalculator(CB-3)를 그대로 재사용해 매 틱 피해를 계산하고, MonsterAttackResolver와
## 동일한 is_invincible() 확인 후 take_damage() 호출 계약을 따른다(자세한 내용은 해당
## 스크립트 헤더 참조). core_broken 분기는 spec 3-3장 그대로 "자폭 없음" — 죽는 순간
## _die()가 곧바로 호출되어 별도의 몬스터 측 경직 반응 없이 즉시 소멸한다(체급별 넉백
## 저항 등 MobStaggerComponent 배선은 애초에 치명타(강)로 죽는 마지막 타격에는 적용되지
## 않는다 — take_damage()가 hp<=0 판정 시 stagger 등록 전에 _die()로 분기하기 때문).
##
## 행동 블록 조합(2개): 배회 → 투사체(조준+발사, 자폭은 사망 시 1회성 파생 동작이라
## 블록 수에 포함하지 않음 — spec 3-3장 그대로).
class_name RiftSlimeMonster
extends MonsterBase

signal projectile_fired(aim_position: Vector2)
signal core_broken  ## 강 등급 마무리 — 자폭 없음, 재료 100% (economy 연동은 IT-2 후속)
signal self_destructed(acid_pool_position: Vector2)  ## 약/중 등급 마무리 — 산성 웅덩이 스텁

enum State { WANDER, AIM, COOLDOWN }

## 투사체 씬 — 미할당(null)이면 판정 대신 projectile_fired 시그널만 발생(테스트/미배선 상황 대응)
@export var projectile_scene: PackedScene

## 자폭 산성 웅덩이 씬(RiftSlimeAcidPool) — 미할당(null)이면 self_destructed 시그널만
## 발생하고 실제 판정은 생성하지 않는다(테스트/미배선 상황 대응, 위 투사체와 동일 패턴).
@export var acid_pool_scene: PackedScene

## 웅덩이 지속 피해 계산에 쓰는 데미지 공식(CB-3 공용 리소스, res://data/combat/damage_formula.tres).
@export var formula_data: DamageFormulaData

var state: State = State.WANDER

var _wander_dir := Vector2.ZERO
var _wander_timer: float = 0.0
var _aim: AimFireBlock
var _aim_point := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_aim = AimFireBlock.new()
	_aim.telegraph_sec = stats.projectile_telegraph_sec
	_aim.cooldown_sec = stats.projectile_cooldown_sec
	_aim.aim_started.connect(_on_aim_started)
	_aim.fired.connect(_on_aim_fired)
	_aim.cooldown_ended.connect(_on_aim_cooldown_ended)
	_wander_dir = random_wander_direction()
	_wander_timer = randf_range(1.0, 2.5)


func _physics_process(delta: float) -> void:
	if is_dead():
		return
	if is_staggered():
		velocity = _knockback_velocity
		_clamp_velocity_to_finite()
		move_and_slide()
		return
	match state:
		State.WANDER:
			_process_wander(delta)
			if is_target_in_range_tiles(stats.perception_range_tiles):
				_start_aim()
		State.AIM, State.COOLDOWN:
			velocity = Vector2.ZERO
			_aim.update(delta)
			if target == null or not is_target_in_range_tiles(stats.projectile_range_tiles):
				_aim.reset()
				state = State.WANDER
				_play_animation("idle")
	_clamp_velocity_to_finite()
	move_and_slide()


func _process_wander(delta: float) -> void:
	## spec: 배회 속도 0.6타일/초 — "거의 제자리" 이동이므로 idle 애니메이션을 유지한다.
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_dir = random_wander_direction()
		_wander_timer = randf_range(1.0, 2.5)
	velocity = _wander_dir * stats.tiles_to_px(stats.wander_speed_tiles)
	_update_facing(velocity)
	_play_animation("idle")


func _start_aim() -> void:
	if target:
		_aim_point = target.global_position  ## 조준 시작 시점의 착탄 지점을 고정 표시
	_aim.start_aim()


func _on_aim_started() -> void:
	state = State.AIM
	_play_animation("attack", _aim_point - global_position)


func _on_aim_fired() -> void:
	state = State.COOLDOWN
	_play_animation("idle")
	projectile_fired.emit(_aim_point)
	_spawn_projectile(_aim_point)


## 쿨다운이 끝나면 사거리 이내인 한 최신 목표 위치로 조준을 다시 시작한다.
## 사거리를 벗어난 경우는 _physics_process의 범위 체크가 다음 프레임에 배회로 되돌린다.
func _on_aim_cooldown_ended() -> void:
	if target and is_target_in_range_tiles(stats.projectile_range_tiles):
		_start_aim()


func _spawn_projectile(aim_point: Vector2) -> void:
	if projectile_scene == null:
		return
	var proj := projectile_scene.instantiate() as Node2D
	get_tree().root.add_child(proj)
	proj.global_position = global_position
	if proj.has_method("launch"):
		proj.call("launch", aim_point, stats.tiles_to_px(stats.projectile_speed_tiles))


# --- 사망 분기 (마무리 타격 등급에 따라 핵 파괴/자폭 — spec 3-3장) ---


func _die() -> void:
	if last_hit_grade == "강":
		core_broken.emit()
	else:
		self_destructed.emit(global_position)
		_spawn_acid_pool(global_position)
	super._die()


## self_destructed 분기 전용 — 실제 산성 웅덩이(RiftSlimeAcidPool)를 사망 지점에 스폰하고
## 몬스터 파라미터(공격력·DPS 비율·예고/지속 시간·반경)를 그대로 넘긴다.
func _spawn_acid_pool(spawn_position: Vector2) -> void:
	if acid_pool_scene == null:
		return
	var pool := acid_pool_scene.instantiate() as Node2D
	get_tree().root.add_child(pool)
	pool.global_position = spawn_position
	if pool.has_method("configure"):
		pool.call(
			"configure",
			stats.attack_power,
			stats.self_destruct_dps_ratio,
			stats.self_destruct_telegraph_sec,
			stats.self_destruct_duration_sec,
			stats.self_destruct_radius_tiles,
			stats.tile_size_px,
			formula_data
		)
