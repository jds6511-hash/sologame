## C-10 검증 — 신규 적 7종 씬(.tscn)이 wolf.tscn 선례 구조대로 조립됐는지, 씬에 물린
## 데이터(스탯·경직 규칙·데미지 공식·투사체)와 드랍 레지스트리 배선이 맞는지 확인한다.
##
## 스프라이트는 pixel-artist C-9 완료 전까지 M2 기존 시트를 임시 재사용하므로, 텍스처 경로는
## 검사하지 않는다(정식 교체 시 이 테스트가 깨지지 않아야 한다). 대신 "애니메이션 4종
## (idle/walk/attack/death)이 존재한다"는 계약만 본다 — MonsterBase._die()가 death를,
## _play_animation_or()가 idle/walk/attack 폴백을 요구하기 때문이다.
extends GutTest

const SCENE_DIR := "res://scenes/monsters/"
const LIGHT_RULES_PATH := "res://data/combat/mob_stagger_rules_light.tres"
const STANDARD_RULES_PATH := "res://data/combat/mob_stagger_rules.tres"

## 씬 파일 → [기대 display_name, 기대 MobStagger rules 경로]
## (m3-monster-spec.md 8-1장 총괄표 "MobStagger rules.tres" 행: 숲거미·임프=light / 무법자=표준)
const EXPECTED := {
	"forest_spider.tscn": ["숲거미", LIGHT_RULES_PATH],
	"shadow_forest_spider.tscn": ["그림자 숲거미", LIGHT_RULES_PATH],
	"outlaw.tscn": ["무법자", STANDARD_RULES_PATH],
	"highwayman.tscn": ["노상강도", STANDARD_RULES_PATH],
	"poacher.tscn": ["밀렵꾼", STANDARD_RULES_PATH],
	"imp.tscn": ["임프", LIGHT_RULES_PATH],
	"imp_lord.tscn": ["포효 임프장", LIGHT_RULES_PATH],
}

const REQUIRED_ANIMATIONS := ["idle", "walk", "attack", "death"]


func _instantiate(file_name: String) -> MonsterBase:
	var scene: PackedScene = load(SCENE_DIR + file_name)
	assert_not_null(scene, "%s 로드 실패" % file_name)
	var monster := scene.instantiate() as MonsterBase
	assert_not_null(monster, "%s 는 MonsterBase 인스턴스여야 한다" % file_name)
	autofree(monster)
	return monster


# --- 씬 존재·필수 자식 노드 (wolf.tscn 선례 구조) ---


func test_all_seven_scenes_exist_and_instantiate() -> void:
	for file_name in EXPECTED:
		assert_true(ResourceLoader.exists(SCENE_DIR + file_name), "%s 씬 파일이 있어야 한다" % file_name)
		var monster := _instantiate(file_name)
		assert_true(monster is CharacterBody2D, "%s 루트는 CharacterBody2D" % file_name)


func test_required_child_nodes_follow_wolf_scene_layout() -> void:
	for file_name in EXPECTED:
		var monster := _instantiate(file_name)
		for path in [
			"CollisionShape2D",
			"Sprite",
			"AttackHitbox",
			"AttackHitbox/CollisionShape2D",
			"MobStagger",
			"AttackResolver"
		]:
			assert_not_null(monster.get_node_or_null(path), "%s: %s 노드 필요" % [file_name, path])


func test_collision_layers_match_wolf_scene() -> void:
	for file_name in EXPECTED:
		var monster := _instantiate(file_name)
		assert_eq(monster.collision_layer, 4, "%s 몬스터 레이어" % file_name)
		assert_eq(monster.collision_mask, 7, "%s 몬스터 마스크" % file_name)
		var hitbox: Area2D = monster.get_node("AttackHitbox")
		assert_eq(hitbox.collision_layer, 0, "%s 히트박스 레이어" % file_name)
		assert_eq(hitbox.collision_mask, 2, "%s 히트박스 마스크(플레이어)" % file_name)
		assert_false(hitbox.monitoring, "%s 히트박스는 판정 구간에만 켜진다" % file_name)


# --- 콜리전 캡슐 규격 (M2 degenerate 캡슐 문제 재발 방지) ---


func test_collision_capsule_height_is_at_least_double_radius() -> void:
	for file_name in EXPECTED:
		var monster := _instantiate(file_name)
		var shape_node: CollisionShape2D = monster.get_node("CollisionShape2D")
		var capsule := shape_node.shape as CapsuleShape2D
		assert_not_null(capsule, "%s: 몸통 콜리전은 CapsuleShape2D" % file_name)
		assert_gt(capsule.radius, 0.0, "%s: 반경 > 0" % file_name)
		assert_gte(
			capsule.height,
			capsule.radius * 2.0,
			"%s: 캡슐 height(%.1f) >= 2*radius(%.1f) 준수" % [file_name, capsule.height, capsule.radius]
		)


# --- 씬에 물린 데이터 (스탯 / 경직 규칙 / 데미지 공식) ---


func test_stats_resource_matches_species() -> void:
	for file_name in EXPECTED:
		var monster := _instantiate(file_name)
		assert_not_null(monster.stats, "%s: stats 미할당" % file_name)
		assert_eq(monster.stats.display_name, EXPECTED[file_name][0], "%s: 스탯 리소스" % file_name)


