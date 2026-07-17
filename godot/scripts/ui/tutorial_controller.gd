## 온보딩 튜토리얼 6단계 진행 관리자 (UI-4) — docs\art\ux\onboarding.md 3장 그대로 구현한다.
##
## 퀘스트 시스템(MQ-01·MQ-02)이 아직 구현되지 않아(quest-designer M2+ 예정), 문서가 트리거로
## 지정한 "MQ-01 자동 수령"·"MQ-02 수령 + 서식지 진입"은 대체 조건으로 근사했다 — 각 대체
## 지점에 주석을 남겼다(기획 확인 필요 항목은 결과 보고에도 정리).
##
## 진행 게이트는 없다(1장 원칙2) — 이 스크립트는 오직 "지금 어떤 힌트를 보여줄까"만 결정하고,
## 플레이어 행동 자체를 막지 않는다. player_controller.gd·monster_base.gd·rabbit_monster.gd 등
## 코어 전투/이동/AI 스크립트는 전혀 수정하지 않았다 — 전부 기존 공개 시그널·공개 필드(예:
## RabbitMonster.state)를 관찰(폴링)하는 것만으로 조건을 판정한다.
##
## tutorial_done 플래그는 M2 범위에서 세이브 시스템이 없어 이 노드의 세션 내 상태로만
## 존재한다(작업 지시 그대로) — 영구 저장이 필요해지면 세이브 시스템(systems-dev) 연동 시
## 이 값을 그대로 읽어 넣으면 된다.
class_name TutorialController
extends Node

signal tutorial_completed

enum Stage { MOVE, ATTACK, FLEE_DASH, PARRY_DODGE, SKILL, AWAIT_FIRST_KILL, LOOT }

const NEAR_RANGE_TILES := 3.0
const MOVE_COMPLETE_TILES := 3.0
const SKILL_TRIGGER_HIT_COUNT := 2
const PARRY_WINDOW_SEC := 0.6
const FIRST_KILL_HOLD_SEC := 2.0
const HEAL_HINT_DURATION_SEC := 8.0

const MOVE_TEXT := "⌨ W A S D 로 이동하세요"
const ATTACK_TEXT := "🖱 마우스 좌클릭으로 공격하세요"
const FLEE_DASH_TEXT := "⎵ Space 로 대시해 거리를 좁히세요"
const PARRY_TEXT := "⎵ 적이 공격을 예고하면 Space 로 피하세요"
const SKILL_TEXT := "① 1번 키로 스킬 [강타]를 사용해보세요"
const LOOT_TEXT := "F 키로 드랍 아이템을 주우세요"
const FIRST_KILL_TEXT := "첫 처치! 경험치 +5"
const HEAL_TEXT := "③ HP가 낮으면 3번 키로 [응급 처치]를 사용할 수 있습니다"

var tutorial_done: bool = false
var hint_heal_done: bool = false

var _player: PlayerController = null
var _player_stats: PlayerStatsComponent = null
var _inventory: InventoryComponent = null
var _drop_system: DropSystem = null
var _hud: Hud = null
var _hint_bar: OnboardingHintBar = null
var _rabbits: Array[RabbitMonster] = []

var _stage: Stage = Stage.MOVE
var _hint := OnboardingHintTiming.new()
var _current_stage_text := ""

var _move_initialized := false
var _move_hint_suppressed := false
var _last_position := Vector2.ZERO
var _moved_tiles := 0.0

var _base_attack_landed := false
var _hit_counts: Dictionary = {}  ## RabbitMonster -> int(기본 공격 유효 타격 수)

var _dash_ever_used := false
var _rabbit_fled_ever := false

var _rabbit_prev_state: Dictionary = {}  ## RabbitMonster -> RabbitMonster.State
var _rabbit_swing_ever := false
var _parry_window_timer := -1.0
var _parry_learned := false

var _skill1_ever_used := false
var _first_kill_happened := false
var _item_dropped_ever := false
var _item_added_ever := false

var _heal_hint_timer := -1.0


## eastern_frontier_starting_area.gd가 _ready()에서 한 번 호출한다(hud.bind_player와 동일한
## 통합 패턴). rabbits: MonsterSpawner 하위에 이미 스폰된 RabbitMonster 목록.
func start(
	player: PlayerController,
	player_stats: PlayerStatsComponent,
	inventory: InventoryComponent,
	drop_system: DropSystem,
	hud: Hud,
	hint_bar: OnboardingHintBar,
	rabbits: Array[RabbitMonster]
) -> void:
	_player = player
	_player_stats = player_stats
	_inventory = inventory
	_drop_system = drop_system
	_hud = hud
	_hint_bar = hint_bar
	_rabbits = rabbits

	_last_position = player.global_position
	_move_initialized = true
	_move_hint_suppressed = _any_move_input_active()

	player.attack_hit.connect(_on_attack_hit)
	player.skill_used.connect(_on_skill_used)
	player.dash_started.connect(_on_dash_started)
	player_stats.hp_changed.connect(_on_hp_changed)
	inventory.item_added.connect(_on_item_added)
	drop_system.item_dropped.connect(_on_item_dropped)
	for rabbit in rabbits:
		_rabbit_prev_state[rabbit] = rabbit.state
		rabbit.died.connect(_on_rabbit_died)


