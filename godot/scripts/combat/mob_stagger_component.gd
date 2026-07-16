## 몬스터(잡몹) 피격 경직·슈퍼아머 상태머신 (CB-4, combat.md 5-2장).
##
## 몬스터 종류·행동 블록(CB-6)과 무관하게 재사용하는 범용 컴포넌트다.
## ai-dev는 몬스터 씬(scripts/ai/·scenes/world/, 본 태스크 범위 밖)에서 이 스크립트를
## 자식 노드로 붙이고, 피격 판정 시 register_hit()을 호출하면 된다 — 사용법은
## 하단 "CB-6 연동 방법" 주석 참조.
##
## 규칙: 경직이 연속 stagger_chain_limit(기본 3)회 발생하면 그다음 경직 대신
## superarmor_sec(기본 1.5초) 동안 슈퍼아머 상태가 되어 경직이 완전히 무시된다
## (무한 경직 방지). 슈퍼아머가 끝나면 연속 횟수가 초기화되어 다시 경직이 걸린다.
##
## CB-6 연동 방법 (ai-dev):
##   1. 몬스터 씬에 이 스크립트를 붙인 자식 노드를 추가하고 rules(.tres)를 지정한다.
##   2. 피격 판정이 성립하면 `register_hit(is_heavy)`를 호출한다.
##      - is_heavy: 강타·치명타 여부(combat.md 5-2 "강타·치명타 0.25초+넉백" 기준).
##        DamageCalculator.calculate_damage()가 돌려준 is_critical을 그대로 넘기는
##        것을 기본 매핑으로 권장한다(단순화 — 몬스터 쪽에서 다른 기준을 쓰고 싶다면
##        자유롭게 재정의해도 된다).
##   3. 반환된 Dictionary의 "staggered"가 true면 몬스터의 이동/공격 상태머신을
##      경직 상태로 전이시키고, "superarmor"가 true면 경직을 무시하고 평시 상태를
##      유지한다. is_staggered()/is_superarmor()로 언제든 현재 상태를 조회할 수 있다.
##   4. stagger_started/stagger_ended/superarmor_started/superarmor_ended 시그널로
##      애니메이션·연출을 트리거할 수 있다.
class_name MobStaggerComponent
extends Node

signal stagger_started(is_heavy: bool)
signal stagger_ended
signal superarmor_started
signal superarmor_ended

enum StaggerState { NONE, STAGGERED, SUPERARMOR }

@export var rules: MobStaggerRules

var _state: StaggerState = StaggerState.NONE
var _chain_count: int = 0
var _timer: float = 0.0
var _pending_superarmor_after_stagger: bool = false


func _process(delta: float) -> void:
	advance_time(delta)


## 피격 판정 성립 시 호출. 반환값: {"staggered": bool, "superarmor": bool}
func register_hit(is_heavy: bool) -> Dictionary:
	if _state == StaggerState.SUPERARMOR:
		return {"staggered": false, "superarmor": true}

	_chain_count += 1
	_pending_superarmor_after_stagger = _chain_count >= rules.stagger_chain_limit
	_state = StaggerState.STAGGERED
	_timer = rules.heavy_stagger_sec if is_heavy else rules.light_stagger_sec
	stagger_started.emit(is_heavy)
	return {"staggered": true, "superarmor": false}


func is_staggered() -> bool:
	return _state == StaggerState.STAGGERED


func is_superarmor() -> bool:
	return _state == StaggerState.SUPERARMOR


## 시간 흐름을 반영해 상태를 갱신한다. _process가 매 프레임 호출하며,
## GUT 테스트에서는 직접 호출해 델타를 주입한다.
func advance_time(delta: float) -> void:
	if _state == StaggerState.NONE:
		return
	_timer -= delta
	if _timer > 0.0:
		return

	if _state == StaggerState.STAGGERED:
		stagger_ended.emit()
		if _pending_superarmor_after_stagger:
			_chain_count = 0
			_pending_superarmor_after_stagger = false
			_state = StaggerState.SUPERARMOR
			_timer = rules.superarmor_sec
			superarmor_started.emit()
		else:
			_state = StaggerState.NONE
	elif _state == StaggerState.SUPERARMOR:
		_state = StaggerState.NONE
		superarmor_ended.emit()
