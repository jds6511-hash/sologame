## 피격 화이트 플래시 공용 헬퍼 (CB-8) — godot/shaders/hit_flash.gdshader를 재생한다.
##
## 대상 CanvasItem(Sprite2D, AnimatedSprite2D 등)에 ShaderMaterial을 자동으로 부착하고,
## flash_strength 유니폼을 강도 → 0으로 Tween 애니메이션한다. 지속시간·강도는 이 헬퍼가
## 책임지며, 셰이더 자체는 "그 순간의 강도"만 그린다(godot/shaders/hit_flash.gdshader 주석 참조).
##
## 사용 예 (HitFeedback(CB-7) 등 다른 모듈에서 호출):
##   HitFlash.play(monster_sprite, HitFlash.Preset.MEDIUM)          # 히트스톱 '중' 프리셋
##   HitFlash.play_custom(boss_sprite, 0.8, 0.05, Color(1, 1, 1))   # 커스텀 강도/지속시간
##
## 프리셋 기본값 근거: STYLE_GUIDE.md 6-1장이 명시한 값은 MEDIUM(히트스톱 '중'과 동기,
## 약 0.06초)뿐이다. WEAK/STRONG은 combat.md 5-3장의 히트스톱 3단(0.03s/0.06s/0.10s) 비율에
## 맞춰 tech-artist가 보간한 값이며, M2 손맛 튜닝(디렉터 승인 G2-3) 대상이다.
##
## 이 스크립트는 CB-7 코드를 직접 수정하지 않는다 — 통합은 후속 패스.
class_name HitFlash
extends RefCounted

enum Preset { WEAK, MEDIUM, STRONG }

## 프리셋별 강도(0~1) — combat.md 5-3장 히트스톱 3단과 매칭.
const PRESET_INTENSITY: Dictionary = {
	Preset.WEAK: 0.6,
	Preset.MEDIUM: 1.0,
	Preset.STRONG: 1.0,
}
## 프리셋별 지속시간(초) — MEDIUM=0.06은 STYLE_GUIDE 6-1장 확정값, WEAK/STRONG은 위 근거 설명 참조.
const PRESET_DURATION_SEC: Dictionary = {
	Preset.WEAK: 0.03,
	Preset.MEDIUM: 0.06,
	Preset.STRONG: 0.10,
}

const _SHADER: Shader = preload("res://shaders/hit_flash.gdshader")


## 히트스톱 프리셋에 대응하는 화이트 플래시 재생.
static func play(target: CanvasItem, preset: Preset) -> void:
	play_custom(target, PRESET_INTENSITY[preset], PRESET_DURATION_SEC[preset])


## 임의의 강도(0~1)·지속시간(초)·색으로 플래시 재생. color 기본값은 STYLE_GUIDE 6-1 고정색
## #ffffff — 흰색 외의 값은 피격 피드백 용도가 아닌 별도 연출에서만 사용할 것.
static func play_custom(
	target: CanvasItem,
	intensity: float = 1.0,
	duration_sec: float = 0.06,
	color: Color = Color.WHITE
) -> void:
	if target == null or not target.is_inside_tree():
		return
	var material := _ensure_material(target)
	material.set_shader_parameter("flash_color", color)
	material.set_shader_parameter("flash_strength", intensity)
	var tween := target.create_tween()
	tween.tween_method(_make_strength_setter(material), intensity, 0.0, duration_sec)


static func _make_strength_setter(material: ShaderMaterial) -> Callable:
	return func(value: float) -> void: material.set_shader_parameter("flash_strength", value)


static func _ensure_material(target: CanvasItem) -> ShaderMaterial:
	var material := target.material as ShaderMaterial
	if material == null or material.shader != _SHADER:
		material = ShaderMaterial.new()
		material.shader = _SHADER
		target.material = material
	return material
