## 레벨 차 경험치·골드 보정 배율 데이터 (Resource) — M3 B-1.
##
## m3-leveling-spec.md 4장(growth.md 5-4장)을 필드화한다. d = 몬스터 레벨 - 플레이어 레벨.
## economy-foundation.md 5-4장이 "이 표를 골드에도 동일 적용"으로 확정했으므로, 경험치와
## 골드가 이 단일 리소스를 공유해 이중 관리를 없앤다(spec 8-4 정합 확인).
##
## 배율표(spec 4장):
##   d >= +5      : 1.20 (상한)
##   -4 <= d <= 4 : 1.00 (중립)
##   d = -5..-9   : 0.85 / 0.70 / 0.55 / 0.40 / 0.25 (레벨당 -0.15)
##   d <= -10     : 0.10 (바닥)
class_name LevelDiffCurve
extends Resource

@export var up_cap_diff: int = 5  ## 이 값 이상이면 상한 배율
@export var up_cap_mult: float = 1.2
@export var neutral_min: int = -4  ## 이 값 이상이면(상한 미만) 중립 1.0
@export var neutral_max: int = 4  ## 참고용(중립 상단 경계 — 룩업은 up_cap_diff로 판정)
## d = -5, -6, -7, -8, -9 에 대응하는 하향 배율(내림차순).
@export var down_mults: PackedFloat32Array = PackedFloat32Array([0.85, 0.7, 0.55, 0.4, 0.25])
@export var floor_mult: float = 0.1  ## d <= -10 바닥 배율


## 레벨 차 d(= 몬스터 레벨 - 플레이어 레벨)에 대한 경험치·골드 배율.
func multiplier(d: int) -> float:
	if d >= up_cap_diff:
		return up_cap_mult
	if d >= neutral_min:
		return 1.0
	## 이하 d <= neutral_min - 1 (기본값에서 d <= -5). d=-5 -> idx 0 ... d=-9 -> idx 4.
	var idx := neutral_min - 1 - d
	if idx >= 0 and idx < down_mults.size():
		return down_mults[idx]
	return floor_mult
