## 화면 흔들림 공용 컴포넌트 (CB-8) — Camera2D의 자식 노드로 배치해 사용한다.
##
## 용도: 히트스톱 3단(docs/design/systems/combat.md 5-3장)에 대응하는 화면 흔들림 강도 3단을
## 재생한다. STYLE_GUIDE.md 6-2장 "히트스톱 연동" 규칙 — 약=흔들림 없음 / 중=약 / 강=중.
##
## 사용법 (HitFeedback(CB-7) 등 다른 모듈에서 호출):
##   1. 전투 카메라(Camera2D) 밑에 이 스크립트를 붙인 Node를 자식으로 추가한다.
##      씬 트리 예: Camera2D -> CameraShake
##   2. 히트 발생 시 `$Camera2D/CameraShake.shake(CameraShake.Preset.STRONG)` 호출.
##      프리셋 밖의 값이 필요하면 `shake_custom(amplitude_px, duration_sec)`.
##   3. shake(Preset.WEAK)는 정의상 진폭 0 — 호출해도 항상 무동작이다(3단을 분기 없이
##      동일한 호출 형태로 다루기 위한 설계).
##
## 구현 노트:
## - 부모 노드가 Camera2D여야 하며, Camera2D.offset 속성에 흔들림을 얹는다.
## - 연속 타격 시 더 강한 흔들림이 약한 흔들림을 덮어쓴다(진폭 기준 비교) — 남은 흔들림이 있는
##   상태에서 더 약한 프리셋이 호출되면 무시한다.
## - 히트스톱 구현 방식(Engine.time_scale 축소 또는 SceneTree.paused)과 무관하게 항상 실제
##   경과 시간(real time) 기준으로 재생되도록 Time.get_ticks_usec()로 델타를 직접 계산하고,
##   process_mode = PROCESS_MODE_ALWAYS로 설정한다 — 히트스톱이 SceneTree를 멈추는 방식이어도
##   흔들림 연출은 끊기지 않는다. (CB-7의 실제 히트스톱 구현 방식은 아직 미확정이라 두 경우
##   모두에 대응하도록 방어적으로 설계했다.)
##
## 이 스크립트는 CB-7 코드를 직접 수정하지 않는다 — 통합은 후속 패스.
class_name CameraShake
extends Node

enum Preset { WEAK, MEDIUM, STRONG }

## 프리셋별 진폭(px, 카메라 로컬 기준) — 약 프리셋은 문서상 "흔들림 없음"이므로 0.
const PRESET_AMPLITUDE_PX: Dictionary = {
	Preset.WEAK: 0.0,
	Preset.MEDIUM: 2.0,
	Preset.STRONG: 5.0,
}
## 프리셋별 지속시간(초) — combat.md 5-3장 히트스톱 3단(0.03s/0.06s/0.10s)과 동일하게 맞춘다.
const PRESET_DURATION_SEC: Dictionary = {
	Preset.WEAK: 0.0,
	Preset.MEDIUM: 0.06,
	Preset.STRONG: 0.10,
}

var _trauma_duration_sec: float = 0.0
var _trauma_time_left_sec: float = 0.0
var _trauma_amplitude_px: float = 0.0
var _last_tick_usec: int = 0
var _rng := RandomNumberGenerator.new()

@onready var _camera: Camera2D = get_parent() as Camera2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if _camera == null:
		push_warning("CameraShake는 Camera2D의 자식 노드로 배치해야 합니다.")


## 히트스톱 프리셋에 대응하는 흔들림 재생.
func shake(preset: Preset) -> void:
	shake_custom(PRESET_AMPLITUDE_PX[preset], PRESET_DURATION_SEC[preset])


## 임의의 진폭(px)·지속시간(초)으로 흔들림 재생 — 프리셋 밖의 연출(궁극기 등)이 필요할 때 사용.
func shake_custom(amplitude_px: float, duration_sec: float) -> void:
	if amplitude_px <= 0.0 or duration_sec <= 0.0:
		return
	if _trauma_time_left_sec > 0.0 and amplitude_px < _trauma_amplitude_px:
		return
	_trauma_amplitude_px = amplitude_px
	_trauma_duration_sec = duration_sec
	_trauma_time_left_sec = duration_sec


func _process(_delta: float) -> void:
	if _camera == null:
		return
	var real_delta_sec := _consume_real_delta_sec()
	if _trauma_time_left_sec <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	_trauma_time_left_sec = max(_trauma_time_left_sec - real_delta_sec, 0.0)
	var falloff := _trauma_time_left_sec / _trauma_duration_sec
	var current_amplitude_px := _trauma_amplitude_px * falloff
	_camera.offset = (
		Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * current_amplitude_px
	)
	if _trauma_time_left_sec <= 0.0:
		_camera.offset = Vector2.ZERO


## Engine.time_scale(히트스톱 구현 방식 중 하나)의 영향을 받지 않는 실제 경과 시간(초).
func _consume_real_delta_sec() -> float:
	var now_usec := Time.get_ticks_usec()
	if _last_tick_usec == 0:
		_last_tick_usec = now_usec
	var delta_sec := (now_usec - _last_tick_usec) / 1_000_000.0
	_last_tick_usec = now_usec
	return delta_sec
