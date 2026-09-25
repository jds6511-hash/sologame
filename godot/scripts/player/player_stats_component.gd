## 플레이어 HP/MP 및 회복 규칙 컴포넌트 (M2 Phase3 — growth.md 1~3장, combat.md 5-4장).
##
## growth.md 기준 Lv1 전사 스탯(CombatantStats — 정식화됨, max_mp 포함)을 실제 HP/MP
## 실체로 다룬다. Player 씬의 자식 노드("PlayerStats")로 배치하며 부모(PlayerController)를
## 그대로 참조한다(PlayerAttackResolver와 동일한 배치 패턴).
##
## 책임 분리: 데미지 "계산"(방어 감산·치명타 등, combat.md 6장)은 DamageCalculator(CB-3)
## 몫이고, 몬스터 피격 판정 "성립"은 MonsterAttackResolver(CB-4) 몫이다. 이 컴포넌트는
## MonsterBase.take_damage()와 동일하게 "최종 데미지 값을 그대로 HP에서 빼는" 결과 처리만
## 담당한다.
##
## 사망 처리(M3 D3-2, 디렉터 확정 "시작 지점 부활 + 경미 패널티")는 이 컴포넌트가 HP만
## 책임진다: `_die()`는 HP를 0으로 두고 `died`만 알린다 — 즉 **사망 상태가 실제로 유지된다**
## (종전의 "그 자리에서 즉시 전액 부활"을 대체). 사망 모션 대기·암전·골드 패널티·부활 호출
## 순서는 PlayerDeathSequence(scripts/player/player_death_sequence.gd)가 진행하며, 그쪽이
## 암전 구간에서 respawn()을 호출한다. combat.md 5-4장이 미뤄 둔 "사망 페널티" 규격의 실수치는
## PlayerDeathRules(.tres)에 있다.
class_name PlayerStatsComponent
extends Node

signal hp_changed(current_hp: float, max_hp: float)
signal mp_changed(current_mp: float, max_mp: float)
signal died
signal respawned
signal potion_used(healed_amount: float)
signal potion_use_failed  ## 쿨다운 중이거나 보스전 캡 초과 — UI 안내용

## 포션 사용 SFX (SD-1).
const POTION_USE_SFX := preload("res://assets/audio/sfx/sfx_combat_potion_use.wav")

@export var stats: CombatantStats  ## growth.md 1~3장 Lv1 전사 스탯(HP/MP/공격력/방어력/민첩)
@export var recovery_rules: PlayerRecoveryRules  ## combat.md 5-4장 회복 규칙

## 보스전 여부. M2에는 보스가 없어 실제 트리거가 없다(구조만 구현) — 보스 콘텐츠가 생기면
## start_boss_encounter()/end_boss_encounter()를 보스 조우 시작/종료 지점에서 호출하면 된다.
var is_boss_encounter: bool = false

var current_hp: float = 0.0
var current_mp: float = 0.0

var _potion_cooldown_timer: float = 0.0
var _boss_potion_used_count: int = 0
var _time_since_combat_action_sec: float = 0.0
var _defense_buff_percent: float = 0.0
var _defense_buff_timer: float = 0.0
var _respawn_position := Vector2.ZERO

@onready var _player: Node2D = get_parent()


func _ready() -> void:
	current_hp = stats.max_hp
	current_mp = stats.max_mp
	_respawn_position = _player.global_position
	if _player.has_signal("player_hit_taken"):
		_player.player_hit_taken.connect(_on_combat_action.unbind(1))
	if _player.has_signal("attack_hit"):
		_player.attack_hit.connect(_on_combat_action.unbind(2))


func _process(delta: float) -> void:
	_update_potion_cooldown(delta)
	_update_defense_buff(delta)
	_update_natural_regen(delta)


# --- 피해 적용 (MonsterAttackResolver 연동 지점) ---


## MonsterAttackResolver가 몬스터 공격 판정 성립 시 호출한다. amount는 DamageCalculator가
## 계산한 최종 데미지다(방어 감산 등은 호출자가 이미 반영했다).
func take_damage(amount: float, _hit_grade: String = "약", _attacker: Node2D = null) -> void:
	if is_dead():
		return
	_on_combat_action()
	current_hp = max(current_hp - amount, 0.0)
	hp_changed.emit(current_hp, stats.max_hp)
	if current_hp <= 0.0:
		_die()


