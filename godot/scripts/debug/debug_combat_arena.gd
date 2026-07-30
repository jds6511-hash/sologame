## CB-9 디버그 전투장 — alpha-tester가 손맛 반복 검증에 쓰는 전용 씬(combat.md 9-1장).
##
## 기능: 몬스터 3종 소환(F1~F3)·스탯 조작(F6~F9)·즉시 리셋(F5)·프레임 카운터.
## 조작이 실제 게임플레이 입력(1~4/Q/E/R/좌우클릭/Space 등, project.godot [input])과
## 겹치지 않도록 디버그 전용 키는 전부 함수키(F1~F9)를 raw keycode로 처리한다
## (godot/scripts/vfx_common/hit_feedback_demo.gd의 raw keycode 데모 패턴과 동일).
##
## 데미지 배선(2026-07-26 수정): 근접 2종(뿔토끼·들개 마수) 씬에는 MonsterAttackResolver가,
## 균열 점액은 원거리 투사체·산성 웅덩이에 실피해 경로가 각 씬/스크립트에 직접 baked되어 있다.
## 따라서 이 디버그 씬은 더 이상 스폰 시 리졸버를 동적으로 붙이지 않는다(그 임시 배선은 실제
## 게임 스포너 monster_spawner.gd에는 없어 디렉터 플레이에서 "몬스터가 데미지를 주지 못하는"
## 차단 버그의 원인이 되었다 — 배선을 씬으로 옮겨 게임 전역에서 일관되게 작동하게 했다).
class_name DebugCombatArena
extends Node2D

const WOLF_SCENE: PackedScene = preload("res://scenes/monsters/wolf.tscn")
const RABBIT_SCENE: PackedScene = preload("res://scenes/monsters/rabbit.tscn")
const RIFT_SLIME_SCENE: PackedScene = preload("res://scenes/monsters/rift_slime.tscn")

const ATTACK_POWER_STEP := 10.0
const MAX_HP_STEP := 50.0
const SPAWN_DISTANCE_PX := 48.0
const TIME_JUMP_HOURS := 1.0  ## G2-4 디버그 시간 점프 — 밤을 기다리지 않고 즉시 확인용

@export var player_path: NodePath
@export var monsters_root_path: NodePath
@export var status_label_path: NodePath

var _player_spawn_position := Vector2.ZERO
var _frame_count: int = 0
var _spawn_sequence: int = 0

@onready var _player: PlayerController = get_node(player_path)
@onready var _monsters_root: Node2D = get_node(monsters_root_path)
@onready var _status_label: Label = get_node(status_label_path)
@onready var _player_stats: PlayerStatsComponent = _player.get_node("PlayerStats")
@onready var _attacker_stats: CombatantStats = _player.get_node("AttackResolver").attacker_stats
@onready var _hud: Hud = $Hud


func _ready() -> void:
	_player_spawn_position = _player.global_position
	_hud.bind_player(_player, _player_stats)
	## 디버그 전투장은 지역색이 필요 없어 일반 전투 곡을 그대로 쓴다
	## (bgm-lyria-prompts.md 1-1 판단 사항 2 — 전용 트랙 미생성).
	BgmManager.play_for_scene(scene_file_path)


func _process(_delta: float) -> void:
	_frame_count += 1
	_update_status_label()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_F1:
			_spawn_monster(RABBIT_SCENE, "뿔토끼")
		KEY_F2:
			_spawn_monster(WOLF_SCENE, "들개 마수")
		KEY_F3:
			_spawn_monster(RIFT_SLIME_SCENE, "균열 점액")
		KEY_F4:
			_clear_monsters()
		KEY_F5:
			_reset_arena()
		KEY_F6:
			_adjust_attack_power(ATTACK_POWER_STEP)
		KEY_F7:
			_adjust_attack_power(-ATTACK_POWER_STEP)
		KEY_F8:
			_adjust_max_hp(MAX_HP_STEP)
		KEY_F9:
			_adjust_max_hp(-MAX_HP_STEP)
		KEY_F10:
			_debug_jump_time()


# --- 몬스터 소환 (F1~F3) ---


