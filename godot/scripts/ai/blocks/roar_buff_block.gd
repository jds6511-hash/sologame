## 포효 버프 행동 블록 (m3-monster-spec.md 3-6장, combat.md 9-2 로스터 "포효 버프").
##
## 임프의 무피해 버프 블록 — 다수전에서 처치 우선순위를 강제한다. 반경 내 아군 순회·버프
## 적용·버프 지속 관리는 소유 몬스터(ImpMonster)가 roared 시그널을 받아 처리하고(spec
## 8-3장 지시), 이 블록은 예고→발동→쿨다운 타이머만 관리한다(판정 없음 = 직접 피해 없음).
##
## 단계 전이 (spec 4-3 상태 전이도 그대로):
##   [READY] --start()--> [TELEGRAPH](roar_telegraph_started, 0.5초 — 고개 젖힘)
##           --예고 종료--> [COOLDOWN](roared = 이 시점에 버프 적용, 12.0초)
##           --쿨다운 종료--> [READY](cooldown_ended)
##   [TELEGRAPH] --cancel()(피격 경직)--> [COOLDOWN]
##
## 버프 지속 6.0초 < 쿨다운 12.0초 → 가동률 50%(spec 3-6 "상시 유지 불가")는 이 블록의
## 쿨다운과 소유 몬스터의 버프 타이머가 함께 보장한다.
class_name RoarBuffBlock
extends RefCounted

signal roar_telegraph_started
signal roared
signal cooldown_ended

enum Phase { READY, TELEGRAPH, COOLDOWN }

var phase: Phase = Phase.READY
var telegraph_sec: float = 0.5
var cooldown_sec: float = 12.0

var _timer: float = 0.0


func start() -> void:
	phase = Phase.TELEGRAPH
	_timer = 0.0
	roar_telegraph_started.emit()


func update(delta: float) -> void:
	if phase == Phase.READY:
		return
	_timer += delta
	match phase:
		Phase.TELEGRAPH:
			if _timer >= telegraph_sec:
				_enter(Phase.COOLDOWN)
				roared.emit()
		Phase.COOLDOWN:
			if _timer >= cooldown_sec:
				_enter(Phase.READY)
				cooldown_ended.emit()


## 피격 경직 등으로 예고를 취소한다(버프 없이 쿨다운으로 넘어간다 — 예고 캔슬 = 딜찬스).
func cancel() -> void:
	if phase != Phase.TELEGRAPH:
		return
	_enter(Phase.COOLDOWN)


func is_ready() -> bool:
	return phase == Phase.READY


func is_busy() -> bool:
	return phase == Phase.TELEGRAPH


func _enter(next_phase: Phase) -> void:
	phase = next_phase
	_timer = 0.0
