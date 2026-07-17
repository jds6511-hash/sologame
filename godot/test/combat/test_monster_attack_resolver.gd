## CB-4/M2 Phase3 검증 — 몬스터 attack_landed 판정이 플레이어의 take_hit()을 호출해
## 경직·무적을 트리거하고(MonsterBase 실제 시그널을 더미로 모사), DamageCalculator(CB-3)로
## 계산한 실데미지를 PlayerStatsComponent에 적용하는지 확인한다.
##
## 데미지 검산: combat.md 8-1장 "몬스터 공격력은 그대로 6장 공식에 넣으면 결과가 플레이어
## 최대 HP의 10%에 근접하도록 역산된 값"이라는 성질을 그대로 이용한다 — 뿔토끼 공격력(15,
## m2-monster-spec.md 3-1장, 역산값 15.39를 정수로 반올림한 표기)을 Lv1 전사(HP 135, 방어
## 14) 기준으로 넣으면 방어 감산 100/114를 거쳐 랜덤 보정(0.95~1.05) 이내에서 약 13.16
## (=15x100/114, "10%인 13.5"에 근접하되 표의 반올림 오차만큼 차이)이 나와야 한다.
extends GutTest

var _player: PlayerController
var _stats: PlayerStatsComponent
var _monster: DummyAttackLandedSource
var _resolver: MonsterAttackResolver


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_stats = _player.get_node("PlayerStats")

	var root := Node.new()
	add_child_autofree(root)

	_monster = DummyAttackLandedSource.new()
	_monster.name = "Monster"
	var monster_stats := MonsterStatsData.new()
	monster_stats.attack_power = 15.0  ## m2-monster-spec.md 3-1장 뿔토끼
	_monster.stats = monster_stats
	root.add_child(_monster)

	## monster_path는 반드시 트리 진입(_ready) 전에 설정한다 — @onready가 첫 _ready에서
	## get_node(monster_path)를 바로 해석하기 때문(NodePath는 resolver 자신 기준 상대 경로).
	_resolver = MonsterAttackResolver.new()
	_resolver.monster_path = NodePath("../Monster")
	_resolver.formula_data = load("res://data/combat/damage_formula.tres")
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


func test_attack_landed_applies_real_damage_close_to_10_percent_of_player_max_hp() -> void:
	_monster.fire_attack_landed(_player)
	var damage_taken: float = 135.0 - _stats.current_hp
	var expected_base := 15.0 * (100.0 / (100.0 + 14.0))
	assert_between(damage_taken, expected_base * 0.95, expected_base * 1.05)


func test_attack_landed_while_invincible_applies_no_damage() -> void:
	_player.is_dash_invincible = true
	_monster.fire_attack_landed(_player)
	assert_eq(_stats.current_hp, 135.0, "무적 중에는 경직뿐 아니라 데미지도 적용되지 않아야 함")


func test_attack_landed_without_formula_data_skips_damage_gracefully() -> void:
	_resolver.formula_data = null
	_monster.fire_attack_landed(_player)
	assert_true(_player.is_hit_stunned, "경직 반응은 그대로 성립해야 함")
	assert_eq(_stats.current_hp, 135.0, "formula_data가 없으면 데미지 계산을 건너뛰어야 함")
