## HitFeedback 신호 → CameraShake/HitFlash 연결 브릿지 (MP-4 통합, world 전용).
##
## HitFeedbackManager(오토로드 "HitFeedback", CB-7)가 발신하는
## screen_shake_requested(intensity: int)/hit_flash_requested(target: Node) 시그널을
## 구독해 CB-8이 만든 CameraShake.shake()/HitFlash.play() 호출로 그대로 연결한다
## (godot/scripts/vfx_common/camera_shake.gd·hit_flash.gd 문서화된 인터페이스).
##
## 두 시그널은 HitFeedback.play() 한 번의 호출 안에서 화면 흔들림 → 피격 플래시 순서로
## 동기 발신되므로(hit_feedback_manager.gd play()), 화면 흔들림 강도(intensity)를 그대로
## 재사용해 플래시 프리셋을 정한다 — CameraShake.Preset과 HitFlash.Preset 모두
## 약=0/중=1/강=2로 동일하게 정의되어 있어 값 변환 없이 그대로 매핑된다.
##
## 주의: "HitFeedback" 오토로드는 본 작업 시점에 등록/파싱 오류가 있어 gameplay-dev가
## 별도로 수정 중이다(오케스트레이터 지시 — 해당 오류는 본 태스크 범위 밖). 그 오류로
## 본 스크립트가 함께 깨지지 않도록 전역 식별자 대신 get_node_or_null("/root/HitFeedback")로
## 방어적으로 조회한다 — 오토로드가 아직 없거나 로드에 실패해도 이 스크립트 자체는
## 파싱·실행 가능하며, 연동만 비활성화된다.
class_name HitFeedbackCameraBridge
extends Node

@export var camera_shake_path: NodePath

var _camera_shake: CameraShake
var _last_intensity: int = 0


func _ready() -> void:
	_camera_shake = get_node_or_null(camera_shake_path) as CameraShake
	var hit_feedback := get_node_or_null("/root/HitFeedback")
	if hit_feedback == null:
		push_warning("HitFeedback 오토로드를 찾을 수 없습니다 — 카메라 흔들림/피격 플래시 연동 비활성화")
		return
	hit_feedback.screen_shake_requested.connect(_on_screen_shake_requested)
	hit_feedback.hit_flash_requested.connect(_on_hit_flash_requested)


func _on_screen_shake_requested(intensity: int) -> void:
	_last_intensity = intensity
	if _camera_shake:
		_camera_shake.shake(intensity as CameraShake.Preset)


func _on_hit_flash_requested(target: Node) -> void:
	if target is CanvasItem:
		HitFlash.play(target, _last_intensity as HitFlash.Preset)
