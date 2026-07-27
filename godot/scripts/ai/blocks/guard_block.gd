## 가드 행동 블록 (m3-monster-spec.md 3-4장, combat.md 9-2 로스터 "가드").
##
## 무법자의 무피해 방어 블록. 정면 각(±60°) 판정·데미지 감쇄(−60%)·강 등급 브레이크 판정은
## 소유 몬스터(OutlawMonster)가 take_damage 훅에서 처리하고(spec 8-3장 지시), 이 블록은
## "지금 가드가 서 있는가 / 브레이크 경직 중인가 / 쿨다운이 남았는가"만 관리한다.
##
## 단계 전이 (spec 4-2 상태 전이도 그대로):
##   [READY] --start()--> [ENTERING](0.2초 자세 전환 — 아직 감쇄 없음)
##           --진입 종료--> [GUARDING](guard_entered, 최대 1.5초)
##           --1.5초 경과 또는 notify_absorbed_hit()(1회 피격)--> [RECOVERY](guard_ended, 0.4초)
##           --후딜 종료--> [COOLDOWN](6.0초)
##           --쿨다운 종료--> [READY](cooldown_ended)
##   [ENTERING/GUARDING] --notify_guard_break()(강 등급 피격)--> [BROKEN](guard_broken, 경직
##       1.0초) --> [COOLDOWN]  ← spec 4-2 상태 전이도는 브레이크 후 해제 후딜 없이 바로 복귀
##
## 무피해 방어라 진입 예고가 0.2초로 짧은 것은 spec 3-4 "회피할 데미지가 없어 combat.md 4장
## 0.4~0.8초 규격의 명시적 예외"에 해당한다.
class_name GuardBlock
extends RefCounted

signal guard_entered
signal guard_broken
signal guard_ended
signal cooldown_ended

enum Phase { READY, ENTERING, GUARDING, BROKEN, RECOVERY, COOLDOWN }

var phase: Phase = Phase.READY
var enter_sec: float = 0.2
var duration_sec: float = 1.5
var break_stun_sec: float = 1.0
var recovery_sec: float = 0.4
var cooldown_sec: float = 6.0

var _timer: float = 0.0


func start() -> void:
	phase = Phase.ENTERING
	_timer = 0.0


func update(delta: float) -> void:
	if phase == Phase.READY:
		return
	_timer += delta
	match phase:
		Phase.ENTERING:
			if _timer >= enter_sec:
				_enter(Phase.GUARDING)
				guard_entered.emit()
		Phase.GUARDING:
			if _timer >= duration_sec:
				_enter(Phase.RECOVERY)
				guard_ended.emit()
		Phase.BROKEN:
			if _timer >= break_stun_sec:
				_enter(Phase.COOLDOWN)
		Phase.RECOVERY:
			if _timer >= recovery_sec:
				_enter(Phase.COOLDOWN)
		Phase.COOLDOWN:
			if _timer >= cooldown_sec:
				_enter(Phase.READY)
				cooldown_ended.emit()


## 정면 일반 피격 1회를 흘렸을 때 호출 — spec 3-4 "지속 최대 1.5초 또는 1회 피격까지".
func notify_absorbed_hit() -> void:
	if phase != Phase.GUARDING:
		return
	_enter(Phase.RECOVERY)
	guard_ended.emit()


## 강 등급(치명타·차지 강타) 피격 시 호출 — 즉시 해제 + 경직 1.0초(딜찬스).
func notify_guard_break() -> void:
	if phase != Phase.GUARDING and phase != Phase.ENTERING:
		return
	_enter(Phase.BROKEN)
	guard_broken.emit()


func is_ready() -> bool:
	return phase == Phase.READY


func is_busy() -> bool:
	return phase != Phase.READY and phase != Phase.COOLDOWN


## 데미지 감쇄·넉백/경직 무효가 실제로 적용되는 구간(진입 0.2초 이후).
func is_guarding() -> bool:
	return phase == Phase.GUARDING


func is_broken() -> bool:
	return phase == Phase.BROKEN


func _enter(next_phase: Phase) -> void:
	phase = next_phase
	_timer = 0.0
