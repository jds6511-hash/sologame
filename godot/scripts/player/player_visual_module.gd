## 플레이어 애니메이션 갱신 모듈 — pixel-artist AR-1 스프라이트(3방향 시트) 배선.
##
## PlayerController에서 "현재 상태를 어떤 애니메이션 이름으로 그리는가"만 떼어낸 헬퍼다.
## 동작은 종전과 완전히 동일하며(순수 추출), 컨트롤러 쪽 파일 길이 여유를 만들어 검투사
## 분노 게이지(M3 C-1)를 같은 파일에 얹을 수 있게 하기 위한 분리다 — 원거리 상태를
## archer_shot_module.gd로 분리한 것과 같은 패턴(RefCounted, 씬 구조 변경 없음).
##
## 시트는 idle/walk/attack/hit/death 각각 정면(front)/측면(side)/후면(back) 3방향으로
## 구성되어 있다(STYLE_GUIDE.md 3-3장). 좌우는 별도 프레임 없이 측면 애니메이션의
## flip_h로 근사한다(문서 "좌우는 미러 허용" 원칙).
class_name PlayerVisualModule
extends RefCounted

var _player: PlayerController = null
var _sprite: AnimatedSprite2D = null


func setup(player: PlayerController, sprite: AnimatedSprite2D) -> void:
	_player = player
	_sprite = sprite


## 매 프레임 컨트롤러가 호출한다. 컨트롤러의 공개 상태(사망·경직·공격/스킬 상태)는 직접
## 읽고, 컨트롤러 내부 상태(차지 홀드·이동 입력·조준 각도·애니메이션 재시작 요청)는 인자로
## 받는다. restart_attack_anim은 그 프레임 1회성 요청이며 소비는 호출자가 한다.
func update(
	restart_attack_anim: bool,
	is_charging: bool,
	move_input: Vector2,
	last_move_direction: Vector2,
	aim_rotation: float
) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var direction := _facing_vector(is_charging, move_input, last_move_direction, aim_rotation)
	var suffix := _facing_suffix(direction)
	_sprite.flip_h = suffix == "side" and direction.x < 0.0
	var anim_name := "%s_%s" % [_action_name(is_charging, move_input), suffix]
	if not _sprite.sprite_frames.has_animation(anim_name):
		return
	if _sprite.animation != anim_name:
		## 다른 상태로 전환 — 평소처럼 새 애니메이션을 재생한다(불필요한 재시작 방지).
		_sprite.play(anim_name)
	elif restart_attack_anim:
		## 같은 "attack_*"가 이어지는 콤보/홀드라도 스윙마다 프레임0부터 다시 베도록 강제한다.
		## 재시작 가드(animation != anim_name)로는 막히므로 프레임을 명시적으로 0으로 되감는다.
		_sprite.play(anim_name)
		_sprite.set_frame_and_progress(0, 0.0)


## 현재 재생해야 할 상태(동작) 이름 — 애니메이션 이름의 앞부분(예: "walk")이 된다.
func _action_name(is_charging: bool, move_input: Vector2) -> String:
	if _player.is_dead():
		return "death"
	if _player.is_hit_stunned:
		return "hit"
	if _is_acting(is_charging):
		return "attack"
	if move_input.length_squared() > 0.0:
		return "walk"
	return "idle"


## 애니메이션 방향 판정에 쓸 기준 벡터. 공격/스킬 중에는 Facing 노드의 조준 각도를 그대로
## 쓴다(기본 공격은 STARTUP 동안 마우스/자동 조준으로 갱신되다가 ACTIVE 진입 시 고정된다,
## QoL③ _apply_attack_aim 참고). 그 외에는 이동 입력(없으면 마지막 이동 방향)을 쓴다.
func _facing_vector(
	is_charging: bool, move_input: Vector2, last_move_direction: Vector2, aim_rotation: float
) -> Vector2:
	if _is_acting(is_charging):
		return Vector2.RIGHT.rotated(aim_rotation)
	if move_input.length_squared() > 0.0:
		return move_input
	return last_move_direction


## 공격·스킬·차지 중(= "attack" 모션과 조준 방향을 쓰는 상태) 여부.
func _is_acting(is_charging: bool) -> bool:
	return (
		_player.attack_state != PlayerController.AttackState.NONE
		or _player.skill_state != PlayerController.AttackState.NONE
		or is_charging
	)


## 방향 벡터를 3방향 시트 행 이름으로 근사한다 — 상하 성분이 더 크면 정면/후면,
## 아니면 측면(좌우는 flip_h로 구분).
func _facing_suffix(direction: Vector2) -> String:
	if direction == Vector2.ZERO:
		return "front"
	if absf(direction.y) >= absf(direction.x):
		return "back" if direction.y < 0.0 else "front"
	return "side"
