## 순간이동 행동 블록 (m3-monster-spec.md 3-5장, combat.md 9-2 로스터 "순간이동").
##
## 임프의 무피해 재배치 블록 — 카이팅(궁수) 난이도 검증(G3-2)의 핵심 장치. 목표 지점
## 계산(플레이어 측면/후방 2~3타일)과 실제 텔레포트는 소유 몬스터(ImpMonster)가 blinked
## 시그널을 받아 처리하고(spec 8-3장 지시), 이 블록은 타이머만 관리한다.
##
## 단계 전이 (spec 3-5장 표 그대로):
##   [READY] --start()--> [TELEGRAPH](blink_telegraph_started, 0.3초 — 균열 일렁임)
##           --예고 종료--> [RECOVERY](blinked = 이 시점에 이동, 등장 후딜 0.3초 무방비)
##           --후딜 종료--> [COOLDOWN](recovery_ended, 4.5초 — 포효 임프장 아종은 6.0초)
##           --쿨다운 종료--> [READY](cooldown_ended)
##   [TELEGRAPH] --cancel()(피격 경직)--> [COOLDOWN]
##
## 예고 0.3초는 spec 3-5 "무피해 재배치라 짧게 — combat.md 4장 0.4~0.8초 규격의 명시적
## 예외"에 해당한다("사라진다" 신호를 읽을 최소 시간만 확보).
class_name BlinkBlock
extends RefCounted

signal blink_telegraph_started
signal blinked
signal recovery_ended
signal cooldown_ended

enum Phase { READY, TELEGRAPH, RECOVERY, COOLDOWN }

var phase: Phase = Phase.READY
var telegraph_sec: float = 0.3
var recovery_sec: float = 0.3
var cooldown_sec: float = 4.5

var _timer: float = 0.0


func start() -> void:
	phase = Phase.TELEGRAPH
	_timer = 0.0
	blink_telegraph_started.emit()


func update(delta: float) -> void:
	if phase == Phase.READY:
		return
	_timer += delta
	match phase:
		Phase.TELEGRAPH:
			if _timer >= telegraph_sec:
				_enter(Phase.RECOVERY)
				blinked.emit()
		Phase.RECOVERY:
			if _timer >= recovery_sec:
				_enter(Phase.COOLDOWN)
				recovery_ended.emit()
		Phase.COOLDOWN:
			if _timer >= cooldown_sec:
				_enter(Phase.READY)
				cooldown_ended.emit()


## 피격 경직 등으로 예고를 취소한다(이동 없이 쿨다운으로 넘어간다).
func cancel() -> void:
	if phase != Phase.TELEGRAPH:
		return
	_enter(Phase.COOLDOWN)


func is_ready() -> bool:
	return phase == Phase.READY


func is_busy() -> bool:
	return phase != Phase.READY and phase != Phase.COOLDOWN


## 재등장 직후 무방비 구간(딜찬스) — 소유 몬스터는 이 동안 이동·공격하지 않는다.
func is_recovering() -> bool:
	return phase == Phase.RECOVERY


func _enter(next_phase: Phase) -> void:
	phase = next_phase
	_timer = 0.0
