## CB-4 회귀 방지 — 2026-07-18 디렉터 플레이 경고 스팸 수정
## ("Vector2 cannot be normalized, the elements must be finite").
##
## take_hit()의 넉백 속도 계산(player_controller.gd)은 `distance_px / _hit_stun_timer`로
## 나눗셈을 한다. _hit_stun_timer(=hit_rules.light_stun_sec)가 0이면 나눗셈이
## Infinity/NaN을 만들어 _knockback_velocity가 비유한 값으로 오염된다.
## monster_base.gd의 동일 계산(_register_stagger_hit)에는 이미 "stagger_duration > 0.0"
## 가드가 있었지만(GDScript 삼항 연산자는 단락 평가라 duration<=0이면 normalized()조차
## 호출되지 않는다), 플레이어 쪽(player_controller.gd:496)에는 대응 가드가 없었다 —
## 본 테스트는 그 비대칭을 take_hit() 직후의 _knockback_velocity 값으로 직접 재현한다
## (수정 전 FAIL).
##
## 주의(조사 중 확인한 사실, 수정 여부와 무관하게 기록): _physics_process()의
## _update_hit_reaction()이 매 프레임 최상단에서 "_hit_stun_timer <= 0.0"이면
## _knockback_velocity를 ZERO로 되돌리기 때문에, take_hit() 직후 곧바로
## _physics_process()를 한 번 호출하는 시나리오에서는 이 오염이 move_and_slide()에
## 도달하기 전에 우연히 자체 교정된다(같은 프레임 안에서 발생 순서상 가려짐).
## 그래서 오염 자체는 take_hit() 반환 직후의 _knockback_velocity로 직접 검증해야
## 실제 계산 버그를 놓치지 않는다 — 이 값을 다른 경로(예: 디버그 HUD, 사운드 트리거
## 등)가 _physics_process 이전에 참조하면 그대로 노출될 수 있는 잠재 위험이었다.
extends GutTest

var _player: PlayerController


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/player/player.tscn")
	_player = scene.instantiate()
	add_child_autofree(_player)
	## 공유 리소스(.tres)를 오염시키지 않도록 테스트 전용 복제본으로 교체한다.
	_player.hit_rules = _player.hit_rules.duplicate()
	_player.hit_rules.light_stun_sec = 0.0


func test_zero_stun_duration_keeps_knockback_velocity_finite() -> void:
	_player.take_hit(false, Vector2.RIGHT)
	assert_true(_player._knockback_velocity.is_finite(), "경직 시간이 0이어도 넉백 속도는 유한해야 함")


func test_zero_stun_duration_keeps_physics_process_velocity_finite() -> void:
	_player.take_hit(false, Vector2.RIGHT)
	_player._physics_process(0.016)
	assert_true(_player.velocity.is_finite())
	assert_true(_player.global_position.is_finite(), "velocity 오염이 위치 좌표로 전파되면 안 됨")
