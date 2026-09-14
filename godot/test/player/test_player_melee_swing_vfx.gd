## 근접 기본 공격이 판정 순간에 실제 검 궤적을 표시하는지 검증한다.
extends GutTest

var _player: PlayerController


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)


func test_player_scene_has_melee_swing_vfx() -> void:
	assert_not_null(
		_player.get_node_or_null("MeleeSwingVfx"),
		"근접 공격의 휘두름을 보여 주는 전용 VFX가 플레이어 씬에 있어야 함"
	)


func test_melee_swing_vfx_is_hidden_while_idle() -> void:
	var vfx: Node2D = _player.get_node("MeleeSwingVfx")
	assert_false(vfx.visible, "검 궤적은 공격하지 않을 때 보이지 않아야 함")


func test_melee_active_phase_shows_swing_vfx() -> void:
	var vfx: Node2D = _player.get_node("MeleeSwingVfx")
	_player._start_attack_step(0)
	_player.attack_state = PlayerController.AttackState.ACTIVE
	_player._attack_phase_timer = _player.combo_data.steps[0].active_sec * 0.5
	vfx._process(0.0)
	assert_true(vfx.visible, "근접 판정이 열리는 순간에는 검 궤적이 보여야 함")
