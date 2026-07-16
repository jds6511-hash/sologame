## 타격 피드백 공용 모듈 (CB-7, combat.md 5-3·9-1장).
##
## 오토로드 싱글턴("HitFeedback")으로 등록해 어디서든 HitFeedback.play(preset, ...)
## 한 줄로 히트스톱·화면 흔들림·피격 플래시·이펙트/사운드를 한꺼번에 트리거한다.
## 스킬·몬스터 종류는 전혀 알 필요 없이 프리셋(HitFeedbackPreset) 하나만 고르면 되므로,
## combat.md 9-1장 "신규 스킬·몬스터는 프리셋을 고르기만 해도 기본 타격감이 보장된다"
## 요구를 그대로 만족한다.
##
## 화면 흔들림/화이트 플래시의 실제 셰이더·카메라 연출은 CB-8(tech-artist) 담당이며,
## 이 모듈은 screen_shake_requested/hit_flash_requested 시그널만 발신한다 —
## CB-8은 이 두 시그널을 구독하기만 하면 된다.
class_name HitFeedbackManager
extends Node

## CB-8이 구독: 화면 흔들림 강도(HitFeedbackPreset.screen_shake_intensity 그대로 전달)
signal screen_shake_requested(intensity: int)
## CB-8이 구독: 피격 화이트 플래시를 적용할 대상 노드
signal hit_flash_requested(target: Node)

var _hitstop_depth: int = 0
var _hitstop_restore_scale: float = 1.0


## 프리셋 하나를 즉시 재생한다. target을 넘기면 피격 플래시 신호에 함께 전달된다.
func play(preset: HitFeedbackPreset, at_position: Vector2, target: Node = null) -> void:
	if preset == null:
		return
	screen_shake_requested.emit(preset.screen_shake_intensity)
	if target != null:
		hit_flash_requested.emit(target)
	_spawn_vfx(preset, at_position)
	_play_sfx(preset, at_position)
	_apply_hitstop(preset.hitstop_sec)  ## await 포함 — 호출자는 기다리지 않아도 됨(발사 후 잊기)


func _spawn_vfx(preset: HitFeedbackPreset, at_position: Vector2) -> void:
	if preset.vfx_scene == null:
		return
	var vfx: Node = preset.vfx_scene.instantiate()
	if vfx is Node2D:
		vfx.global_position = at_position
	get_tree().current_scene.add_child(vfx)


func _play_sfx(preset: HitFeedbackPreset, at_position: Vector2) -> void:
	if preset.sfx_stream == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = preset.sfx_stream
	player.global_position = at_position
	get_tree().current_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## 히트스톱: Engine.time_scale을 잠깐 0으로 낮췄다가 실시간(time_scale 무관) 타이머로
## 복원한다. 여러 타격이 겹쳐도(_hitstop_depth) 가장 늦게 끝나는 쪽이 복원을 맡는다.
func _apply_hitstop(duration_sec: float) -> void:
	if duration_sec <= 0.0:
		return
	if _hitstop_depth == 0:
		_hitstop_restore_scale = Engine.time_scale
	_hitstop_depth += 1
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration_sec, true, false, true).timeout
	_hitstop_depth -= 1
	if _hitstop_depth <= 0:
		_hitstop_depth = 0
		Engine.time_scale = _hitstop_restore_scale