## PlayerAttackResolver 등 공격자 쪽 duck-typing 계약(get_combat_defense) — 방어 버프
## 반영치를 돌려준다.
func get_combat_defense() -> float:
	return stats.defense * (1.0 + _defense_buff_percent)


func is_dead() -> bool:
	return current_hp <= 0.0


func heal(amount: float) -> void:
	if is_dead() or amount <= 0.0:
		return
	current_hp = min(current_hp + amount, stats.max_hp)
	hp_changed.emit(current_hp, stats.max_hp)


func has_mp(amount: float) -> bool:
	return current_mp >= amount


func spend_mp(amount: float) -> void:
	current_mp = max(current_mp - amount, 0.0)
	mp_changed.emit(current_mp, stats.max_mp)


## 레벨업으로 최대 HP/MP가 늘었을 때 PlayerStatGrowth(M3 B-2)가 호출한다. 늘어난 최대치만큼
## 현재값을 가산해 "레벨업 = 약간 회복" 체감을 준다(m3-leveling-spec.md 3-2 규약, 전체 회복
## 아님). stats(공유 CombatantStats)의 max_hp/max_mp는 호출 전에 이미 새 값으로 갱신돼 있어야
## 한다(PlayerStatGrowth가 재계산 후 이 함수를 부른다).
func grow_max_stats(hp_increase: float, mp_increase: float) -> void:
	if hp_increase > 0.0:
		current_hp += hp_increase
		hp_changed.emit(current_hp, stats.max_hp)
	if mp_increase > 0.0:
		current_mp += mp_increase
		mp_changed.emit(current_mp, stats.max_mp)


## 결의의 외침(m2-warrior-skills.md 5-3장) 등 방어력 버프 적용.
func apply_defense_buff(percent: float, duration_sec: float) -> void:
	_defense_buff_percent = percent
	_defense_buff_timer = duration_sec


# --- 사망·부활 (M3 D3-2 — 진행은 PlayerDeathSequence) ---


## HP가 0이 된 순간의 처리. 여기서는 사망 상태를 "유지"하는 것이 전부다 — 사망 모션이
## 재생될 시간(is_dead() == true인 관측 가능한 구간)을 만드는 것이 이 변경의 핵심이다.
func _die() -> void:
	current_hp = 0.0
	died.emit()


## 부활 — PlayerDeathSequence가 암전 구간에서 호출한다. HP/MP를 최대치의 지정 비율로 되살리고
## 리스폰 지점으로 옮긴다. hp_percent가 0에 가깝게 설정돼도 HP 1은 남겨(재사망 루프 방지),
## 부활 직후 다시 is_dead()가 되는 상태로는 절대 돌아가지 않는다.
## 전투 이탈 타이머도 초기화해 부활 직후 자연 회복이 5초 뒤부터 시작되게 한다.
func respawn(hp_percent: float, mp_percent: float) -> void:
	current_hp = maxf(stats.max_hp * clampf(hp_percent, 0.0, 1.0), 1.0)
	current_mp = stats.max_mp * clampf(mp_percent, 0.0, 1.0)
	_player.global_position = _respawn_position
	_time_since_combat_action_sec = 0.0
	hp_changed.emit(current_hp, stats.max_hp)
	mp_changed.emit(current_mp, stats.max_mp)
	respawned.emit()


## 리스폰 지점 갱신 — 기본값은 씬에 배치된 플레이어의 초기 위치(시작 지역 씬에서는
## Markers/PlayerStart와 같은 좌표)이며, 그래서 씬 쪽 배선이 따로 필요하지 않다.
##
## 도시·부락·모닥불 같은 거점이 생기면 그 오브젝트가 이 함수를 호출하는 것만으로 "최근 거점
## 부활"로 확장된다(combat.md 5-4장 "거점 휴식"과 같은 자리). 지역(씬) 간 이동을 넘나드는
## 부활은 씬 전환 자체가 아직 없어 범위 밖이다.
func set_respawn_position(world_position: Vector2) -> void:
	_respawn_position = world_position


func get_respawn_position() -> Vector2:
	return _respawn_position


# --- 포션 (CB-5, combat.md 5-4장 — 구조만: 쿨다운·회복량·보스전 캡) ---


