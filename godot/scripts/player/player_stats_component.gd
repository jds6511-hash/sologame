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
## 사망 처리는 "임시: 리스폰"이다 — combat.md 5-4장이 "사망 페널티(부활 위치·비용)는
## 세이브/로드·경제와 얽히므로 추후 별도 규정한다"고 명시적으로 미룬 항목이라, 여기서는
## 최소 동작(즉시 전체 회복 + 최초 스폰 위치로 복귀)만 구현한다.
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


## 결의의 외침(m2-warrior-skills.md 5-3장) 등 방어력 버프 적용.
func apply_defense_buff(percent: float, duration_sec: float) -> void:
	_defense_buff_percent = percent
	_defense_buff_timer = duration_sec


# --- 사망 처리 (임시: 즉시 리스폰) ---


func _die() -> void:
	died.emit()
	current_hp = stats.max_hp
	current_mp = stats.max_mp
	_player.global_position = _respawn_position
	hp_changed.emit(current_hp, stats.max_hp)
	mp_changed.emit(current_mp, stats.max_mp)
	respawned.emit()


# --- 포션 (CB-5, combat.md 5-4장 — 구조만: 쿨다운·회복량·보스전 캡) ---


## 포션 사용 시도. 성공하면 true를 돌려준다. 인벤토리 수량 차감은 IT-3(systems-dev)의
## 아이템 시스템 몫이며, 이 함수는 "포션 1개를 지금 쓸 수 있는가"(쿨다운·보스전 캡)만
## 판정한다 — 호출자가 실제 아이템 보유 여부를 먼저 확인해야 한다.
func use_potion() -> bool:
	if is_dead():
		return false
	if _potion_cooldown_timer > 0.0:
		potion_use_failed.emit()
		return false
	if is_boss_encounter and _boss_potion_used_count >= recovery_rules.potion_boss_cap:
		potion_use_failed.emit()
		return false

	var heal_amount := stats.max_hp * recovery_rules.potion_heal_percent
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
