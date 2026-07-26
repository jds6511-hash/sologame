## 디렉터 플레이 차단 버그 재현 — 몬스터가 플레이어에게 실제 피해를 주는지 "씬 배선" 수준에서
## 검증한다(늑대에게 맞아도 플레이어 HP 불변 버그).
##
## 근본 원인: scenes/monsters/*.tscn 어디에도 MonsterAttackResolver가 배선돼 있지 않아
## MonsterBase.attack_landed 시그널을 아무도 소비하지 않았고(근접 2종), 균열 점액 투사체는
## _on_body_entered가 hit_target 시그널만 발신하고 실피해를 적용하지 않았다(원거리).
##
## 이 테스트는 실제 몬스터 씬 + 실제 플레이어 씬을 함께 트리에 넣고,
##  - 근접 2종(뿔토끼·들개 마수): 근접 스윙 히트박스가 플레이어를 물리적으로 감지하면
##    씬에 baked된 MonsterAttackResolver를 거쳐 플레이어 HP가 감소하는지,
##  - 균열 점액: 투사체 직격 시 플레이어 HP가 감소하는지
## 를 확인한다. 수정 전에는 세 경우 모두 FAIL한다.
extends GutTest

const RABBIT_SCENE := preload("res://scenes/monsters/rabbit.tscn")
const WOLF_SCENE := preload("res://scenes/monsters/wolf.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/monsters/rift_slime_projectile.tscn")
const FORMULA := preload("res://data/combat/damage_formula.tres")

var _player: PlayerController
var _stats: PlayerStatsComponent


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2.ZERO
	_stats = _player.get_node("PlayerStats")


## 근접 몬스터를 플레이어와 겹쳐 배치하고, 이동/넉백으로 겹침이 풀리지 않게 물리 처리를
## 끈다(히트박스 감지 자체는 물리 서버가 처리하므로 _physics_process와 무관하게 작동한다).
func _spawn_overlapping_melee_monster(scene: PackedScene) -> MonsterBase:
	var monster: MonsterBase = scene.instantiate()
	add_child_autofree(monster)
	monster.global_position = Vector2.ZERO
	monster.target = _player
	monster.set_physics_process(false)
	return monster


func _assert_melee_swing_damages_player(scene: PackedScene, monster_name: String) -> void:
	var monster := _spawn_overlapping_melee_monster(scene)
	var hp_before := _stats.current_hp
	monster._enable_attack_hitbox()  ## 근접 스윙 판정(active) 구간 개시 = 히트박스 monitoring on
	await wait_physics_frames(3)  ## body_entered 는 다음 물리 프레임에 발신된다
	assert_lt(_stats.current_hp, hp_before, "%s 근접 스윙 명중 시 플레이어 HP가 감소해야 한다" % monster_name)


func test_rabbit_melee_swing_damages_player() -> void:
	await _assert_melee_swing_damages_player(RABBIT_SCENE, "뿔토끼")


func test_wolf_melee_swing_damages_player() -> void:
	await _assert_melee_swing_damages_player(WOLF_SCENE, "들개 마수")


## 균열 점액 투사체(원거리) — 직격 시 플레이어 HP가 감소해야 한다. 투사체 씬의 충돌
## 설정(mask=2·monitoring)은 이미 정상이라, 버그는 _on_body_entered가 실피해를 적용하지
## 않던 것이므로 직접 호출로 결정적으로 재현한다.
func test_rift_slime_projectile_damages_player() -> void:
	var proj := PROJECTILE_SCENE.instantiate()
	add_child_autofree(proj)
	proj.global_position = _player.global_position
	proj.configure(37.0, FORMULA)  ## 균열 점액 공격력(slime_stats.tres 37)
	var hp_before := _stats.current_hp
	proj._on_body_entered(_player)
	assert_lt(_stats.current_hp, hp_before, "균열 점액 투사체 직격 시 플레이어 HP가 감소해야 한다")
