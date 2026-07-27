## 도약 행동 블록 (m3-monster-spec.md 3-1장, combat.md 9-2 로스터 "도약").
##
## 숲거미의 주 데미지 예고 패턴. MeleeSwingBlock·AimFireBlock과 동일하게 "언제 어느
## 구간인가"만 알려주는 순수 타이머 부품이며, 착지 지점 계산·공중 이동·히트박스 on/off·
## 데미지는 소유 몬스터(ForestSpiderMonster)가 시그널을 받아 처리한다.
##
## 단계 전이 (spec 3-1 "예고(웅크림) → 도약(공중 이동) → 착지(판정) → 후딜"):
##   [READY] --start()--> [TELEGRAPH](telegraph_started, 0.5초 — 착지 지점 고정)
##           --예고 종료--> [TRAVEL](leap_started, 0.35초 — 공중 이동)
##           --이동 종료--> [ACTIVE](became_active, 0.15초 — 착지 판정)
##           --판정 종료--> [RECOVERY](active_ended, 0.4초 — 무방비 카운터 창)
##           --후딜 종료--> [COOLDOWN](ended, 3.5초)
##           --쿨다운 종료--> [READY](cooldown_ended)
##   [TELEGRAPH/TRAVEL] --cancel()(피격 경직)--> [COOLDOWN]
##
## ai-dev 구현 결정 (spec 미기재 — systems-designer 확인 대상, 디렉터 결정 아님):
##   1. 쿨다운 기점: 스펙이 명시하지 않아 "후딜 종료 시점"부터 계산한다(1사이클 =
##      예고+이동+판정+후딜+쿨다운 = 4.9초). G3-1 튜닝 대상.
##   2. 시그널 목록: spec 8-3장은 telegraph_started/became_active/ended 3개만 제시하지만,
##      소유 몬스터가 공중 이동 개시·판정 종료 시점을 알아야 해서 leap_started·active_ended·
##      cooldown_ended를 추가했다(판정 지속 0.15초를 정확히 지키기 위함).
##   3. 경직 캔슬(spec 4-1 "예고 캔슬 = 딜찬스") 시 READY가 아니라 COOLDOWN으로 보낸다 —
##      캔슬 직후 즉시 재도약하면 캔슬이 딜찬스가 되지 못하기 때문이다.
class_name LeapBlock
extends RefCounted

signal telegraph_started
signal leap_started
signal became_active
signal active_ended
signal ended
signal cooldown_ended

enum Phase { READY, TELEGRAPH, TRAVEL, ACTIVE, RECOVERY, COOLDOWN }

var phase: Phase = Phase.READY
var telegraph_sec: float = 0.5
var travel_sec: float = 0.35
var active_sec: float = 0.15
var recovery_sec: float = 0.4
var cooldown_sec: float = 3.5

var _timer: float = 0.0


func start() -> void:
	phase = Phase.TELEGRAPH
	_timer = 0.0
	telegraph_started.emit()


func update(delta: float) -> void:
	if phase == Phase.READY:
		return
	_timer += delta
	match phase:
		Phase.TELEGRAPH:
			if _timer >= telegraph_sec:
				_enter(Phase.TRAVEL)
				leap_started.emit()
		Phase.TRAVEL:
			if _timer >= travel_sec:
				_enter(Phase.ACTIVE)
				became_active.emit()
		Phase.ACTIVE:
			if _timer >= active_sec:
				_enter(Phase.RECOVERY)
				active_ended.emit()
		Phase.RECOVERY:
			if _timer >= recovery_sec:
				_enter(Phase.COOLDOWN)
				ended.emit()
		Phase.COOLDOWN:
			if _timer >= cooldown_sec:
				_enter(Phase.READY)
				cooldown_ended.emit()


## 피격 경직 등으로 예고·이동을 취소한다(판정은 발생하지 않고 쿨다운으로 넘어간다).
func cancel() -> void:
	if phase == Phase.READY or phase == Phase.COOLDOWN:
		return
	var was_active := phase == Phase.ACTIVE
	_enter(Phase.COOLDOWN)
	if was_active:
		active_ended.emit()
	ended.emit()


func is_ready() -> bool:
	return phase == Phase.READY


## 예고~후딜 구간(쿨다운 제외) — 소유 몬스터가 "패턴 수행 중"을 판정할 때 쓴다.
func is_busy() -> bool:
	return phase != Phase.READY and phase != Phase.COOLDOWN


func is_traveling() -> bool:
	return phase == Phase.TRAVEL


func is_active() -> bool:
	return phase == Phase.ACTIVE


func _enter(next_phase: Phase) -> void:
	phase = next_phase
	_timer = 0.0
