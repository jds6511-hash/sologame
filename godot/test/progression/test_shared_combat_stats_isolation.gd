## 공유 CombatantStats 격리 검증 — 파일 백업 리소스 in-place 오염 방지(M3 기술 부채).
##
## player.tscn은 AttackResolver·PlayerStats·PlayerStatGrowth가 **하나의** CombatantStats를
## 공유한다(m3-gear-growth-wiring.md 3장). 그 공유 인스턴스가 파일 백업 리소스
## (warrior_lv1_combatant_stats.tres) 그 자체였을 때, Lv1 전직이 유발하는 recompute_stats(1)이
## 파일 리소스를 직접 변형해 Godot 리소스 캐시를 오염시켰다 — 같은 프로세스에서 이후 생성되는
## 모든 플레이어가 Lv1 스냅샷(공격 26.0 / 방어 14.0) 대신 Lv1 정밀값(25.6 / 14.5)을 보게 된다.
## 테스트만의 문제가 아니라 실런타임 문제였다(월드 재진입·씬 전환 시 스냅샷 소실).
##
## 검증 축 셋:
##   ① 씬 인스턴스는 파일 리소스를 직접 물지 않는다(파일 = 초기값 템플릿).
##   ② 그러면서도 한 인스턴스 안에서는 세 소비자가 **같은** 인스턴스를 본다(공유 구조 유지 —
##      스탯 재계산이 데미지·방어 공식으로 퍼지는 경로가 설계 의도다).
##   ③ Lv1 전직 후에도 파일 리소스와 새 인스턴스는 Lv1 스냅샷을 유지한다
##      (m3-leveling-spec.md 7-5·8-1: Lv1은 스냅샷, Lv2부터 재계산이 넘겨받는다).
extends GutTest

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const STATS_PATH := "res://data/combat/warrior_lv1_combatant_stats.tres"

## Lv1 스냅샷 값(.tres 저장값 = 표시 반올림 기준, spec 8-1).
const SNAPSHOT_ATTACK := 26.0
const SNAPSHOT_DEFENSE := 14.0
## (레벨, 직업) 순수 함수의 Lv1 정밀값 — 재계산이 실제로 돌았음을 확인하는 대조값.
const RECOMPUTED_ATTACK := 25.6
const RECOMPUTED_DEFENSE := 14.5

const TOL := 0.0001

## 씬이 참조하는 것과 동일한 캐시 인스턴스(오염 대상).
var _file_stats: CombatantStats


func before_each() -> void:
	_file_stats = load(STATS_PATH) as CombatantStats


func _spawn_player() -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func _shared_stats(player: PlayerController) -> CombatantStats:
	return (player.get_node("PlayerStatGrowth") as PlayerStatGrowth).combat_stats


## Lv1 상태에서 전직을 강행해 recompute_stats(1)을 유발한다(오염 재현 경로).
func _force_level1_transition(player: PlayerController) -> void:
	var transition: PlayerJobTransition = player.get_node("PlayerJobTransition")
	transition.transition_available = true
	assert_true(transition.perform_transition(&"warrior"), "전제: Lv1 전직 강행 성공")


# --- ① 파일 리소스는 템플릿일 뿐 씬 인스턴스에 직접 물리지 않는다 ---


func test_scene_instance_does_not_hold_file_backed_resource() -> void:
	var stats := _shared_stats(_spawn_player())
	assert_ne(stats, _file_stats, "씬 인스턴스의 공유 스탯은 파일 리소스 그 자체가 아니어야 한다")
	assert_eq(stats.resource_path, "", "사본은 파일 경로를 갖지 않는다(디스크·캐시와 무관)")


func test_two_player_instances_get_separate_stats() -> void:
	var first := _shared_stats(_spawn_player())
	var second := _shared_stats(_spawn_player())
	assert_ne(first, second, "인스턴스마다 별도 사본이어야 서로 오염되지 않는다")


