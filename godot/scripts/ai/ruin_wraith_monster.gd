extends ImpMonster
## 기존 재배치 행동에 고정 원점 장판을 추가한다. 장판은 이 개체의 자식으로 소유한다.

const HAZARD = preload("res://scenes/monsters/ruin_wraith_hazard.tscn")
const FORMULA = preload("res://data/combat/damage_formula.tres")
const HAZARD_COOLDOWN := 7.0
var _hazard_cooldown := 0.0
var _hazard_pending := false


func _ready() -> void:
	super._ready()
	died.connect(_clear_hazards)


func _physics_process(delta: float) -> void:
	if not _hazard_target_alive():
		_clear_hazards()
		if is_instance_valid(target) and target.has_method("is_dead") and target.is_dead():
			target = null
	_hazard_cooldown = maxf(0.0, _hazard_cooldown - delta)
	super._physics_process(delta)
	if state == State.CHASE and not is_staggered():
		cast_hazard()


func _hazard_target_alive() -> bool:
	return (
		is_inside_tree()
		and not is_queued_for_deletion()
		and not is_dead()
		and is_instance_valid(target)
		and not target.is_queued_for_deletion()
		and not (target.has_method("is_dead") and target.is_dead())
	)


func cast_hazard() -> bool:
	if not _hazard_target_alive() or _hazard_pending or _hazard_cooldown > 0.0:
		return false
	if not is_target_in_range_tiles(stats.perception_range_tiles):
		return false
	_hazard_pending = true
	_hazard_cooldown = HAZARD_COOLDOWN
	_add_hazard.call_deferred(target.global_position)
	return true


func _add_hazard(center: Vector2) -> void:
	_hazard_pending = false
	if not _hazard_target_alive():
		return
	var pool = HAZARD.instantiate()
	pool.name = "WraithHazard"
	pool.top_level = true
	add_child(pool)
	pool.global_position = center
	pool.configure(effective_attack_power(), 0.6, 1.0, 2.0, 2.5, stats.tile_size_px, FORMULA)


func _clear_hazards() -> void:
	for child in get_children():
		if child is RiftSlimeAcidPool:
			child.set_physics_process(false)
			child.set_deferred("monitoring", false)
			child.queue_free()
