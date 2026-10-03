extends RiftSlimeAcidPool
## 예고·활성 표시와 물리 판정 모두 같은 반경을 사용한다.

var radius_px := 40.0


func _ready() -> void:
	super._ready()
	_shape.shape = _shape.shape.duplicate()
	_sprite.hide()
	queue_redraw()


func configure(
	attack: float,
	ratio: float,
	warning: float,
	duration: float,
	radius_tiles: float,
	tile_size: float,
	formula: DamageFormulaData
) -> void:
	radius_px = radius_tiles * tile_size
	super.configure(attack, ratio, warning, duration, radius_tiles, tile_size, formula)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var caster = get_parent()
	if not is_instance_valid(caster) or not caster._hazard_target_alive():
		monitoring = false
		queue_free()
		return
	super._physics_process(delta)
	queue_redraw()


func _draw() -> void:
	var color := Color(0.65, 0.35, 0.9, 0.5) if _is_active else Color(1.0, 0.65, 0.1, 0.25)
	draw_circle(Vector2.ZERO, radius_px, color)
	draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 48, Color(1.0, 0.7, 0.2, 0.9), 2.0)
