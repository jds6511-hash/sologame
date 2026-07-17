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

## 오토로드는 엔진 부팅 시점(SceneTree 구성 이전)에 바로 인스턴스화되는데, 이때는
## 전역 클래스 이름 캐시(res://.godot/global_script_class_cache.cfg — .gitignore 대상이라
## 새로 clone한 저장소·CI에는 존재하지 않음)가 아직 채워지지 않은 상태일 수 있다.
## 타입 힌트를 "HitFeedbackPreset"처럼 전역 클래스 이름으로 쓰면 그 캐시에 의존하게 되어
## "Could not find type" 파싱 오류가 나므로, 경로 기반 preload로 직접 참조해 캐시 상태와
## 무관하게 항상 로드되도록 한다 (오토로드 스크립트 한정 — 조치 필요 이유).
const HitFeedbackPresetScript := preload("res://scripts/combat/hit_feedback_preset.gd")

var _hitstop_depth: int = 0
var _hitstop_restore_scale: float = 1.0


## 프리셋 하나를 즉시 재생한다. target을 넘기면 피격 플래시 신호에 함께 전달된다.
func play(preset: HitFeedbackPresetScript, at_position: Vector2, target: Node = null) -> void:
	if preset == null:
		return
	screen_shake_requested.emit(preset.screen_shake_intensity)
	if target != null:
		hit_flash_requested.emit(target)
	_spawn_vfx(preset, at_position)
	_play_sfx(preset, at_position)
	_apply_hitstop(preset.hitstop_sec)  ## await 포함 — 호출자는 기다리지 않아도 됨(발사 후 잊기)


func _spawn_vfx(preset: HitFeedbackPresetScript, at_position: Vector2) -> void:
	if preset.vfx_scene == null:
		return
	var vfx: Node = preset.vfx_scene.instantiate()
	if vfx is Node2D:
		vfx.global_position = at_position
	_resolve_effect_parent().add_child(vfx)


func _play_sfx(preset: HitFeedbackPresetScript, at_position: Vector2) -> void:
	play_sfx(preset.sfx_stream, at_position)


## 프리셋에 묶이지 않은 단발성 SFX 재생 — 스킬 명중/회피/피격/몬스터 사망/포션 사용 등
## scripts/combat·scripts/player 각 트리거 지점에서 공용으로 호출한다(중복 구현 방지).
func play_sfx(stream: AudioStream, at_position: Vector2) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = at_position
	player.bus = "SFX"
	_resolve_effect_parent().add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## 이펙트/사운드를 붙일 부모 노드를 정한다. 평상시엔 current_scene이지만, GUT 헤드리스
## 테스트 환경은 메인 씬을 띄우지 않아 current_scene이 계속 null이다 — 이 경우 이 오토로드
## 자신(항상 트리에 존재)에 부착하는 것으로 폴백해 add_child 호출이 죽지 않게 한다.
func _resolve_effect_parent() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		return current_scene
	return self


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