## 포션 사용 시도. 성공하면 true를 돌려준다. 인벤토리 수량 차감은 IT-3(systems-dev)의
## 아이템 시스템 몫이며, 이 함수는 "포션 1개를 지금 쓸 수 있는가"(쿨다운·보스전 캡)만
## 판정한다 — 호출자가 실제 아이템 보유 여부를 먼저 확인해야 한다.
##
## heal_override: 아이템 데이터의 고정 회복량(ItemData.heal_amount, economy-foundation.md
## 5-1장). 양수면 그 절댓값으로 회복하고, 미지정(0 이하)이면 종전대로
## PlayerRecoveryRules.potion_heal_percent(최대 HP 30%)로 회복한다 — 회복량 데이터가 없는
## 호출부(디버그 단축키 등)는 인자 없이 그대로 호출하면 된다.
func use_potion(heal_override: float = -1.0) -> bool:
	if is_dead():
		return false
	if _potion_cooldown_timer > 0.0:
		potion_use_failed.emit()
		return false
	if is_boss_encounter and _boss_potion_used_count >= recovery_rules.potion_boss_cap:
		potion_use_failed.emit()
		return false

	var heal_amount := (
		heal_override if heal_override > 0.0 else stats.max_hp * recovery_rules.potion_heal_percent
	)
	heal(heal_amount)
	_potion_cooldown_timer = recovery_rules.potion_cooldown_sec
	if is_boss_encounter:
		_boss_potion_used_count += 1
	potion_used.emit(heal_amount)
	HitFeedback.play_sfx(POTION_USE_SFX, _player.global_position)
	return true


## 보스 조우 시작/종료 지점에서 호출(보스 콘텐츠 도입 후 wiring 예정) — 캡 카운터 초기화.
func start_boss_encounter() -> void:
	is_boss_encounter = true
	_boss_potion_used_count = 0


func end_boss_encounter() -> void:
	is_boss_encounter = false
	_boss_potion_used_count = 0


## 상태의 소유자가 저장 제외 판정을 제공한다. 호출자는 대기 시간 정책만 전달한다.
func save_block_reason(quiet_seconds: float) -> String:
	if is_dead():
		return "death_sequence"
	if is_boss_encounter:
		return "boss_encounter"
	if _time_since_combat_action_sec < quiet_seconds:
		return "recent_combat"
	if _potion_cooldown_timer > 0.0 or _defense_buff_timer > 0.0:
		return "cooldown_or_buff"
	return ""


func get_potion_cooldown_remaining_sec() -> float:
	return _potion_cooldown_timer


func _update_potion_cooldown(delta: float) -> void:
	if _potion_cooldown_timer > 0.0:
		_potion_cooldown_timer = max(_potion_cooldown_timer - delta, 0.0)


func _update_defense_buff(delta: float) -> void:
	if _defense_buff_timer <= 0.0:
		return
	_defense_buff_timer = max(_defense_buff_timer - delta, 0.0)
	if _defense_buff_timer <= 0.0:
		_defense_buff_percent = 0.0


# --- 자연 회복 (combat.md 5-4장: 전투 이탈 5초 후 초당 2%) ---
# "전투 이탈"의 판정 기준은 문서에 조작적 정의가 없어(디자인 공백), 가장 직접적으로 관측
# 가능한 신호인 "최근 피격/공격 이후 경과 시간"으로 정의했다 — 다른 정의가 필요하면 추후
# systems-designer 확인 후 조정.


func _update_natural_regen(delta: float) -> void:
	var time_before_sec := _time_since_combat_action_sec
	_time_since_combat_action_sec += delta
	if is_dead() or current_hp >= stats.max_hp:
		return
	if _time_since_combat_action_sec < recovery_rules.natural_regen_delay_sec:
		return
	## 이번 delta 구간 중 지연 시간을 "넘어선" 부분만 회복에 반영한다(경계를 정확히
	## 넘는 순간의 delta 전부를 회복으로 치는 것을 방지 — delta가 큰 호출에서도 정확).
	var overlap_sec: float = (
		_time_since_combat_action_sec
		- maxf(time_before_sec, recovery_rules.natural_regen_delay_sec)
	)
	if overlap_sec <= 0.0:
		return
	var regen := stats.max_hp * recovery_rules.natural_regen_percent_per_sec * overlap_sec
	current_hp = min(current_hp + regen, stats.max_hp)
	hp_changed.emit(current_hp, stats.max_hp)


func _on_combat_action() -> void:
	_time_since_combat_action_sec = 0.0
