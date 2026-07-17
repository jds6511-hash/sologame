## UI-4 검증 — TutorialController(온보딩 6단계, onboarding.md 3장)의 단계 전환·진행 게이트
## 없음(1장 원칙2)을 재현한다. player_controller.gd·rabbit_monster.gd는 test_rabbit_monster.gd·
## test_player_attack_resolver.gd와 동일하게 private 메서드/시그널을 직접 호출해 조건을
## 격리한다(상태 전이 자체는 이미 CB-6/CB-2 테스트가 검증했으므로 여기서는 재검증하지 않는다).
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const RABBIT_SCENE := preload("res://scenes/monsters/rabbit.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const HINT_BAR_SCENE := preload("res://scenes/ui/onboarding_hint_bar.tscn")

var _player: PlayerController
var _player_stats: PlayerStatsComponent
var _hud: Hud
var _hint_bar: OnboardingHintBar
var _inventory: InventoryComponent
var _drop_system: DropSystem
var _tutorial: TutorialController


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player_stats = _player.get_node("PlayerStats")

	_hud = HUD_SCENE.instantiate()
	add_child_autofree(_hud)

	_hint_bar = HINT_BAR_SCENE.instantiate()
	add_child_autofree(_hint_bar)

	_inventory = InventoryComponent.new()
	add_child_autofree(_inventory)
	_drop_system = DropSystem.new()
	add_child_autofree(_drop_system)

	_tutorial = TutorialController.new()
	add_child_autofree(_tutorial)


func after_each() -> void:
	Input.action_release("move_up")


func _spawn_rabbit() -> RabbitMonster:
	var rabbit: RabbitMonster = RABBIT_SCENE.instantiate()
	add_child_autofree(rabbit)
	return rabbit


func _start_tutorial(rabbits: Array[RabbitMonster] = []) -> void:
	_tutorial.start(_player, _player_stats, _inventory, _drop_system, _hud, _hint_bar, rabbits)


# --- 1단계: 이동 ---


func test_move_stage_shows_hint_and_completes_after_3_tiles() -> void:
	_start_tutorial()
	_tutorial._process(0.016)
	_hint_bar._process(0.3)
	assert_eq(_hint_bar.get_node("Panel/Label").text, TutorialController.MOVE_TEXT)

	_player.global_position += Vector2(3 * 16, 0)  ## 3타일 이동
	_tutorial._process(0.016)

	assert_true(_tutorial._moved_tiles >= 3.0)
	assert_eq(_tutorial._stage, TutorialController.Stage.ATTACK)


func test_move_hint_suppressed_when_move_key_already_pressed() -> void:
	Input.action_press("move_up")
	_start_tutorial()
	_tutorial._process(0.016)
	_hint_bar._process(0.3)
	assert_false(_hint_bar.get_node("Panel").visible, "이미 이동 입력 중이면 힌트를 생략해야 한다")


# --- 2단계: 기본 공격 ---


func test_attack_stage_completes_on_base_attack_hit() -> void:
	var rabbit := _spawn_rabbit()
	rabbit.global_position = _player.global_position
	var rabbits: Array[RabbitMonster] = [rabbit]
	_start_tutorial(rabbits)
	_tutorial._process(0.016)  ## 1단계 완료 전이므로 아직 ATTACK 아님
	_player.global_position += Vector2(3 * 16, 0)
	_tutorial._process(0.016)  ## 1단계 완료 -> 2단계 진입
	assert_eq(_tutorial._stage, TutorialController.Stage.ATTACK)

	_tutorial._on_attack_hit(_player.combo_data.steps[0], rabbit)

	_tutorial._process(0.016)
	assert_eq(_tutorial._stage, TutorialController.Stage.FLEE_DASH)


func test_attack_stage_ignores_skill_hit() -> void:
	var rabbit := _spawn_rabbit()
	rabbit.global_position = _player.global_position
	var rabbits: Array[RabbitMonster] = [rabbit]
	_start_tutorial(rabbits)
	_player.global_position += Vector2(3 * 16, 0)
	_tutorial._process(0.016)

	_tutorial._on_attack_hit(_player.skill_slot_1, rabbit)  ## 스킬 판정 — 기본 공격 아님

	_tutorial._process(0.016)
	assert_eq(_tutorial._stage, TutorialController.Stage.ATTACK, "스킬 히트는 2단계(기본 공격) 완료 조건이 아니다")


# --- 3단계: 회피 ---


func test_flee_dash_completes_on_dash_after_rabbit_flees() -> void:
	var rabbit := _spawn_rabbit()
	var rabbits: Array[RabbitMonster] = [rabbit]
	_start_tutorial(rabbits)
	_tutorial._stage = TutorialController.Stage.FLEE_DASH  ## 선행 단계는 별도 테스트로 검증됨

	rabbit._start_flee()
	_tutorial._process(0.016)
	assert_true(_tutorial._rabbit_fled_ever)

	_player.dash_started.emit()
	_tutorial._process(0.016)
	assert_eq(_tutorial._stage, TutorialController.Stage.PARRY_DODGE)


func test_parry_dodge_completes_when_dash_within_window() -> void:
	var rabbit := _spawn_rabbit()
	var rabbits: Array[RabbitMonster] = [rabbit]
	_start_tutorial(rabbits)
	_tutorial._stage = TutorialController.Stage.PARRY_DODGE

	rabbit._start_melee_swing()
	_tutorial._process(0.016)
	assert_true(_tutorial._rabbit_swing_ever)

	_player.dash_started.emit()
	_tutorial._process(0.016)
	assert_eq(_tutorial._stage, TutorialController.Stage.SKILL)


func test_parry_dodge_not_learned_when_dash_outside_window() -> void:
	var rabbit := _spawn_rabbit()
	var rabbits: Array[RabbitMonster] = [rabbit]
	_start_tutorial(rabbits)
	_tutorial._stage = TutorialController.Stage.PARRY_DODGE

	rabbit._start_melee_swing()
	_tutorial._process(0.016)
	_tutorial._process(TutorialController.PARRY_WINDOW_SEC + 0.1)  ## 판정 창 종료

	_player.dash_started.emit()
	_tutorial._process(0.016)
	assert_eq(
		_tutorial._stage, TutorialController.Stage.PARRY_DODGE, "판정 창을 넘긴 뒤의 회피는 3단계를 완료시키지 않는다"
	)


# --- 4단계: 스킬 ---


func test_skill_stage_completes_when_slot1_used_after_2_hits() -> void:
	var rabbit := _spawn_rabbit()
	var rabbits: Array[RabbitMonster] = [rabbit]
	_start_tutorial(rabbits)
	_tutorial._stage = TutorialController.Stage.SKILL

	_tutorial._on_attack_hit(_player.combo_data.steps[0], rabbit)
	_tutorial._on_attack_hit(_player.combo_data.steps[0], rabbit)
	_tutorial._process(0.016)

	_player.skill_used.emit(_player.skill_slot_1.skill_name)
	_tutorial._process(0.016)
	assert_eq(_tutorial._stage, TutorialController.Stage.AWAIT_FIRST_KILL)


# --- 5·6단계: 첫 처치 / 루팅 ---


func test_first_kill_flashes_toast_and_advances_to_loot() -> void:
	var rabbit := _spawn_rabbit()
	var rabbits: Array[RabbitMonster] = [rabbit]
	_start_tutorial(rabbits)

	rabbit.take_damage(9999.0)  ## died 시그널 발생 -> _on_rabbit_died

	assert_eq(_tutorial._stage, TutorialController.Stage.LOOT)
	assert_true(_hint_bar.is_flashing())


func test_loot_stage_completes_and_sets_tutorial_done() -> void:
	var rabbit := _spawn_rabbit()
	var rabbits: Array[RabbitMonster] = [rabbit]
	_start_tutorial(rabbits)
	rabbit.take_damage(9999.0)

	_drop_system.item_dropped.emit(ItemData.new(), 1, Vector2.ZERO)
	_tutorial._process(0.016)

	_inventory.item_added.emit(ItemData.new(), 1)
	_tutorial._process(0.016)

	assert_true(_tutorial.tutorial_done)


# --- 지연 노출: 응급 처치 ---


func test_heal_hint_triggers_once_when_hp_drops_below_50_percent() -> void:
	_start_tutorial()
	_player_stats.take_damage(_player_stats.stats.max_hp * 0.6)

	assert_true(_tutorial.hint_heal_done)
	_tutorial._process(0.016)
	_hint_bar._process(0.3)
	assert_eq(_hint_bar.get_node("Panel/Label").text, TutorialController.HEAL_TEXT)
