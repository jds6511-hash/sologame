## 근접 스윙 공용 행동 블록 (combat.md 9-2 "행동 블록 부품화").
##
## 뿔토끼(박치기)·들개 마수(물기)가 공용으로 쓰는 예고(telegraph) → 판정(active) →
## 후딜(recovery) 3단 타이머만 관리한다. 실제 히트박스 on/off·데미지 판정은
## 소유 몬스터(MonsterBase._init_melee_swing)가 시그널을 받아 처리한다 — 이 블록은
## "언제 어느 구간인가"만 알려주는 순수 타이머 부품이라 다른 근접형 몬스터에도
## 그대로 재사용할 수 있다.
class_name MeleeSwingBlock
extends RefCounted

signal telegraph_started
signal became_active
signal ended

enum Phase { TELEGRAPH, ACTIVE, RECOVERY, DONE }

var phase: Phase = Phase.DONE
var telegraph_sec: float = 0.5
var active_sec: float = 0.12
var recovery_sec: float = 0.3

var _timer: float = 0.0


func start() -> void:
	phase = Phase.TELEGRAPH
	_timer = 0.0
	telegraph_started.emit()


func update(delta: float) -> void:
	if phase == Phase.DONE:
		return
	_timer += delta
	match phase:
		Phase.TELEGRAPH:
			if _timer >= telegraph_sec:
				phase = Phase.ACTIVE
				_timer = 0.0
				became_active.emit()
		Phase.ACTIVE:
			if _timer >= active_sec:
				phase = Phase.RECOVERY
				_timer = 0.0
		Phase.RECOVERY:
			if _timer >= recovery_sec:
				phase = Phase.DONE
				ended.emit()


func is_active() -> bool:
	return phase == Phase.ACTIVE


func is_done() -> bool:
	return phase == Phase.DONE
