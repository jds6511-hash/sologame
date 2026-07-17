## M2 후반 통합 검증 — MobStaggerComponent(gameplay-dev, scripts/combat, 수정 없음)가
## 몬스터 3종 씬에 체급별 rules(.tres)로 정확히 배선되고, take_damage() 경로가 실제로
## 경직·넉백을 발동시키는지 확인한다(뿔토끼=경량/들개 마수=표준/균열 점액=중량,
## m2-monster-spec.md 6장, combat.md 5-2-1장).
extends GutTest

var _attacker: Node2D


func before_each() -> void:
	_attacker = Node2D.new()
	add_child_autofree(_attacker)


func _load_monster(scene_path: String) -> MonsterBase:
	var scene: PackedScene = load(scene_path)
	var monster: MonsterBase = scene.instantiate()
	add_child_autofree(monster)
	monster.global_position = Vector2.ZERO
	_attacker.global_position = Vector2(100, 0)  ## 몬스터 기준 오른쪽에서 공격
	return monster


# --- 배선 확인: 체급별 rules 리소스가 정확히 붙었는가 ---


func test_rabbit_has_light_weight_stagger_rules() -> void:
	var rabbit := _load_monster("res://scenes/monsters/rabbit.tscn")
	var stagger: MobStaggerComponent = rabbit.get_node("MobStagger")
	assert_not_null(stagger, "뿔토끼 씬에 MobStagger 노드가 배선되어야 함")
	assert_eq(stagger.rules.light_knockback_tiles, 0.3, "경량 체급 일반 타격 넉백")
	assert_eq(stagger.rules.heavy_knockback_tiles, 0.7, "경량 체급 강타·치명타 넉백")


func test_wolf_has_standard_weight_stagger_rules() -> void:
	var wolf := _load_monster("res://scenes/monsters/wolf.tscn")
	var stagger: MobStaggerComponent = wolf.get_node("MobStagger")
	assert_not_null(stagger, "들개 마수 씬에 MobStagger 노드가 배선되어야 함")
	assert_eq(stagger.rules.light_knockback_tiles, 0.2, "표준 체급 일반 타격 넉백")
	assert_eq(stagger.rules.heavy_knockback_tiles, 0.45, "표준 체급 강타·치명타 넉백")


func test_rift_slime_has_heavy_weight_stagger_rules() -> void:
	var slime := _load_monster("res://scenes/monsters/rift_slime.tscn")
	var stagger: MobStaggerComponent = slime.get_node("MobStagger")
	assert_not_null(stagger, "균열 점액 씬에 MobStagger 노드가 배선되어야 함")
	assert_eq(stagger.rules.light_knockback_tiles, 0.1, "중량 체급 일반 타격 넉백")
	assert_eq(stagger.rules.heavy_knockback_tiles, 0.25, "중량 체급 강타·치명타 넉백")


# --- 실제 동작 확인: take_damage() -> 경직·넉백 (뿔토끼로 대표 검증) ---


func test_take_damage_triggers_staggered_state() -> void:
	var rabbit := _load_monster("res://scenes/monsters/rabbit.tscn")
	assert_false(rabbit.is_staggered())
	rabbit.take_damage(1.0, "약", _attacker)
	assert_true(rabbit.is_staggered(), "일반 타격도 경직을 유발해야 함")


func test_knockback_velocity_points_away_from_attacker() -> void:
	var rabbit := _load_monster("res://scenes/monsters/rabbit.tscn")
	rabbit.take_damage(1.0, "약", _attacker)  ## 공격자가 오른쪽(+x)에 있음
	rabbit._physics_process(0.001)
	assert_lt(rabbit.velocity.x, 0.0, "공격자 반대 방향(왼쪽)으로 밀려나야 함")


func test_heavy_grade_hit_uses_heavy_knockback_speed() -> void:
	var rabbit := _load_monster("res://scenes/monsters/rabbit.tscn")
	rabbit.take_damage(1.0, "강", _attacker)
	assert_true(rabbit.is_staggered())
	rabbit._physics_process(0.001)
	var expected_heavy_speed: float = 0.7 * 16.0 / 0.25  ## 경량 체급 강타·치명타 넉백 거리/경직 시간
	assert_almost_eq(absf(rabbit.velocity.x), expected_heavy_speed, 0.5)


func test_third_consecutive_light_hit_triggers_superarmor_and_blocks_further_stagger() -> void:
	## MobStaggerComponent의 타이머는 자신의 _process(엔진 idle 프레임)로만 흐른다 —
	## 몬스터의 _physics_process를 수동 호출해도 컴포넌트 타이머는 흐르지 않으므로
	## (test_mob_stagger_component.gd와 동일하게) advance_time()을 직접 호출해 진행시킨다.
	var wolf := _load_monster("res://scenes/monsters/wolf.tscn")
	var stagger: MobStaggerComponent = wolf.get_node("MobStagger")
	wolf.take_damage(1.0, "약", _attacker)
	stagger.advance_time(0.15)  ## 첫 경직 종료
	wolf.take_damage(1.0, "약", _attacker)
	stagger.advance_time(0.15)  ## 두 번째 경직 종료
	wolf.take_damage(1.0, "약", _attacker)
	stagger.advance_time(0.15)  ## 세 번째 경직 종료 -> 슈퍼아머 진입

	assert_true(stagger.is_superarmor(), "연속 경직 3회 후 슈퍼아머로 전환되어야 함")

	wolf.take_damage(1.0, "약", _attacker)
	assert_false(wolf.is_staggered(), "슈퍼아머 중에는 경직이 걸리지 않아야 함")


func test_lethal_hit_does_not_register_stagger() -> void:
	var rabbit := _load_monster("res://scenes/monsters/rabbit.tscn")
	rabbit.take_damage(9999.0, "약", _attacker)
	assert_true(rabbit.is_dead())
	assert_false(rabbit.is_staggered(), "즉사 타격은 경직 등록 없이 바로 사망 처리되어야 함")
