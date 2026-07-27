## 돌진 행동 블록 (m3-monster-spec.md 3-3장, combat.md 9-2 로스터 "돌진").
##
## 무법자의 주 데미지 예고 패턴. LeapBlock과 동일한 순수 타이머 부품이며, 돌진 방향 고정·
## 직선 이동·경로 판정(히트박스)·벽 충돌 감지는 소유 몬스터(OutlawMonster)가 처리한다.
##
## 단계 전이 (spec 3-3 "예고(자세·방향 고정) → 돌진(직선 이동, 경로 판정) → 후딜"):
##   [READY] --start()--> [TELEGRAPH](telegraph_started, 0.6초 — 방향 고정)
##           --예고 종료--> [CHARGING](charge_started, 거리/속도 = 6타일/8타일초 ≈ 0.75초)
##           --이동 종료--> [RECOVERY](charge_ended, 0.5초)
##           --후딜 종료--> [COOLDOWN](ended, 4.0초)
##           --쿨다운 종료--> [READY](cooldown_ended)
##   [CHARGING] --hit_wall()--> [RECOVERY](후딜 0.5 + 벽 경직 0.8 = 1.3초 무방비)
##   [TELEGRAPH/CHARGING] --cancel()(피격 경직)--> [COOLDOWN]
##
## ai-dev 구현 결정(LeapBlock 헤더와 동일 원칙): 쿨다운은 후딜 종료 시점부터 계산하며,
## charge_sec(돌진 이동 시간)은 소유 몬스터가 거리÷속도로 계산해 주입한다(근거리에서
## 백스텝으로 활주로를 확보하는 처리도 소유 몬스터 몫 — spec 3-3 "돌진 이동" 행).
class_name ChargeBlock
extends RefCounted

signal telegraph_started
signal charge_started
signal charge_ended
signal ended
signal cooldown_ended

enum Phase { READY, TELEGRAPH, CHARGING, RECOVERY, COOLDOWN }

var phase: Phase = Phase.READY
var telegraph_sec: float = 0.6
var charge_sec: float = 0.75  ## 소유 몬스터가 charge_distance_tiles ÷ charge_speed_tiles로 주입
var recovery_sec: float = 0.5
var wall_stun_sec: float = 0.8
var cooldown_sec: float = 4.0

var _timer: float = 0.0
var _current_recovery_sec: float = 0.5


func start() -> void:
	phase = Phase.TELEGRAPH
	_timer = 0.0
	_current_recovery_sec = recovery_sec
	telegraph_started.emit()


func update(delta: float) -> void:
	if phase == Phase.READY:
		return
	_timer += delta
	match phase:
		Phase.TELEGRAPH:
			if _timer >= telegraph_sec:
				_enter(Phase.CHARGING)
				charge_started.emit()
		Phase.CHARGING:
			if _timer >= charge_sec:
				_enter(Phase.RECOVERY)
				charge_ended.emit()
		Phase.RECOVERY:
			if _timer >= _current_recovery_sec:
				_enter(Phase.COOLDOWN)
				ended.emit()
		Phase.COOLDOWN:
			if _timer >= cooldown_sec:
				_enter(Phase.READY)
				cooldown_ended.emit()


## 돌진 중 벽에 충돌했을 때 호출 — 즉시 후딜로 넘어가고 후딜에 벽 경직(0.8초)을 가산한다
## (spec 3-3 "벽에 박혀 비틀" = 지형 유도 딜찬스).
func hit_wall() -> void:
	if phase != Phase.CHARGING:
		return
	_enter(Phase.RECOVERY)
	_current_recovery_sec = recovery_sec + wall_stun_sec
	charge_ended.emit()


## 피격 경직 등으로 예고·돌진을 취소한다(판정 없이 쿨다운으로 넘어간다).
func cancel() -> void:
	if phase == Phase.READY or phase == Phase.COOLDOWN:
		return
	var was_charging := phase == Phase.CHARGING
	_enter(Phase.COOLDOWN)
	if was_charging:
		charge_ended.emit()
	ended.emit()


func is_ready() -> bool:
	return phase == Phase.READY


func is_busy() -> bool:
	return phase != Phase.READY and phase != Phase.COOLDOWN


func is_charging() -> bool:
	return phase == Phase.CHARGING


func _enter(next_phase: Phase) -> void:
	phase = next_phase
	_timer = 0.0
