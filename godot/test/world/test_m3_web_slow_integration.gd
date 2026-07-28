## C-10 통합 검증 — 조립한 숲거미 씬의 거미줄이 **실제로 플레이어를 둔화시키는지** 끝까지
## 확인한다. 단위 계약은 이미 각각 검증되어 있으나(ai-dev: 시그널 발신 / gameplay-dev:
## apply_move_speed_slow API), 그 둘을 잇는 것은 씬 조립(투사체 슬롯 할당)이므로 C-10 몫이다.
##
## 연결 고리: ForestSpiderMonster._on_web_fired → _spawn_web_projectile(web_projectile_scene)
## → 투사체 Area2D(mask=2)가 플레이어 몸통(layer=2)에 명중 → hit_target →
## _on_web_projectile_hit → player.apply_move_speed_slow(0.40, 2.0).
##
## 물리 프레임을 실제로 돌려 검증하므로, 거미줄 사거리(2~4타일) 안에 플레이어를 세워
## 상태머신이 스스로 조준(0.6초)→발사→명중에 이르게 한다.
extends GutTest

const SPIDER_SCENE_PATH := "res://scenes/monsters/forest_spider.tscn"
const SHADOW_SCENE_PATH := "res://scenes/monsters/shadow_forest_spider.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const TILE_PX := 16.0
## 거미줄 사거리(2~4타일) 안이면서 도약 최소 거리보다 먼 거리.
const ENGAGE_DISTANCE_PX := 3.0 * TILE_PX
## 조준 0.6초 + 투사체 비행(3타일 / 4타일·초) + 여유. 60fps 기준 프레임 수.
const MAX_WAIT_FRAMES := 150


func _spawn_pair(spider_scene_path: String) -> Array:
	var player: PlayerController = (load(PLAYER_SCENE_PATH) as PackedScene).instantiate()
	player.global_position = Vector2.ZERO
	add_child_autofree(player)
	var spider: ForestSpiderMonster = (load(spider_scene_path) as PackedScene).instantiate()
	spider.global_position = Vector2(ENGAGE_DISTANCE_PX, 0.0)
	spider.target = player
	add_child_autofree(spider)
	return [player, spider]


## 플레이어가 둔화될 때까지 물리 프레임을 돌린다(중간에 플레이어를 제자리에 고정 —
## 헤드리스에는 입력이 없어 스스로 움직이지 않지만, 넉백으로 밀리면 사거리를 벗어난다).
func _wait_for_slow(player: PlayerController, spider: ForestSpiderMonster) -> float:
	for _i in MAX_WAIT_FRAMES:
		await wait_physics_frames(1)
		if player._move_slow_percent > 0.0:
			return player._move_slow_percent
		player.global_position = Vector2.ZERO
		spider.global_position = Vector2(ENGAGE_DISTANCE_PX, 0.0)
	return player._move_slow_percent


func test_forest_spider_web_slows_the_player() -> void:
	var pair := _spawn_pair(SPIDER_SCENE_PATH)
	var player: PlayerController = pair[0]
	var spider: ForestSpiderMonster = pair[1]
	assert_not_null(spider.web_projectile_scene, "씬에 거미줄 투사체가 할당돼 있어야 한다")

	var slow_percent := await _wait_for_slow(player, spider)
	assert_almost_eq(slow_percent, spider.stats.web_slow_pct, 0.0001, "거미줄 명중 시 이동속도 −40%가 적용된다")
	assert_almost_eq(
		player._move_slow_timer,
		spider.stats.web_slow_duration_sec,
		0.05,
		"둔화 지속은 숲거미 데이터(2.0초)를 따른다"
	)
	assert_almost_eq(
		player._resolve_move_speed_px(false),
		player.movement_data.get_walk_speed_px_per_sec() * (1.0 - spider.stats.web_slow_pct),
		0.0001,
		"실제 걷기 속도가 그만큼 느려진다"
	)


## 그림자 숲거미 아종은 같은 스크립트·같은 투사체를 쓰지만 둔화 지속만 3.0초로 길다(spec 7-1).
func test_shadow_forest_spider_web_lasts_longer() -> void:
	var pair := _spawn_pair(SHADOW_SCENE_PATH)
	var player: PlayerController = pair[0]
	var spider: ForestSpiderMonster = pair[1]
	assert_eq(spider.stats.web_slow_duration_sec, 3.0, "야간 아종 거미줄 지속 3.0초")

	var slow_percent := await _wait_for_slow(player, spider)
	assert_gt(slow_percent, 0.0, "야간 아종도 실제로 둔화를 건다")
	assert_almost_eq(player._move_slow_timer, 3.0, 0.05, "지속이 3.0초로 적용된다")


## 거미줄은 무피해(spec 3-2)여야 한다 — 투사체에 formula_data를 넘기지 않으므로 직격 피해 0.
func test_web_projectile_deals_no_damage() -> void:
	var pair := _spawn_pair(SPIDER_SCENE_PATH)
	var player: PlayerController = pair[0]
	var spider: ForestSpiderMonster = pair[1]
	var stats_component: PlayerStatsComponent = player.get_node("PlayerStats")
	var hp_before := stats_component.current_hp

	await _wait_for_slow(player, spider)
	assert_eq(stats_component.current_hp, hp_before, "거미줄 명중은 피해를 주지 않는다")