func _spawn_monster(scene: PackedScene, display_name: String) -> void:
	_spawn_sequence += 1
	var monster: Node2D = scene.instantiate()
	monster.name = "DebugMonster_%d" % _spawn_sequence
	var angle := randf() * TAU
	monster.global_position = _player.global_position + Vector2(SPAWN_DISTANCE_PX, 0).rotated(angle)
	_monsters_root.add_child(monster)
	monster.target = _player

	_update_status_label("%s 소환" % display_name)


func _clear_monsters() -> void:
	for child in _monsters_root.get_children():
		child.queue_free()
	_update_status_label("몬스터 전체 제거")


# --- 즉시 리셋 (F5) ---


func _reset_arena() -> void:
	_clear_monsters()
	_player.global_position = _player_spawn_position
	_player.velocity = Vector2.ZERO
	_player.is_hit_stunned = false
	_player.is_dashing = false
	_player.is_dash_invincible = false
	_player.dash_charges = _player.movement_data.dash_charge_max
	_player_stats.current_hp = _player_stats.stats.max_hp
	_player_stats.current_mp = _player_stats.stats.max_mp
	_player_stats.hp_changed.emit(_player_stats.current_hp, _player_stats.stats.max_hp)
	_player_stats.mp_changed.emit(_player_stats.current_mp, _player_stats.stats.max_mp)
	_update_status_label("즉시 리셋")


# --- 스탯 조작 (F6~F9) ---
# AttackResolver.attacker_stats와 PlayerStats.stats는 player.tscn에서 동일한
# CombatantStats 리소스 인스턴스를 가리킨다 — 하나만 바꾸면 공격력/HP 계산 전부에
# 즉시 반영된다(단일 소스 원칙 유지, 별도 동기화 코드 불필요).


func _adjust_attack_power(delta: float) -> void:
	_attacker_stats.attack_power = maxf(_attacker_stats.attack_power + delta, 1.0)
	_update_status_label("공격력 %.0f" % _attacker_stats.attack_power)


func _adjust_max_hp(delta: float) -> void:
	_player_stats.stats.max_hp = maxf(_player_stats.stats.max_hp + delta, 10.0)
	_player_stats.current_hp = minf(_player_stats.current_hp, _player_stats.stats.max_hp)
	_player_stats.hp_changed.emit(_player_stats.current_hp, _player_stats.stats.max_hp)
	_update_status_label("최대 HP %.0f" % _player_stats.stats.max_hp)


# --- 시간 점프 (F10, G2-4) ---


func _debug_jump_time() -> void:
	GameClock.debug_jump_hours(TIME_JUMP_HOURS)
	var phase := "낮" if GameClock.is_day else "밤"
	_update_status_label(
		(
			"시간 %.0f시간 점프 → %d일차 %02d:%02d (%s)"
			% [
				TIME_JUMP_HOURS,
				GameClock.day_number,
				GameClock.get_hour(),
				GameClock.get_minute(),
				phase
			]
		)
	)


# --- 상태 표시 ---


func _update_status_label(last_action: String = "") -> void:
	_status_label.text = (
		"[CB-9 디버그 전투장] F1=뿔토끼 F2=들개 마수 F3=균열 점액 소환 · F4=몬스터 정리 · F5=리셋\n"
		+ (
			"F6/F7=공격력 +-%d · F8/F9=최대HP +-%d · F10=시간 %.0f시간 점프\n"
			% [ATTACK_POWER_STEP, MAX_HP_STEP, TIME_JUMP_HOURS]
		)
		+ (
			"프레임: %d · FPS: %d · 몬스터 수: %d\n"
			% [_frame_count, Engine.get_frames_per_second(), _monsters_root.get_child_count()]
		)
		+ (
			"공격력 %.0f · 최대 HP %.0f · HP %.0f/%.0f · MP %.0f/%.0f\n"
			% [
				_attacker_stats.attack_power,
				_player_stats.stats.max_hp,
				_player_stats.current_hp,
				_player_stats.stats.max_hp,
				_player_stats.current_mp,
				_player_stats.stats.max_mp,
			]
		)
		+ (
			"상태: %s%s"
			% [_player.get_debug_state_text(), (" — " + last_action) if last_action else ""]
		)
	)
