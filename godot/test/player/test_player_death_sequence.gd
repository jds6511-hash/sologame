## M3 D3-2 검증 — PlayerDeathSequence의 단계 진행(사망 모션 → 암전 → 시작 지점 부활)과
## 골드 패널티 산식이 PlayerDeathRules(.tres) 수치대로 동작하는지 확인한다.
##
## 디렉터 확정 지시는 "시작 지점 부활 + 경미 패널티"이며, 이 파일이 검증하는 핵심 계약은
## **부활이 화면이 완전히 가려진 BLACKOUT 진입 시점에 일어난다**는 것이다 — 그보다 이르면
## 순간이동이 보이고, 그보다 늦으면 밝아진 화면에 시체가 남는다.
##
## 시간 진행은 `_process(delta)`를 직접 호출해 결정적으로 만든다(test_elite_groggy_gauge.gd와
## 같은 방식). 한 번의 `_process` 호출에서는 단계 전이가 한 번만 일어나므로 단계마다 따로
## 호출한다.
extends GutTest

var _player: PlayerController
var _stats: PlayerStatsComponent
var _sequence: PlayerDeathSequence


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	_stats = _player.get_node("PlayerStats")
	_sequence = _player.get_node("PlayerDeathSequence")


## 사망 모션 구간이 끝날 만큼 시간을 흘려 FADE_OUT까지 보낸다(단계별 1회 호출).
func _advance_to_fade_out() -> void:
	_sequence._process(_sequence.rules.death_motion_sec + 0.01)


func _advance_to_blackout() -> void:
	_advance_to_fade_out()
	_sequence._process(_sequence.rules.fade_out_sec + 0.01)


func test_death_starts_sequence_and_locks_input_while_still_dead() -> void:
	watch_signals(_sequence)

	_stats.take_damage(9999.0)

	assert_eq(_sequence.phase, PlayerDeathSequence.Phase.MOTION)
	assert_true(_sequence.is_active())
	assert_true(_player.is_input_locked, "사망 연출 중에는 조작이 막혀야 한다")
	assert_true(_stats.is_dead(), "모션 구간은 사망 상태가 유지되어야 사망 모션이 재생된다")
	assert_signal_emitted(_sequence, "death_sequence_started")


func test_blackout_is_transparent_during_motion() -> void:
	_stats.take_damage(9999.0)

	assert_eq(_sequence.get_blackout_alpha(), 0.0, "모션 구간에는 아직 화면이 가려지지 않는다")


func test_fade_out_darkens_screen_while_still_dead() -> void:
	_stats.take_damage(9999.0)

	_advance_to_fade_out()

	assert_eq(_sequence.phase, PlayerDeathSequence.Phase.FADE_OUT)
	assert_true(_stats.is_dead(), "페이드 아웃 중에도 아직 부활하지 않는다")


func test_respawn_happens_exactly_at_blackout_with_screen_fully_covered() -> void:
	_stats.set_respawn_position(Vector2(320, 192))
	_player.global_position = Vector2(900, 900)
	_stats.take_damage(9999.0)

	_advance_to_blackout()

	assert_eq(_sequence.phase, PlayerDeathSequence.Phase.BLACKOUT)
	assert_eq(_sequence.get_blackout_alpha(), 1.0, "부활 순간 화면이 완전히 가려져 있어야 한다")
	assert_false(_stats.is_dead())
	assert_eq(_player.global_position, Vector2(320, 192))
	assert_eq(_stats.current_hp, _stats.stats.max_hp * _sequence.rules.respawn_hp_percent)
	assert_eq(_stats.current_mp, _stats.stats.max_mp * _sequence.rules.respawn_mp_percent)


## FADE_IN은 이미 살아 있지만 화면이 밝아지는 중이라 조작만 계속 막는 구간이다.
func test_fade_in_keeps_input_locked_while_already_alive() -> void:
	_stats.take_damage(9999.0)
	_advance_to_blackout()

	_sequence._process(_sequence.rules.blackout_hold_sec + 0.01)

	assert_eq(_sequence.phase, PlayerDeathSequence.Phase.FADE_IN)
	assert_false(_stats.is_dead())
	assert_true(_player.is_input_locked)


func test_sequence_end_unlocks_input_and_clears_blackout() -> void:
	watch_signals(_sequence)
	_stats.take_damage(9999.0)
	_advance_to_blackout()
	_sequence._process(_sequence.rules.blackout_hold_sec + 0.01)

	_sequence._process(_sequence.rules.fade_in_sec + 0.01)

	assert_eq(_sequence.phase, PlayerDeathSequence.Phase.NONE)
	assert_false(_sequence.is_active())
	assert_false(_player.is_input_locked)
	assert_eq(_sequence.get_blackout_alpha(), 0.0)
	assert_signal_emitted(_sequence, "death_sequence_finished")


## 연출 중 추가 사망 통보가 와도 단계가 되감기지 않아야 한다(재진입 가드).
func test_second_death_during_sequence_is_ignored() -> void:
	_stats.take_damage(9999.0)
	_advance_to_fade_out()

	_stats._die()

	assert_eq(_sequence.phase, PlayerDeathSequence.Phase.FADE_OUT, "MOTION으로 되감기면 안 된다")


# --- 골드 패널티 산식 (수치는 PlayerDeathRules — 여기서는 비율·상한·내림만 본다) ---


func test_gold_loss_is_percentage_of_carried_gold() -> void:
	## 100골드 × 5% = 5. 상한은 "동렙 일반몹 30마리분"이라 소액에서는 걸리지 않는다.
	assert_eq(_sequence.gold_loss_for(100), 5)


func test_gold_loss_floors_and_can_be_zero_for_small_amounts() -> void:
	assert_eq(_sequence.gold_loss_for(19), 0, "19 × 5% = 0.95 → 내림 0 (하한 없음)")
	assert_eq(_sequence.gold_loss_for(0), 0)


func test_gold_loss_is_capped() -> void:
	var cap := _sequence.gold_loss_cap()
	assert_gt(cap, 0, "상한은 동렙 일반몹 처치 골드 × 배수이므로 양수다")
	assert_eq(_sequence.gold_loss_for(10_000_000), cap)


## 인벤토리가 없는 씬(player.tscn 단독)에서도 사망이 터지지 않아야 한다 — 월드 씬만
## Player에 "Inventory"를 붙이기 때문이다.
func test_death_without_inventory_does_not_error() -> void:
	assert_null(_player.get_node_or_null("Inventory"), "player.tscn 단독에는 인벤토리가 없다")

	_stats.take_damage(9999.0)

	assert_eq(_sequence.phase, PlayerDeathSequence.Phase.MOTION)
