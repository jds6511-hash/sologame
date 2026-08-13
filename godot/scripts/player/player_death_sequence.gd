## 사망 흐름 진행 노드 (M3 D3-2) — 사망 모션 → 암전 → 시작 지점 부활.
##
## 디렉터 확정 지시("시작 지점 부활 + 경미 패널티")의 구현체다. 종전 `_die()`는 그 자리에서
## 즉시 전액 부활시켜 **`is_dead()`가 true인 순간이 관측되지 않았고**, 그래서 정식 시트의
## `death_*` 12프레임이 재생될 자리도 없었다. 이제 `PlayerStatsComponent._die()`는 HP를 0으로
## 두고 `died`만 알리며, 실제 부활은 이 노드가 암전 구간에서 호출한다.
##
## 배치: Player 씬의 자식 노드("PlayerDeathSequence") — PlayerStats와 같은 패턴이며 부모
## (PlayerController)를 그대로 참조한다. 골드 패널티 대상인 InventoryComponent는 씬에 따라
## 있을 수도 없을 수도 있어(월드 씬이 Player에 "Inventory"를 붙인다) 사망 시점에 조회한다.
##
## 단계별 타이밍·부활 비율·골드 상실률은 전부 PlayerDeathRules(.tres) 데이터다 — 이 파일에
## 기획 수치를 하드코딩하지 않는다.
##
## 암전은 `scripts\ui\`·`scenes\ui\`를 건드리지 않고 이 노드가 코드로 만든 CanvasLayer +
## ColorRect로 처리한다(HUD layer 1 · 힌트바 5 · 통합 메뉴 10보다 위). `ux-foundation.md`
## 3장의 S15(사망/게임 오버 오버레이)는 화면 등재만 되어 있고 연출·리트라이 UI 규격이 없어,
## 정식 UX가 나올 때까지의 최소 연출이다.
class_name PlayerDeathSequence
extends Node

signal death_sequence_started
signal death_penalty_applied(gold_lost: int)  ## UI 안내용 — 실제로 잃은 골드
signal death_sequence_finished

## MOTION·FADE_OUT 동안 is_dead()가 true이고, BLACKOUT 진입 시점에 부활한다.
## FADE_IN은 이미 살아 있지만 화면이 아직 밝아지는 중이라 조작만 계속 막는 구간이다.
enum Phase { NONE, MOTION, FADE_OUT, BLACKOUT, FADE_IN }

## HUD(1)·온보딩 힌트바(5)·통합 메뉴(10)보다 위에 그려야 화면 전체가 덮인다.
const BLACKOUT_CANVAS_LAYER := 20

@export var rules: PlayerDeathRules

var phase: Phase = Phase.NONE

var _phase_timer: float = 0.0
var _blackout: ColorRect = null

@onready var _player: PlayerController = get_parent()
@onready var _stats: PlayerStatsComponent = _player.get_node_or_null("PlayerStats")


func _ready() -> void:
	_build_blackout()
	if _stats != null:
		_stats.died.connect(_on_player_died)


func _process(delta: float) -> void:
	if phase == Phase.NONE:
		return
	_phase_timer += delta
	match phase:
		Phase.MOTION:
			if _phase_timer >= rules.death_motion_sec:
				_enter_phase(Phase.FADE_OUT)
		Phase.FADE_OUT:
			_set_blackout_alpha(_progress(rules.fade_out_sec))
			if _phase_timer >= rules.fade_out_sec:
				_enter_phase(Phase.BLACKOUT)
		Phase.BLACKOUT:
			if _phase_timer >= rules.blackout_hold_sec:
				_enter_phase(Phase.FADE_IN)
		Phase.FADE_IN:
			_set_blackout_alpha(1.0 - _progress(rules.fade_in_sec))
			if _phase_timer >= rules.fade_in_sec:
				_enter_phase(Phase.NONE)


## 시퀀스 진행 중 여부 — 조작이 막혀 있는 구간과 정확히 일치한다.
func is_active() -> bool:
	return phase != Phase.NONE


# --- 단계 전이 ---


func _on_player_died() -> void:
	if phase != Phase.NONE:
		return
	_player.is_input_locked = true
	_apply_gold_penalty()
	_enter_phase(Phase.MOTION)
	death_sequence_started.emit()


func _enter_phase(next_phase: Phase) -> void:
	phase = next_phase
	_phase_timer = 0.0
	match next_phase:
		Phase.BLACKOUT:
			## 화면이 완전히 가려진 순간에 부활시킨다 — 순간이동이 보이지 않게 하는 것이
			## 암전의 목적이다. 이 시점부터 is_dead()가 false가 된다.
			_set_blackout_alpha(1.0)
			if _stats != null:
				_stats.respawn(rules.respawn_hp_percent, rules.respawn_mp_percent)
		Phase.NONE:
			_set_blackout_alpha(0.0)
			_player.is_input_locked = false
			death_sequence_finished.emit()


## 현재 단계의 진행률(0~1). duration이 0 이하로 설정돼도 0 나눗셈이 나지 않게 막는다.
func _progress(duration_sec: float) -> float:
	if duration_sec <= 0.0:
		return 1.0
	return clampf(_phase_timer / duration_sec, 0.0, 1.0)


# --- 골드 패널티 (economy-foundation.md 1-1·6장, 규격은 PlayerDeathRules 주석) ---


func _apply_gold_penalty() -> void:
	var inventory := _player.get_node_or_null("Inventory") as InventoryComponent
	if inventory == null:
		return
	death_penalty_applied.emit(inventory.lose_gold(gold_loss_for(inventory.gold)))


## 소지 골드 carried_gold에서 잃을 액수. 비율(gold_loss_percent) 상실이며 "동렙 몹 N마리분"
## 상한을 넘지 않는다. 내림이므로 소액 보유 시 0이 될 수 있다(하한 없음 — 규칙 주석 참고).
func gold_loss_for(carried_gold: int) -> int:
	if carried_gold <= 0:
		return 0
	var loss := int(floor(float(carried_gold) * rules.gold_loss_percent))
	return mini(loss, gold_loss_cap())


## 상실 상한(골드) = gold_loss_cap_kill_units × g(플레이어 레벨).
## g(L)은 DropSystem.calc_gold(일반 등급)를 그대로 재사용한다 — 골드 공식 구현을 두 벌
## 만들지 않기 위해서다(일반 등급은 rate_config를 참조하지 않으므로 null을 넘겨도 안전).
func gold_loss_cap() -> int:
	var progression := _player.get_node_or_null("PlayerProgression") as PlayerProgression
	var level := 1
	if progression != null:
		level = progression.current_level
	var kill_unit := DropSystem.calc_gold(level, DropTableData.MonsterTier.NORMAL, null)
	return maxi(roundi(rules.gold_loss_cap_kill_units * kill_unit), 0)


# --- 암전 연출 (코드로 만드는 CanvasLayer — UI 담당 파일을 건드리지 않는다) ---


func _build_blackout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = BLACKOUT_CANVAS_LAYER
	add_child(layer)
	_blackout = ColorRect.new()
	_blackout.color = Color(0.0, 0.0, 0.0, 0.0)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_blackout)
	_blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _set_blackout_alpha(alpha: float) -> void:
	if _blackout == null:
		return
	_blackout.color = Color(0.0, 0.0, 0.0, clampf(alpha, 0.0, 1.0))


## 현재 암전 정도(0~1) — 테스트·QA 확인용.
func get_blackout_alpha() -> float:
	return _blackout.color.a if _blackout != null else 0.0