func test_mob_stagger_rules_match_knockback_class() -> void:
	for file_name in EXPECTED:
		var monster := _instantiate(file_name)
		var stagger: MobStaggerComponent = monster.get_node("MobStagger")
		assert_not_null(stagger.rules, "%s: MobStagger rules 미할당" % file_name)
		assert_eq(stagger.rules.resource_path, EXPECTED[file_name][1], "%s: 넉백 체급 규칙" % file_name)


func test_attack_resolver_is_wired_to_root_with_damage_formula() -> void:
	for file_name in EXPECTED:
		var monster := _instantiate(file_name)
		var resolver: MonsterAttackResolver = monster.get_node("AttackResolver")
		assert_eq(resolver.monster_path, NodePath(".."), "%s: 리졸버 대상 경로" % file_name)
		assert_not_null(resolver.formula_data, "%s: 데미지 공식 리소스 미할당" % file_name)


func test_sprite_has_four_base_animations() -> void:
	for file_name in EXPECTED:
		var monster := _instantiate(file_name)
		var sprite: AnimatedSprite2D = monster.get_node("Sprite")
		assert_not_null(sprite.sprite_frames, "%s: SpriteFrames 미할당" % file_name)
		for anim in REQUIRED_ANIMATIONS:
			assert_true(
				sprite.sprite_frames.has_animation(anim), "%s: %s 애니메이션 필요" % [file_name, anim]
			)


# --- 투사체 슬롯 (ai-dev 인수 사항 4) ---


func test_forest_spiders_have_web_projectile_scene() -> void:
	for file_name in ["forest_spider.tscn", "shadow_forest_spider.tscn"]:
		var spider := _instantiate(file_name) as ForestSpiderMonster
		assert_not_null(spider.web_projectile_scene, "%s: 거미줄 투사체 씬 할당 필요" % file_name)


func test_poacher_has_crossbow_projectile_and_formula() -> void:
	var poacher := _instantiate("poacher.tscn") as OutlawMonster
	assert_not_null(poacher.projectile_scene, "밀렵꾼: 석궁 볼트 씬 할당 필요")
	assert_not_null(poacher.formula_data, "밀렵꾼: 석궁 직격 피해 공식 할당 필요")
	assert_true(poacher.stats.uses_ranged_attack, "밀렵꾼은 돌진 대신 조준 사격 조합")


func test_melee_outlaws_do_not_use_ranged_switch() -> void:
	for file_name in ["outlaw.tscn", "highwayman.tscn"]:
		var outlaw := _instantiate(file_name) as OutlawMonster
		assert_false(outlaw.stats.uses_ranged_attack, "%s: 돌진 조합 유지" % file_name)


# --- 무리 식별자 (ai-dev 인수 사항 2) ---


func test_pack_id_defaults_empty_and_spider_has_no_pack_field() -> void:
	for file_name in [
		"outlaw.tscn", "highwayman.tscn", "poacher.tscn", "imp.tscn", "imp_lord.tscn"
	]:
		var monster := _instantiate(file_name)
		assert_true("pack_id" in monster, "%s: pack_id 필드 필요(스포너가 주입)" % file_name)
		assert_eq(monster.get("pack_id"), "", "%s: pack_id 기본값은 빈 문자열" % file_name)
	var spider := _instantiate("forest_spider.tscn")
	assert_false("pack_id" in spider, "숲거미는 개별 급습 — pack_id 개념 없음(spec 4-1)")


func test_pack_aggro_sharing_flags_match_spec() -> void:
	for file_name in ["forest_spider.tscn", "shadow_forest_spider.tscn"]:
		var spider := _instantiate(file_name)
		assert_false(spider.stats.shares_pack_aggro, "%s: 어그로 공유 없음" % file_name)
	for file_name in [
		"outlaw.tscn", "highwayman.tscn", "poacher.tscn", "imp.tscn", "imp_lord.tscn"
	]:
		var monster := _instantiate(file_name)
		assert_true(monster.stats.shares_pack_aggro, "%s: 어그로 공유 O" % file_name)


func test_imp_lord_is_elite() -> void:
	var lord := _instantiate("imp_lord.tscn")
	assert_true(lord.stats.is_elite, "포효 임프장은 정예(평시 슈퍼아머)")
	for file_name in EXPECTED:
		if file_name == "imp_lord.tscn":
			continue
		assert_false(_instantiate(file_name).stats.is_elite, "%s: 잡몹 등급" % file_name)


# --- 드랍·EXP 배선 (ai-dev 인수 사항 3) ---


func test_drop_registry_resolves_every_new_scene() -> void:
	for file_name in EXPECTED:
		var monster := _instantiate(file_name)
		var table := MonsterDropRegistry.table_for(monster)
		assert_not_null(table, "%s: 드랍 테이블 조회 실패" % file_name)
		assert_eq(
			table.monster_display_name, EXPECTED[file_name][0], "%s: 드랍 테이블이 종과 일치해야 한다" % file_name
		)


func test_drop_registry_covers_m2_species_too() -> void:
	for file_name in ["rabbit.tscn", "wolf.tscn", "rift_slime.tscn"]:
		var monster := _instantiate(file_name)
		assert_not_null(MonsterDropRegistry.table_for(monster), "%s: M2 종 드랍 테이블 회귀" % file_name)


func test_drop_registry_returns_null_for_unknown_node() -> void:
	assert_null(MonsterDropRegistry.table_for(null), "null 입력은 null 반환")
	var plain := Node.new()
	autofree(plain)
	assert_null(MonsterDropRegistry.table_for(plain), "stats 없는 노드는 null 반환")
