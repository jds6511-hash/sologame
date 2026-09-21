## 플레이어 이동·회피(대시) 수치 데이터 (Resource).
##
## combat.md 4장 "회피(대시)와 무적 프레임" 표의 확정 수치를 그대로 반영한다.
## 걷기 이동속도는 growth.md 3장의 추상 스탯("이동 속도 기본 100")이 아니라,
## combat.md 4장이 명시한 대시 3수치(거리 3타일분·지속 0.35초·2.6배속)에서 역산한다:
##   대시 속도(px/s) = (타일 크기 x 대시 거리 타일 수) / 대시 지속 시간
##   걷기 속도(px/s) = 대시 속도 / 대시 배율
## → 걷기 이동속도의 px/s 절대값이 기획 문서에 직접 명시되어 있지 않아 위 공식으로
##   역산했다. systems-designer 확인 후 growth.md에 절대값이 확정되면 이 역산을
##   덮어쓸 수 있도록 이동속도 필드를 노출해 둔다(현재는 자동 계산값 그대로 사용).
class_name PlayerMovementData
extends Resource

@export var tile_size_px: float = 16.0  ## STYLE_GUIDE.md 1장 — 월드 타일 크기

@export_group("대시 (combat.md 4장)")
@export var dash_duration_sec: float = 0.35
@export var dash_distance_tiles: float = 3.0
@export var dash_speed_multiplier: float = 2.6  ## 걷기 이동속도 대비 대시 속도 배율
@export var dash_invincibility_start_sec: float = 0.0  ## 입력 수락 즉시 무적
@export var dash_invincibility_duration_sec: float = 0.30  ## 기존 종료 시점 유지
@export var dash_charge_max: int = 2  ## 전사 계열 = 표준 2회 (jobs.md 3장)
@export var dash_recharge_sec: float = 4.0  ## 충전 1회당 재충전 시간, 전 직업 공통


## 대시 총 이동 거리(px) = 타일 크기 x 대시 거리(타일 수)
func get_dash_distance_px() -> float:
	return tile_size_px * dash_distance_tiles


## 대시 속도(px/s) = 대시 거리 / 대시 지속 시간
func get_dash_speed_px_per_sec() -> float:
	return get_dash_distance_px() / dash_duration_sec


## 걷기 이동속도(px/s) = 대시 속도 / 대시 배율(2.6배)
func get_walk_speed_px_per_sec() -> float:
	return get_dash_speed_px_per_sec() / dash_speed_multiplier


## 대시 타임라인에서 무적 프레임이 끝나는 시점(초)
func get_dash_invincibility_end_sec() -> float:
	return dash_invincibility_start_sec + dash_invincibility_duration_sec
