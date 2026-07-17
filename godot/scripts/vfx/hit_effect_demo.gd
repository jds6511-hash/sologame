## 타격 이펙트 데모 씬 (AR-4) — 소/중/대 3규격을 키 입력으로 확인.
##
## 조작:
##   1 = 소 (기본 공격 대응, ≤0.2초 / 파티클 ≤32)
##   2 = 중 (일반 스킬 대응, ≤0.5초 / 파티클 ≤32)
##   3 = 대 (궁극기 대응, ≤1.2초 / 파티클 ≤64)
## 각 키는 화면 중앙(TargetSprite 위치)에 해당 이펙트를 1회 재생한다.
##
## 실제 전투 연동은 HitFeedbackManager.play(preset, at_position, target) 호출 시 preset.vfx_scene
## 슬롯(data\combat\hitfeedback_weak\medium\strong.tres)에 이미 연결된 본 이펙트 씬이 자동으로
## 재생하는 방식이며, 이 데모는 그 결과물을 독립적으로 미리 확인하기 위한 것이다.
extends Node2D

const HitEffectSmallScene := preload("res://scenes/vfx/hit_effect_small.tscn")
const HitEffectMediumScene := preload("res://scenes/vfx/hit_effect_medium.tscn")
const HitEffectLargeScene := preload("res://scenes/vfx/hit_effect_large.tscn")

@onready var _spawn_point: Node2D = $TargetSprite
@onready var _status_label: Label = $UILayer/StatusLabel


func _ready() -> void:
	_update_status_label("대기 중 — 1(소) / 2(중) / 3(대) 키를 눌러 확인")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_1:
			_spawn(HitEffectSmallScene, "소 (기본 공격 대응, ≤0.2초 / 파티클 ≤32)")
		KEY_2:
			_spawn(HitEffectMediumScene, "중 (일반 스킬 대응, ≤0.5초 / 파티클 ≤32)")
		KEY_3:
			_spawn(HitEffectLargeScene, "대 (궁극기 대응, ≤1.2초 / 파티클 ≤64)")


func _spawn(effect_scene: PackedScene, label_text: String) -> void:
	var vfx: Node2D = effect_scene.instantiate()
	vfx.global_position = _spawn_point.global_position
	add_child(vfx)
	_update_status_label("트리거: %s" % label_text)


func _update_status_label(status_text: String) -> void:
	_status_label.text = "[AR-4 데모] 1=소 · 2=중 · 3=대\n%s" % status_text