func test_fresh_instance_starts_from_snapshot_values() -> void:
	var stats := _shared_stats(_spawn_player())
	assert_almost_eq(stats.attack_power, SNAPSHOT_ATTACK, TOL, "Lv1 스냅샷 공격력")
	assert_almost_eq(stats.defense, SNAPSHOT_DEFENSE, TOL, "Lv1 스냅샷 방어력")


# --- ② 공유 참조 구조는 유지된다 ---


func test_three_consumers_share_one_instance() -> void:
	var player := _spawn_player()
	var shared := _shared_stats(player)
	var resolver_stats: CombatantStats = player.get_node("AttackResolver").attacker_stats
	var component_stats: CombatantStats = (
		(player.get_node("PlayerStats") as PlayerStatsComponent).stats
	)
	assert_eq(resolver_stats, shared, "AttackResolver가 같은 인스턴스를 봐야 한다")
	assert_eq(component_stats, shared, "PlayerStats가 같은 인스턴스를 봐야 한다")


## 월드 씬은 player.tscn을 중첩 인스턴스로 품는다 — 사본 리맵은 player.tscn 인스턴스화
## 단위로 일어나므로, 월드 안의 Player도 세 참조가 하나의 사본을 공유해야 한다.
## (주의: 월드 씬 노드가 이 .tres를 **직접** 참조하면 그건 별개의 사본이 된다 —
## Inventory 노드의 combat_stats 비배선은 m3-gear-growth-wiring.md 3장 요구사항이기도 하다.)
func test_world_scene_player_shares_one_local_instance() -> void:
	var world_scene: PackedScene = load("res://scenes/world/eastern_frontier_starting_area.tscn")
	var world: Node = world_scene.instantiate()
	add_child_autofree(world)
	var player: PlayerController = world.get_node("Player")
	var shared := _shared_stats(player)
	assert_ne(shared, _file_stats, "월드 씬 Player도 파일 리소스를 직접 물지 않는다")
	assert_eq(player.get_node("AttackResolver").attacker_stats, shared, "월드 씬 — AttackResolver 공유")
	assert_eq(
		(player.get_node("PlayerStats") as PlayerStatsComponent).stats,
		shared,
		"월드 씬 — PlayerStats 공유"
	)
	assert_null(player.get_node("Inventory").combat_stats, "월드 씬 Inventory는 공유 스탯에 배선되지 않는다")


func test_recompute_propagates_through_shared_instance() -> void:
	var player := _spawn_player()
	_force_level1_transition(player)
	var resolver_stats: CombatantStats = player.get_node("AttackResolver").attacker_stats
	## 재계산은 PlayerStatGrowth.combat_stats에만 쓰지만, 공유 인스턴스이므로 전투 공식 쪽에도
	## 그대로 보인다 — 이 경로가 깨지면 스탯 변경이 데미지에 반영되지 않는다.
	assert_almost_eq(resolver_stats.defense, RECOMPUTED_DEFENSE, TOL, "재계산 결과가 공유 참조로 전파")
	assert_almost_eq(resolver_stats.attack_power, RECOMPUTED_ATTACK, TOL, "공격력도 동일 인스턴스")


# --- ③ Lv1 전직이 파일 리소스·다른 인스턴스를 오염시키지 않는다 ---


func test_level1_transition_does_not_pollute_file_resource() -> void:
	_force_level1_transition(_spawn_player())
	assert_almost_eq(_file_stats.defense, SNAPSHOT_DEFENSE, TOL, "파일 리소스 방어력 = Lv1 스냅샷 유지")
	assert_almost_eq(_file_stats.attack_power, SNAPSHOT_ATTACK, TOL, "파일 리소스 공격력 = Lv1 스냅샷 유지")


func test_transition_on_one_player_leaves_next_player_clean() -> void:
	_force_level1_transition(_spawn_player())
	var next_stats := _shared_stats(_spawn_player())
	assert_almost_eq(next_stats.defense, SNAPSHOT_DEFENSE, TOL, "이후 생성 인스턴스도 Lv1 스냅샷")
	assert_almost_eq(next_stats.attack_power, SNAPSHOT_ATTACK, TOL, "이후 생성 인스턴스도 Lv1 스냅샷")
