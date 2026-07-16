## 무리 어그로 공유·공격 토큰 공용 로직 (combat.md 2-2 "다수 교전 규칙").
##
## - 어그로 공유(같은 무리 중 1마리 피격 시 전체 전투 돌입)는 몬스터 스크립트가
##   Godot 그룹(`get_tree().call_group`)으로 직접 처리한다(각 몬스터 종의 상태
##   전이 방식이 다르므로 여기서는 다루지 않는다).
## - 본 클래스는 "동시에 공격 모션에 들어갈 수 있는 마리 수" 규칙만 담당한다.
##   pack_id(문자열)만 공유하면 되므로 몬스터가 씬 트리 그룹에 속할 필요가 없다.
##   실제 무리 구성(같은 pack_id 배정)은 MP-4(레벨 배치, level-designer+ai-dev)가
##   맡는다 — CB-6은 규칙(메커니즘)만 제공한다.
class_name PackAggroCoordinator
extends RefCounted

const MAX_ATTACK_TOKENS := 2  ## combat.md 2-2 "공격 토큰 최대 2마리"

static var _active_attackers: Dictionary = {}  ## pack_id(String) -> 현재 공격 중인 마리 수


## 공격 토큰 획득을 시도한다. 성공하면 true를 반환하고 카운트를 1 늘린다.
## pack_id가 빈 문자열이면 무리가 아닌 솔로 개체이므로 토큰 제한 없이 항상 성공한다.
static func try_acquire_attack_token(pack_id: String) -> bool:
	if pack_id.is_empty():
		return true
	var current: int = _active_attackers.get(pack_id, 0)
	if current >= MAX_ATTACK_TOKENS:
		return false
	_active_attackers[pack_id] = current + 1
	return true


## 공격 종료 시 토큰을 반납한다.
static func release_attack_token(pack_id: String) -> void:
	if pack_id.is_empty():
		return
	var current: int = _active_attackers.get(pack_id, 0)
	_active_attackers[pack_id] = maxi(current - 1, 0)


## 현재 pack_id가 사용 중인 토큰 수 (테스트/디버그용 조회)
static func get_active_token_count(pack_id: String) -> int:
	return _active_attackers.get(pack_id, 0)


## 모든 무리의 토큰 상태 초기화 — static 상태이므로 GUT 테스트 간 오염 방지용으로 호출한다.
static func reset_all() -> void:
	_active_attackers.clear()
