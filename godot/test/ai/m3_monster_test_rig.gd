## M3 신규 몬스터 3종(숲거미·무법자·임프) GUT 테스트 전용 조립 도구 — C-8.
##
## C-8 시점에는 몬스터 씬(.tscn)이 없다(스프라이트가 pixel-artist C-9 진행 중, 씬 조립은
## C-10). 그래서 테스트는 M2 방식(씬 preload) 대신 스크립트 인스턴스에 필요한 자식 노드만
## 직접 붙여 헤드리스로 상태머신을 검증한다 — 씬이 생기면 그대로 통과해야 하는 계약이다.
##
## 주의: @onready(_attack_hitbox·_stagger)는 노드가 트리에 들어갈 때 해석되므로, 아래 함수는
## 반드시 add_child() **전에** 호출해야 한다.
class_name M3MonsterTestRig
extends RefCounted

const STANDARD_RULES_PATH := "res://data/combat/mob_stagger_rules.tres"
const LIGHT_RULES_PATH := "res://data/combat/mob_stagger_rules_light.tres"


## 도약 착지 판정·돌진 경로 판정·근접 스윙이 쓰는 AttackHitbox(Area2D + CollisionShape2D).
static func attach_attack_hitbox(monster: MonsterBase) -> Area2D:
	var hitbox := Area2D.new()
	hitbox.name = "AttackHitbox"
	hitbox.monitoring = false
	hitbox.monitorable = false
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	hitbox.add_child(shape)
	monster.add_child(hitbox)
	return hitbox


## 잡몹 피격 경직·넉백 컴포넌트(scripts/combat 공용, 수정 없이 부착만).
static func attach_stagger(monster: MonsterBase, light_weight: bool = false) -> Node:
	var stagger := Node.new()
	stagger.name = "MobStagger"
	stagger.set_script(load("res://scripts/combat/mob_stagger_component.gd"))
	stagger.rules = load(LIGHT_RULES_PATH if light_weight else STANDARD_RULES_PATH)
	monster.add_child(stagger)
	return stagger
