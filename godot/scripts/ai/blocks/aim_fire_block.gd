## 조준→발사→쿨다운 반복 행동 블록 (combat.md 9-2 "행동 블록 부품화").
##
## 균열 점액의 투사체(산성 방울) 패턴에서 쓰는 조준 예고(telegraph) → 발사(fired) →
## 쿨다운(cooldown_ended) 3단 타이머만 관리한다. 실제 투사체 스폰이나 "무엇을 조준할
## 것인가"(조준 지점 계산)는 소유 몬스터(RiftSlimeMonster)가 담당한다 — 쿨다운이
## 끝나도 이 블록은 스스로 재조준하지 않고 cooldown_ended만 알려서, 몬스터가 매 사이클
## 최신 목표 위치로 조준 지점을 다시 계산할 수 있게 한다(고정된 옛 위치를 재사용하는
## 버그 방지). 다른 원거리 몬스터가 생기면 이 블록을 그대로 재사용할 수 있다.
class_name AimFireBlock
extends RefCounted

signal aim_started
signal fired
signal cooldown_ended

enum Phase { IDLE, AIMING, COOLDOWN }

var phase: Phase = Phase.IDLE
var telegraph_sec: float = 0.7
var cooldown_sec: float = 1.2

var _timer: float = 0.0


func start_aim() -> void:
	phase = Phase.AIMING
	_timer = 0.0
	aim_started.emit()


func update(delta: float) -> void:
	match phase:
		Phase.AIMING:
			_timer += delta
			if _timer >= telegraph_sec:
				_timer = 0.0
				phase = Phase.COOLDOWN
				fired.emit()
		Phase.COOLDOWN:
			_timer += delta
			if _timer >= cooldown_sec:
				phase = Phase.IDLE
				_timer = 0.0
				cooldown_ended.emit()
		Phase.IDLE:
			pass


## 사거리 이탈 등으로 패턴을 중단할 때 호출 — 다음에 다시 start_aim()부터 시작한다.
func reset() -> void:
	phase = Phase.IDLE
	_timer = 0.0