func _process(delta: float) -> void:
	if _player == null or tutorial_done:
		return

	_poll_move_distance()
	_poll_rabbit_states()
	_update_parry_window(delta)
	_hint.update(delta)

	match _stage:
		Stage.MOVE:
			if not _advance_or_show(
				_moved_tiles >= MOVE_COMPLETE_TILES, true, MOVE_TEXT, _move_hint_suppressed
			):
				_next_stage()
		Stage.ATTACK:
			_update_attack_world_prompt()
			if not _advance_or_show(_base_attack_landed, _attack_trigger_ready(), ATTACK_TEXT):
				_next_stage()
		Stage.FLEE_DASH:
			if not _advance_or_show(_dash_ever_used, _rabbit_fled_ever, FLEE_DASH_TEXT):
				_next_stage()
		Stage.PARRY_DODGE:
			if not _advance_or_show(_parry_learned, _rabbit_swing_ever, PARRY_TEXT):
				_next_stage()
		Stage.SKILL:
			if not _advance_or_show(_skill1_ever_used, _skill_trigger_ready(), SKILL_TEXT):
				_next_stage()
		Stage.AWAIT_FIRST_KILL:
			pass  ## _on_rabbit_died가 반응형으로 처리(첫 처치는 아무 시점에나 발생 가능)
		Stage.LOOT:
			if not _advance_or_show(_item_added_ever, _item_dropped_ever, LOOT_TEXT):
				_finish_tutorial()

	_update_heal_hint(delta)
	_sync_bar_visibility()


# --- 단계 공통 진행 헬퍼 ---


## completed면 이 단계를 잠재우고 false(다음 단계로 넘어가라)를 돌려준다. 아직이면 trigger_ready
## 일 때만 힌트 타이머를 시작하고 true(아직 이 단계)를 돌려준다. suppressed면 조건 충족 전까지
## 힌트를 아예 띄우지 않는다(원칙5 "숙련자 자동 생략" — 이동 단계처럼 트리거가 즉시라 완료
## 사실만으로는 생략을 표현할 수 없는 경우 전용).
func _advance_or_show(
	completed: bool, trigger_ready: bool, text: String, suppressed: bool = false
) -> bool:
	if completed:
		_hint.complete()
		return false
	if trigger_ready and not suppressed:
		_hint.begin()
	_current_stage_text = text
	return true


func _next_stage() -> void:
	_hint_bar.hide_hint()
	_hint = OnboardingHintTiming.new()
	match _stage:
		Stage.MOVE:
			_stage = Stage.ATTACK
		Stage.ATTACK:
			_hud.hide_interaction_prompt()
			_stage = Stage.FLEE_DASH
		Stage.FLEE_DASH:
			_stage = Stage.PARRY_DODGE
		Stage.PARRY_DODGE:
			_stage = Stage.SKILL
		Stage.SKILL:
			_stage = Stage.AWAIT_FIRST_KILL
		_:
			pass


func _finish_tutorial() -> void:
	tutorial_done = true
	_hint_bar.hide_hint()
	tutorial_completed.emit()


func _sync_bar_visibility() -> void:
	if _hint_bar.is_flashing():
		return
	if _heal_hint_timer >= 0.0:
		_hint_bar.show_hint(HEAL_TEXT)
		return
	if _hint.is_showing():
		_hint_bar.show_hint(_current_stage_text)
	else:
		_hint_bar.hide_hint()


# --- 1단계: 이동 ---


func _any_move_input_active() -> bool:
	return (
		Input.is_action_pressed("move_up")
		or Input.is_action_pressed("move_down")
		or Input.is_action_pressed("move_left")
		or Input.is_action_pressed("move_right")
	)


func _poll_move_distance() -> void:
	var current: Vector2 = _player.global_position
	var moved_px := current.distance_to(_last_position)
	if moved_px > 0.0:
		_moved_tiles += moved_px / _player.movement_data.tile_size_px
	_last_position = current


# --- 2단계: 기본 공격 ---


func _attack_trigger_ready() -> bool:
	return _nearest_rabbit_in_range() != null


