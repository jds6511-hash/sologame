## 온보딩 힌트 1개의 "절제된 재노출" 타이밍 (docs\art\ux\onboarding.md 1장 원칙4).
##
## 규칙 그대로: 최초 노출 후 8초 뒤 자동 페이드아웃, 15초 뒤 재노출 — 최대 3회까지.
## 3회를 넘기면 조용히 포기한다. "지금 이 순간 화면에 보여야 하는가"만 판단하는 순수
## 로직이라(Node 의존 없음) TutorialController·GUT 양쪽에서 델타 스텝으로 결정론적으로
## 다룰 수 있다. 실제 완료 판정(퀘스트 프리미티브 등)은 이 클래스의 책임이 아니다 —
## 완료됐다고 판단되면 호출자가 complete()를 불러 영구히 잠재운다.
class_name OnboardingHintTiming
extends RefCounted

enum Phase { IDLE, SHOWING, WAITING, DONE }

const SHOW_SEC := 8.0
const WAIT_SEC := 15.0
const MAX_EXPOSURES := 3

var _phase: Phase = Phase.IDLE
var _timer: float = 0.0
var _exposures: int = 0


## 힌트가 노출될 자격이 생겼을 때 매 프레임 호출해도 안전하다 — 이미 진행/포기 중이면
## 아무 일도 하지 않는다(최초 1회만 실제로 SHOWING을 시작한다).
func begin() -> void:
	if _phase != Phase.IDLE:
		return
	if _exposures >= MAX_EXPOSURES:
		_phase = Phase.DONE
		return
	_phase = Phase.SHOWING
	_timer = 0.0
	_exposures += 1


## 매 프레임 호출. SHOWING -> WAITING(8초) -> SHOWING(15초 뒤 재노출, 최대 3회) -> DONE 전이.
func update(delta: float) -> void:
	if _phase != Phase.SHOWING and _phase != Phase.WAITING:
		return
	_timer += delta
	if _phase == Phase.SHOWING and _timer >= SHOW_SEC:
		_phase = Phase.WAITING
		_timer = 0.0
	elif _phase == Phase.WAITING and _timer >= WAIT_SEC:
		if _exposures >= MAX_EXPOSURES:
			_phase = Phase.DONE
		else:
			_phase = Phase.SHOWING
			_timer = 0.0
			_exposures += 1


func is_showing() -> bool:
	return _phase == Phase.SHOWING


func is_done() -> bool:
	return _phase == Phase.DONE


## 완료 조건(이동 3타일 등)이 충족됐을 때 호출 — 즉시 숨기고 다시는 노출하지 않는다.
func complete() -> void:
	_phase = Phase.DONE
