## 디렉터 플레이 게이트 차단 버그 재현·회귀 검증 — 플레이어 공격 히트박스가 활성화되면
## 부채꼴 판정 원점이 플레이어 자신의 콜리전과 겹치므로, 충돌 레이어가 정리되어 있지
## 않으면 플레이어 자신이 attack_hit의 target으로 emit된다(공격 시 자기 자신이 데미지를
## 받는 버그의 근본 원인). 실제 물리 판정(Area2D 겹침)으로 재현한다.
extends GutTest

var _player: PlayerController


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)


func test_attack_hitbox_does_not_hit_the_player_itself() -> void:
	watch_signals(_player)
	_player._enable_attack_hitbox(_player.combo_data.steps[0])  ## 1타 판정 활성화 — 원점이 자신과 겹침

	await wait_physics_frames(2)  ## Area2D 겹침 판정은 물리 프레임이 지나야 갱신된다

	assert_signal_not_emitted(_player, "attack_hit", "공격 판정이 플레이어 자기 자신을 target으로 잡으면 안 된다")


func test_direct_handler_call_with_self_as_body_does_not_emit() -> void:
	watch_signals(_player)
	_player._current_action_step = _player.combo_data.steps[0]

	_player._on_attack_hitbox_body_entered(_player)

	assert_signal_not_emitted(_player, "attack_hit")
