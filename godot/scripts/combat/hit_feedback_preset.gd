## 타격 피드백 프리셋 데이터 (CB-7, combat.md 5-3장).
##
## 약/중/강 3단계 프리셋을 .tres로 분리해, 스킬·몬스터 구현 쪽은 프리셋 리소스를
## 고르기만 하면 히트스톱·화면 흔들림·이펙트/사운드가 함께 적용되게 한다
## (combat.md 9-1장 "타격 피드백 공용 모듈" 방침).
##
## screen_shake_intensity는 세기 단계값(0=없음)만 정의하고, 실제 흔들림 연출(셰이더·
## 카메라 오프셋)은 CB-8(tech-artist) 담당이다 — HitFeedbackManager가 발신하는
## screen_shake_requested 시그널을 CB-8 쪽에서 구독해 강도만큼 흔들면 된다.
## vfx_scene/sfx_stream도 마찬가지로 "연동 슬롯"이며 실제 에셋은 AR-4/SD-1이 채운다.
class_name HitFeedbackPreset
extends Resource

@export_enum("약", "중", "강") var tier_name: String = "약"
@export var hitstop_sec: float = 0.03
@export var screen_shake_intensity: int = 0  ## 0=없음, 1=약, 2=중 (CB-8이 강도 해석)
@export var vfx_scene: PackedScene  ## AR-4 타격 이펙트 연동 슬롯 (미배정 시 null 허용)
@export var sfx_stream: AudioStream  ## SD-1 SFX 연동 슬롯 (미배정 시 null 허용)
