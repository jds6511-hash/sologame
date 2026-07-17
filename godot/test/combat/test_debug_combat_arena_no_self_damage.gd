## 디렉터 플레이 게이트 차단 버그 실동작 검증 — 실제 디버그 전투장 씬
## (scenes/debug/debug_combat_arena.tscn)을 그대로 인스턴스화해 F1(뿔토끼 소환)과 동일한
## 경로(_spawn_monster)로 몬스터를 배치하고, 공격 판정을 물리 프레임으로 재현해
## "공격 시 플레이어 HP 불변 + 몬스터 HP 감소"를 확인한다.
extends GutTest

var _arena: DebugCombatArena
var _player: PlayerController
var _player_stats: PlayerStatsComponent


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/debug/debug_combat_arena.tscn")
	_arena = scene.instantiate()
	add_child_autofree(_arena)
	_player = _arena.get_node("Player")
	_player_stats = _player.get_node("PlayerStats")


func test_attacking_spawned_monster_does_not_damage_player() -> void:
	_arena._spawn_monster(_arena.RABBIT_SCENE, "뿔토끼")
	await wait_physics_frames(2)

	var rabbit: MonsterBase = null
	for child in _arena.get_node("MonstersRoot").get_children():
		if child is MonsterBase:
			rabbit = child
	assert_not_null(rabbit, "F1과 동일한 경로로 뿔토끼가 소환되어야 한다")

	## 헤드리스 환경에는 실제 마우스 입력이 없어 _update_facing_to_mouse()가 매 프레임
	## 계산하는 방향이 테스트 환경(카메라 위치 등)에 좌우된다 — 실제로 안정된 정면 방향을
	## 먼저 관찰한 뒤, 그 방향에 뿔토끼를 배치해 "정면 부채꼴 판정 이내"라는 실제 플레이
	## 조건을 그대로 재현한다(임의로 각도를 고정하지 않음).
	await wait_physics_frames(2)
	var forward: Vector2 = _player._facing.global_transform.x.normalized()
	rabbit.global_position = _player.global_position + forward * 20.0  ## 1타 사거리 이내
	await wait_physics_frames(2)  ## 재배치된 위치가 물리 엔진에 반영될 시간을 확보한다

	var player_hp_before := _player_stats.current_hp
	var rabbit_hp_before := rabbit.hp

	_player._enable_attack_hitbox(_player.combo_data.steps[0])
	await wait_physics_frames(2)

	gut.p(
		(
			"공격 전: 플레이어 HP=%s, 뿔토끼 HP=%s / 공격 후: 플레이어 HP=%s, 뿔토끼 HP=%s"
			% [player_hp_before, rabbit_hp_before, _player_stats.current_hp, rabbit.hp]
		)
	)

	assert_eq(_player_stats.current_hp, player_hp_before, "공격 시 플레이어 자신의 HP는 변하지 않아야 한다")
	assert_lt(rabbit.hp, rabbit_hp_before, "공격 판정이 몬스터에게는 정상적으로 적용되어야 한다")
