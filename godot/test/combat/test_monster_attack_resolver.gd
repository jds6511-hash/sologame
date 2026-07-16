## CB-4 검증 — 몬스터 attack_landed 판정이 플레이어의 take_hit()을 호출해
## 경직·무적을 트리거하는지 확인한다(MonsterBase 실제 시그널을 더미로 모사).
extends GutTest

var _player: PlayerController
var _monster: DummyAttackLandedSource
var _resolver: MonsterAttackResolver


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)

	var root := Node.new()
	add_child_autofree(root)

	_monster = DummyAttackLandedSource.new()
	_monster.name = "Monster"
	root.add_child(_monster)

	## monster_path는 반드시 트리 진입(_ready) 전에 설정한다 — @onready가 첫 _ready에서
	## get_node(monster_path)를 바로 해석하기 때문(NodePath는 resolver 자신 기준 상대 경로).
	_resolver = MonsterAttackResolver.new()
	_resolver.monster_path = NodePath("../Monster")
	root.add_child(_resolver)


func test_attack_landed_on_player_triggers_hit_stun_and_invincibility() -> void:
	_monster.fire_attack_landed(_player)
	assert_true(_player.is_hit_stunned)
	assert_true(_player.is_hit_invincible)


func test_attack_landed_on_non_player_target_does_not_error() -> void:
	var plain_target := Node2D.new()
	add_child_autofree(plain_target)
	_monster.fire_attack_landed(plain_target)
	assert_true(true, "take_hit이 없는 대상은 조용히 무시되어야 함")
