## 충돌 레이어 정리 회귀 검증(디렉터 플레이 게이트 차단 버그 수정) — 씬별 collision_layer/
## collision_mask 배치가 project.godot [layer_names] 배치표(1=지형, 2=플레이어, 3=몬스터)와
## 어긋나지 않는지 확인한다. 플레이어 공격 판정이 몬스터 레이어만, 몬스터 근접/원거리
## 판정이 플레이어 레이어만 감지해야 자기 자신·아군을 오탐하지 않는다.
extends GutTest

const LAYER_TERRAIN := 1
const LAYER_PLAYER := 2
const LAYER_MONSTER := 4

const MONSTER_SCENES := [
	"res://scenes/monsters/rabbit.tscn",
	"res://scenes/monsters/wolf.tscn",
	"res://scenes/monsters/rift_slime.tscn",
]


func _load_player() -> PlayerController:
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	return player


func test_player_body_layer_and_mask() -> void:
	var player := _load_player()
	assert_eq(player.collision_layer, LAYER_PLAYER)
	assert_eq(player.collision_mask, LAYER_TERRAIN | LAYER_MONSTER)


func test_player_attack_hitbox_only_targets_monster_layer() -> void:
	var player := _load_player()
	var hitbox: Area2D = player.get_node("Facing/AttackHitbox")
	assert_eq(hitbox.collision_mask, LAYER_MONSTER, "플레이어 공격 판정은 몬스터 레이어만 감지해야 한다(자기 자신 오탐 방지)")


func test_monster_bodies_are_on_monster_layer_and_collide_with_all() -> void:
	for scene_path in MONSTER_SCENES:
		var monster: MonsterBase = load(scene_path).instantiate()
		add_child_autofree(monster)
		assert_eq(monster.collision_layer, LAYER_MONSTER, scene_path)
		assert_eq(monster.collision_mask, LAYER_TERRAIN | LAYER_PLAYER | LAYER_MONSTER, scene_path)


func test_rabbit_attack_hitbox_only_targets_player_layer() -> void:
	var rabbit: MonsterBase = load("res://scenes/monsters/rabbit.tscn").instantiate()
	add_child_autofree(rabbit)
	var hitbox: Area2D = rabbit.get_node("AttackHitbox")
	assert_eq(hitbox.collision_mask, LAYER_PLAYER)


func test_wolf_attack_hitbox_only_targets_player_layer() -> void:
	var wolf: MonsterBase = load("res://scenes/monsters/wolf.tscn").instantiate()
	add_child_autofree(wolf)
	var hitbox: Area2D = wolf.get_node("AttackHitbox")
	assert_eq(hitbox.collision_mask, LAYER_PLAYER)


func test_rift_slime_projectile_only_targets_player_layer() -> void:
	var proj: Area2D = load("res://scenes/monsters/rift_slime_projectile.tscn").instantiate()
	add_child_autofree(proj)
	assert_eq(
		proj.collision_mask,
		LAYER_PLAYER,
		"투사체는 자신을 발사한 균열 점액과 같은 위치에서 스폰되므로, 몬스터 레이어를 감지하면 스폰 즉시 자기 자신에게 명중해버린다"
	)


func test_rift_slime_acid_pool_only_targets_player_layer() -> void:
	var pool: Area2D = load("res://scenes/monsters/rift_slime_acid_pool.tscn").instantiate()
	add_child_autofree(pool)
	assert_eq(pool.collision_mask, LAYER_PLAYER)
