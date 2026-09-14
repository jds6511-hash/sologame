## CB-4 검증 — 플레이어 피격 경직 0.25초 · 무적 0.6초(combat.md 5-1장 "일반 피격") 재현.
extends GutTest

var _player: PlayerController


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)


func test_take_hit_starts_stun_and_invincibility() -> void:
	_player.take_hit(false, Vector2.RIGHT)
	assert_true(_player.is_hit_stunned)
	assert_true(_player.is_hit_invincible)
	assert_true(_player.is_invincible())


func test_take_hit_flashes_player_sprite_for_clear_feedback() -> void:
	var sprite := _player.get_node("Sprite") as AnimatedSprite2D
	assert_null(sprite.material, "사전 조건: 피격 전에는 플래시 재질이 없어야 함")
	_player.take_hit(false, Vector2.RIGHT)
	assert_true(sprite.material is ShaderMaterial, "피격 순간 캐릭터에 화이트 플래시를 표시해야 함")


func test_light_hit_stun_ends_after_0_25_sec() -> void:
	_player.take_hit(false, Vector2.RIGHT)
	_player._update_hit_reaction(0.24)
	assert_true(_player.is_hit_stunned, "0.25초 전에는 아직 경직 중")
	_player._update_hit_reaction(0.02)
	assert_false(_player.is_hit_stunned, "0.25초 경과 후 경직 종료")


func test_light_hit_invincibility_ends_after_0_6_sec() -> void:
	_player.take_hit(false, Vector2.RIGHT)
	_player._update_hit_reaction(0.59)
	assert_true(_player.is_hit_invincible, "0.6초 전에는 아직 무적")
	_player._update_hit_reaction(0.02)
	assert_false(_player.is_hit_invincible, "0.6초 경과 후 무적 종료")


func test_invincibility_outlasts_stun_light_hit() -> void:
	## 경직(0.25초)이 끝난 뒤에도 무적(0.6초)은 남아 있어야 한다.
	_player.take_hit(false, Vector2.RIGHT)
	_player._update_hit_reaction(0.25)
	assert_false(_player.is_hit_stunned)
	assert_true(_player.is_hit_invincible)


func test_take_hit_ignored_while_already_invincible() -> void:
	_player.take_hit(false, Vector2.RIGHT)
	var stun_timer_before: float = _player._hit_stun_timer
	_player._update_hit_reaction(0.1)
	_player.take_hit(false, Vector2.LEFT)  ## 무적 중이므로 무시되어야 함
	assert_almost_eq(
		_player._hit_stun_timer, stun_timer_before - 0.1, 0.0001, "재피격이 무시되어 경직 타이머가 갱신되지 않아야 함"
	)


func test_take_hit_cancels_ongoing_attack() -> void:
	_player._start_attack_step(0)
	_player.take_hit(false, Vector2.RIGHT)
	assert_eq(_player.attack_state, PlayerController.AttackState.NONE)


func test_take_hit_cancels_ongoing_dash() -> void:
	_player._start_dash()
	_player.take_hit(false, Vector2.RIGHT)
	assert_false(_player.is_dashing)
