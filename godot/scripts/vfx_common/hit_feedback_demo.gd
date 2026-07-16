extends Node2D
## HitFeedback 셰이더 데모 씬 (CB-8) — 피격 화이트 플래시 + 화면 흔들림 3단을 키 입력으로 확인.
##
## 조작:
##   1 = 약 (히트스톱 0.03s / 흔들림 없음)
##   2 = 중 (히트스톱 0.06s / 흔들림 약)
##   3 = 강 (히트스톱 0.10s / 흔들림 중)
## 각 키는 스프라이트의 화이트 플래시(HitFlash)와 카메라 흔들림(CameraShake)을 동시에 재생한다.
##
## 실제 전투 연동은 HitFeedback(CB-7, gameplay-dev 담당)에서 이 두 헬퍼를 호출하는 방식으로
## 이뤄질 예정이며, 이 데모는 그 호출 형태(HitFlash.play / CameraShake.shake)를 그대로 보여준다.
## 이 씬은 CB-7 코드와 직접 연결되어 있지 않다 — 통합은 후속 패스.

@onready var _sprite: Sprite2D = $TargetSprite
@onready var _camera_shake: CameraShake = $Camera2D/CameraShake
@onready var _status_label: Label = $UILayer/StatusLabel


func _ready() -> void:
	_setup_placeholder_sprite()
	_update_status_label("대기 중 — 1(약) / 2(중) / 3(강) 키를 눌러 확인")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_1:
			_trigger(HitFlash.Preset.WEAK, CameraShake.Preset.WEAK, "약 (히트스톱 0.03s / 흔들림 없음)")
		KEY_2:
			_trigger(HitFlash.Preset.MEDIUM, CameraShake.Preset.MEDIUM, "중 (히트스톱 0.06s / 흔들림 약)")
		KEY_3:
			_trigger(HitFlash.Preset.STRONG, CameraShake.Preset.STRONG, "강 (히트스톱 0.10s / 흔들림 중)")


func _trigger(
	flash_preset: HitFlash.Preset, shake_preset: CameraShake.Preset, label_text: String
) -> void:
	HitFlash.play(_sprite, flash_preset)
	_camera_shake.shake(shake_preset)
	_update_status_label("트리거: %s" % label_text)


func _update_status_label(status_text: String) -> void:
	_status_label.text = "[CB-8 데모] 1=약 · 2=중 · 3=강\n%s" % status_text


## 임시 플레이스홀더 스프라이트 — AR-1/AR-2 정식 스프라이트 도입 전까지 32x32 단색 + 1px
## 아웃라인(#181425)으로 STYLE_GUIDE 3-1장 아웃라인 규칙을 흉내낸다. 색은 플레이어 식별색
## #0099db(STYLE_GUIDE 2장)를 사용 — 실제 대상(적/플레이어)과 무관한 데모용 표기.
func _setup_placeholder_sprite() -> void:
	if _sprite.texture != null:
		return
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var base_color := Color("#0099db")
	var outline_color := Color("#181425")
	for y in range(size):
		for x in range(size):
			var is_edge := x == 0 or y == 0 or x == size - 1 or y == size - 1
			image.set_pixel(x, y, outline_color if is_edge else base_color)
	_sprite.texture = ImageTexture.create_from_image(image)
