## 타격 이펙트 — 대 (AR-4). HitFeedbackPreset "강" 슬롯(hitfeedback_strong.tres) 대응.
##
## 재생 시간: 1.2초 이내 (STYLE_GUIDE.md 6-2장 "궁극기 ≤1.2초").
## 파티클 수: 이미터당 ≤64 (STYLE_GUIDE.md 6-2장 "궁극기 ≤64") — 본 씬은 Burst 44 + Spark 16.
## 색: 플레이어 타격 이펙트 색 위계(STYLE_GUIDE.md 6-1 순위3) #0099db/#2ce8f5 + 흰색 하이라이트.
## 예고색(#ff0044)은 어디에도 사용하지 않는다.
##
## 트리거 방법 (둘 중 하나):
##   1) (권장) HitFeedbackManager 경유 — data\combat\hitfeedback_strong.tres의 vfx_scene에
##      본 씬(res://scenes/vfx/hit_effect_large.tscn)이 이미 연결되어 있으므로,
##      HitFeedbackManager.play(strong_preset, at_position, target) 호출 시 자동 재생된다.
##   2) 독립 재생:
##      var vfx := preload("res://scenes/vfx/hit_effect_large.tscn").instantiate()
##      vfx.global_position = 타격_위치
##      get_tree().current_scene.add_child(vfx)
##
## 재생이 끝나면 스스로 queue_free()한다 — 호출 측에서 별도로 정리할 필요 없음.
extends Node2D

const DURATION_SEC: float = 1.2
const PARTICLE_TEXTURE_SIZE_PX: int = 8

const VfxParticleTextureScript := preload("res://scripts/vfx/vfx_particle_texture.gd")

@onready var _burst: GPUParticles2D = $Burst
@onready var _spark: GPUParticles2D = $Spark
@onready var _cleanup_timer: Timer = $CleanupTimer


func _ready() -> void:
	var texture := VfxParticleTextureScript.make_soft_circle(PARTICLE_TEXTURE_SIZE_PX)
	_burst.texture = texture
	_spark.texture = texture
	_burst.emitting = true
	_spark.emitting = true
	_cleanup_timer.start(DURATION_SEC + 0.05)


func _on_cleanup_timer_timeout() -> void:
	queue_free()
