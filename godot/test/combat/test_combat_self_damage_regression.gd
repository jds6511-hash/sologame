## 디렉터 플레이 게이트 차단 버그 종단 회귀 검증 — 실제 Player 씬(AttackResolver 포함)과
## 몬스터 씬을 배치하고 물리 판정으로 공격을 재현해 "공격 시 플레이어 HP 불변 + 몬스터 HP
## 감소"를 확인한다. test_player_attack_resolver.gd·test_monster_attack_resolver.gd가
## 신호 파이프라인을 더미 대상으로 검증한 것과 달리, 이 테스트는 실제 몬스터 씬과 실제
## 물리 겹침 판정까지 포함한 종단 시나리오다.
extends GutTest

var _player: PlayerController
var _player_stats: PlayerStatsComponent
var _rabbit: MonsterBase


func before_each() -> void:
	_player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(_player)
	_player_stats = _player.get_node("PlayerStats")

	_rabbit = load("res://scenes/monsters/rabbit.tscn").instantiate()
	add_child_autofree(_rabbit)
	_rabbit.global_position = Vector2(20, 0)  ## 1타 히트박스 사거리(1.8타일=28.8px) 이내


func test_player_attack_damages_monster_and_leaves_player_hp_unchanged() -> void:
	var start_hp := _player_stats.current_hp
	_player._enable_attack_hitbox(_player.combo_data.steps[0])

	await wait_physics_frames(2)  ## Area2D 겹침 판정은 물리 프레임이 지나야 갱신된다

	assert_eq(_player_stats.current_hp, start_hp, "공격 시 플레이어 자신의 HP는 변하지 않아야 한다")
	assert_lt(_rabbit.hp, _rabbit.stats.max_hp, "공격 판정이 몬스터에게는 정상적으로 적용되어야 한다")
