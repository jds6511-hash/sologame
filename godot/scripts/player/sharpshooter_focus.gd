extends RefCounted
## 명사수의 저장하지 않는 집중/공격 묶음 상태.
## begin_cast는 첫 투사체 생성 확정 뒤 호출한다. 생성 전 취소는 호출하지 않는다.
## projectile_index는 예정 발사 순서의 0 기반 번호다. end는 수명/지형/제거 때 호출한다.
## 직전 묶음은 명중 도착 순서가 아닌 발사 순서다. 기본 충전과 호흡은 즉시,
## 직전 결과가 미결이면 연속 보너스 5만 기다린다. 실패 확정 시 보너스는 없다.
## pause 동안 호출자가 advance를 생략한다. 사망/직업/필드/로드 때 reset한다.

const MAX_FOCUS := 100.0
const SHOT_COST := 50.0

var value := 0.0
var breathing_remaining := 0.0
var _breathing_bonus_pending := false
var _idle_seconds := 0.0
var _next_id := 1
var _last_id := -1
var _casts: Dictionary = {}


func begin_cast(planned_count: int, charge_cap: int = 15) -> int:
	if planned_count <= 0:
		return -1
	var id := _next_id
	_next_id += 1
	var previous := 0
	if _casts.has(_last_id):
		previous = int(_casts[_last_id].outcome)
		_casts[_last_id].next = id
	_casts[id] = {
		"planned": planned_count,
		"pending": planned_count,
		"ended": {},
		"landed": {},
		"cap": clampi(charge_cap, 0, 15),
		"outcome": -1,
		"previous": previous,
		"next": -1,
		"bonus_done": false,
	}
	var previous_id := _last_id
	_last_id = id
	_prune(previous_id)
	return id


func landed(cast_id: int, projectile_index: int) -> void:
	if not _valid_projectile(cast_id, projectile_index):
		return
	var cast: Dictionary = _casts[cast_id]
	if cast.landed.has(projectile_index):
		return
	cast.landed[projectile_index] = true
	_idle_seconds = 0.0
	if int(cast.outcome) == 1:
		return
	if int(cast.cap) > 0:
		_add(mini(10, int(cast.cap)))
		if breathing_remaining > 0.0 and _breathing_bonus_pending:
			_add(20.0)
			_breathing_bonus_pending = false
	_resolve(cast_id, 1)


func end(cast_id: int, projectile_index: int) -> void:
	if not _valid_projectile(cast_id, projectile_index):
		return
	var cast: Dictionary = _casts[cast_id]
	cast.ended[projectile_index] = true
	cast.pending = int(cast.pending) - 1
	if int(cast.pending) == 0 and int(cast.outcome) == -1:
		_resolve(cast_id, 0)
	_prune(cast_id)


func cancel_unspawned(cast_id: int, from_index: int) -> void:
	if not _casts.has(cast_id):
		return
	# 첫 발은 begin_cast의 확정 조건이므로 미생성 취소 대상이 아니다.
	var count: int = int(_casts[cast_id].planned)
	for index in range(maxi(1, from_index), count):
		end(cast_id, index)


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	breathing_remaining = maxf(0.0, breathing_remaining - delta)
	var previous_decay_time := maxf(0.0, _idle_seconds - 5.0)
	_idle_seconds += delta
	var decay_time := maxf(0.0, _idle_seconds - 5.0) - previous_decay_time
	value = maxf(0.0, value - decay_time * 10.0)


func start_breathing() -> void:
	breathing_remaining = 6.0
	_breathing_bonus_pending = true


func take_hit() -> void:
	value = maxf(0.0, value - 20.0)


func spend() -> bool:
	if value < SHOT_COST:
		return false
	value -= SHOT_COST
	return true


func reset() -> void:
	value = 0.0
	breathing_remaining = 0.0
	_breathing_bonus_pending = false
	_idle_seconds = 0.0
	_last_id = -1
	_casts.clear()
	# ID를 재사용하지 않아 이전 필드의 늦은 이벤트가 새 공격을 건드리지 않는다.


func _valid_projectile(cast_id: int, index: int) -> bool:
	if not _casts.has(cast_id):
		return false
	var cast: Dictionary = _casts[cast_id]
	return index >= 0 and index < int(cast.planned) and not cast.ended.has(index)


func _resolve(cast_id: int, outcome: int) -> void:
	var cast: Dictionary = _casts[cast_id]
	cast.outcome = outcome
	_try_bonus(cast_id)
	var next: int = int(cast.next)
	if _casts.has(next):
		_casts[next].previous = outcome
		_try_bonus(next)
		_prune(next)


func _try_bonus(cast_id: int) -> void:
	var cast: Dictionary = _casts[cast_id]
	if bool(cast.bonus_done) or int(cast.outcome) == -1:
		return
	if int(cast.outcome) == 0 or int(cast.cap) <= 10:
		cast.bonus_done = true
	elif int(cast.previous) != -1:
		cast.bonus_done = true
		if int(cast.previous) == 1:
			_add(int(cast.cap) - 10)


func _prune(cast_id: int) -> void:
	if cast_id == _last_id or not _casts.has(cast_id):
		return
	var cast: Dictionary = _casts[cast_id]
	if int(cast.pending) == 0 and bool(cast.bonus_done):
		_casts.erase(cast_id)


func _add(amount: float) -> void:
	value = minf(MAX_FOCUS, value + amount)