func _nearest_rabbit_in_range() -> RabbitMonster:
	var nearest: RabbitMonster = null
	var nearest_dist := INF
	for rabbit in _rabbits:
		if not is_instance_valid(rabbit) or rabbit.is_dead():
			continue
		var dist := rabbit.distance_tiles_to(_player.global_position)
		if dist <= NEAR_RANGE_TILES and dist < nearest_dist:
			nearest = rabbit
			nearest_dist = dist
	return nearest


func _update_attack_world_prompt() -> void:
	if _base_attack_landed:
		_hud.hide_interaction_prompt()
		return
	var nearest := _nearest_rabbit_in_range()
	if nearest == null:
		_hud.hide_interaction_prompt()
		return
	_hud.show_interaction_prompt("공격", nearest.global_position, "좌클릭")


func _on_attack_hit(step, target: Node) -> void:
	if not (target is MonsterBase):
		return
	if not (step is WarriorAttackStep):
		return  ## 스킬 판정은 4단계(강타) 담당 — 여기서는 기본 콤보만 센다.
	_base_attack_landed = true
	_hit_counts[target] = int(_hit_counts.get(target, 0)) + 1


# --- 3단계: 회피 (추격 대시/반격 회피) ---


func _poll_rabbit_states() -> void:
	for rabbit in _rabbits:
		if not is_instance_valid(rabbit):
			continue
		var previous: int = _rabbit_prev_state.get(rabbit, RabbitMonster.State.WANDER)
		var current: int = rabbit.state
		if current == RabbitMonster.State.FLEE and previous != RabbitMonster.State.FLEE:
			_rabbit_fled_ever = true
		if (
			current == RabbitMonster.State.MELEE_SWING
			and previous != RabbitMonster.State.MELEE_SWING
		):
			_rabbit_swing_ever = true
			_parry_window_timer = PARRY_WINDOW_SEC
		_rabbit_prev_state[rabbit] = current


func _update_parry_window(delta: float) -> void:
	if _parry_window_timer < 0.0:
		return
	_parry_window_timer -= delta
	if _parry_window_timer < 0.0:
		_parry_window_timer = -1.0


func _on_dash_started() -> void:
	_dash_ever_used = true
	if _parry_window_timer >= 0.0:
		_parry_learned = true
		_parry_window_timer = -1.0


# --- 4단계: 스킬(강타) ---


func _skill_trigger_ready() -> bool:
	for rabbit in _hit_counts.keys():
		if (
			is_instance_valid(rabbit)
			and not rabbit.is_dead()
			and int(_hit_counts[rabbit]) >= SKILL_TRIGGER_HIT_COUNT
		):
			return true
	return false


func _on_skill_used(skill_name: String) -> void:
	if _player.skill_slot_1 != null and skill_name == _player.skill_slot_1.skill_name:
		_skill1_ever_used = true
	if _player.skill_slot_3 != null and skill_name == _player.skill_slot_3.skill_name:
		_heal_hint_timer = -1.0  ## 응급 처치를 이미 썼으니 지연 힌트를 즉시 접는다.


# --- 5단계: 첫 처치 / 6단계: 루팅 ---


func _on_rabbit_died() -> void:
	if _first_kill_happened:
		return
	_first_kill_happened = true
	_hud.hide_interaction_prompt()
	_stage = Stage.LOOT
	_hint = OnboardingHintTiming.new()
	_hint_bar.flash_message(FIRST_KILL_TEXT, FIRST_KILL_HOLD_SEC)


func _on_item_dropped(_item: ItemData, _quantity: int, _world_position: Vector2) -> void:
	_item_dropped_ever = true


func _on_item_added(_item: ItemData, _quantity: int) -> void:
	_item_added_ever = true


# --- 지연 노출: 응급 처치 (4장, HP 50% 이하 최초 1회) ---
# 질주(4장) 힌트는 "15타일 이상 REACH 퀘스트 목표 수령"이 트리거인데 퀘스트 시스템이 아직
# 없어 구현할 수 없다 — quest-designer/systems-dev의 퀘스트 저널 구현 이후 연동 필요
# (onboarding.md 4장 각주와 동일한 공백, 결과 보고에도 명시).


func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	if hint_heal_done or max_hp <= 0.0:
		return
	if current_hp / max_hp > 0.5:
		return
	hint_heal_done = true
	_heal_hint_timer = HEAL_HINT_DURATION_SEC


func _update_heal_hint(delta: float) -> void:
	if _heal_hint_timer < 0.0:
		return
	_heal_hint_timer -= delta
	if _heal_hint_timer < 0.0:
		_heal_hint_timer = -1.0
