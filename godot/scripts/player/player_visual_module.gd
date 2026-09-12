## 플레이어 애니메이션 갱신 모듈 — pixel-artist AR-1 스프라이트(3방향 시트) 배선.
##
## PlayerController에서 "현재 상태를 어떤 애니메이션 이름으로 그리는가"만 떼어낸 헬퍼다.
## 동작은 종전과 완전히 동일하며(순수 추출), 컨트롤러 쪽 파일 길이 여유를 만들어 검투사
## 분노 게이지(M3 C-1)를 같은 파일에 얹을 수 있게 하기 위한 분리다 — 원거리 상태를
## archer_shot_module.gd로 분리한 것과 같은 패턴(RefCounted, 씬 구조 변경 없음).
##
## 시트는 상태별로 정면(front)/측면(side)/후면(back) 3방향으로 구성되어 있다
## (STYLE_GUIDE.md 3-3장). 좌우는 별도 프레임 없이 측면 애니메이션의 flip_h로 근사한다
## (문서 "좌우는 미러 허용" 원칙).
##
## M3 3-A 정식 시트(직업당 9상태 27종)부터는 상태가 직업마다 다르다 — 전사는
## attack2/charge, 궁수는 aim/rollshot을 갖고 서로 없는 쪽이 있다. 그래서 상태 하나에
## 이름 하나를 대응시키는 대신 **우선순위 후보 목록**을 만들어 시트에 실제로 있는 첫
## 이름을 재생한다(_resolve_action). 시트에 없는 상태는 자동으로 종전 이름(attack/idle 등)
## 으로 접히므로, 전용 시트가 없는 직업(검투사)도 전사 시트로 그대로 굴러간다.
class_name PlayerVisualModule
extends RefCounted

var _player: PlayerController = null
var _sprite: AnimatedSprite2D = null
## 궁수 조준 스탠스 활성 여부를 읽을 원거리 모듈(조준 자세·조준 방향 판정용).
var _shots: ArcherShotModule = null
## 전직이 지정한 직업 시트. 컨트롤러의 @onready(_sprite)보다 먼저 들어올 수 있어(전직 노드의
## _ready가 부모보다 먼저 돈다) 여기에 담아 두고 setup에서 반영한다.
var _job_sprite_frames: SpriteFrames = null
## 이번 프레임의 콤보 스텝 인덱스(update 인자로 받아 후보 판정 중에만 쓴다).
var _attack_step_index: int = -1
var _attack_pose_synced: bool = false


func setup(player: PlayerController, sprite: AnimatedSprite2D, shots: ArcherShotModule) -> void:
	_player = player
	_sprite = sprite
	_shots = shots
	_apply_job_sprite_frames()


## 직업 전용 스프라이트 시트로 교체한다(JobDefinition.sprite_frames). 전사 시트와 궁수 시트는
## 무기와 상태 구성이 다르므로(attack2·charge vs aim·rollshot) 상태별이 아니라 시트째 교체가
## 맞다 — 애니메이션 이름 규약은 공통이고, 없는 상태는 후보 폴백이 종전 이름으로 접는다.
## null이면 전용 시트가 없는 직업(검투사 — 전사 시트를 계속 쓴다)이라 현재 시트를 유지한다.
func set_job_sprite_frames(frames: SpriteFrames) -> void:
	if frames == null:
		return
	_job_sprite_frames = frames
	_apply_job_sprite_frames()


func _apply_job_sprite_frames() -> void:
	if _job_sprite_frames == null or _sprite == null:
		return
	if _sprite.sprite_frames == _job_sprite_frames:
		return
	_sprite.sprite_frames = _job_sprite_frames
	## 교체 직전 재생 중이던 상태가 새 시트에 없을 수 있다(전사 attack2 -> 궁수). 다음 update가
	## 올바른 이름으로 갈아타기 전 한 프레임을 대기 자세로 채운다.
	var stale := not _job_sprite_frames.has_animation(_sprite.animation)
	if stale and _job_sprite_frames.has_animation(&"idle_front"):
		_sprite.play(&"idle_front")


## 매 프레임 컨트롤러가 호출한다. 컨트롤러의 공개 상태(사망·경직·대시·공격/스킬 상태)는 직접
## 읽고, 컨트롤러 내부 상태(차지 홀드·이동 입력·조준 각도·콤보 스텝·애니메이션 재시작 요청)는
## 인자로 받는다. restart_attack_anim은 그 프레임 1회성 요청이며 소비는 호출자가 한다.
func update(
	restart_attack_anim: bool,
	is_charging: bool,
	move_input: Vector2,
	last_move_direction: Vector2,
	aim_rotation: float,
	attack_step_index: int
) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	_attack_step_index = attack_step_index
	var direction := _facing_vector(is_charging, move_input, last_move_direction, aim_rotation)
	var suffix := _facing_suffix(direction)
	_sprite.flip_h = suffix == "side" and direction.x < 0.0
	var anim_name := _resolve_action(_action_candidates(is_charging, move_input), suffix)
	if anim_name.is_empty():
		return
	if _sprite.animation != anim_name:
		## 다른 상태로 전환 — 평소처럼 새 애니메이션을 재생한다(불필요한 재시작 방지).
		_sprite.play(anim_name)
	elif restart_attack_anim:
		## 같은 "attack_*"가 이어지는 콤보/홀드라도 스윙마다 프레임0부터 다시 베도록 강제한다.
		## 재시작 가드(animation != anim_name)로는 막히므로 프레임을 명시적으로 0으로 되감는다.
		_sprite.play(anim_name)
		_sprite.set_frame_and_progress(0, 0.0)
	var was_synced := _attack_pose_synced
	_attack_pose_synced = _sync_attack_pose(anim_name)
	if was_synced and not _attack_pose_synced and not _sprite.is_playing():
		_sprite.play(anim_name)
		if _player.is_dashing:
			_sprite.set_frame_and_progress(0, 0.0)


## 현재 4프레임 시트 계약: 검 0/1/2~3, 활 0~1/2/3 = 선딜/판정/후딜.
## 고정 FPS 대신 판정 시계를 사용해 재조준·공속·히트스톱에도 같은 자세를 유지한다.
func _sync_attack_pose(anim_name: String) -> bool:
	if anim_name.begins_with("dodge") and _is_travel_skill() and not _player.is_dashing:
		if _sprite.sprite_frames.get_frame_count(anim_name) == 3:
			_sprite.pause()
			_sprite.set_frame_and_progress(int(_player.skill_state) - 1, 0.0)
			return true
	if not (anim_name.begins_with("attack") or anim_name.begins_with("rollshot")):
		return false
	var phase := _player.attack_state
	var ranged := false
	if _player.skill_state != PlayerController.AttackState.NONE:
		phase = _player.skill_state
		ranged = _player.active_skill is ArcherSkillData
	elif _player.combo_data != null and _attack_step_index >= 0:
		if _attack_step_index >= _player.combo_data.steps.size():
			return false
		ranged = _player.combo_data.steps[_attack_step_index] is ArcherAttackStep
	if phase == PlayerController.AttackState.NONE:
		return false
	if _sprite.sprite_frames.get_frame_count(anim_name) != 4:
		return false
	var progress := _player.get_action_phase_progress()
	var pose := 0
	match phase:
		PlayerController.AttackState.STARTUP:
			pose = 1 if ranged and progress >= 0.5 else 0
		PlayerController.AttackState.ACTIVE:
			pose = 2 if ranged else 1
		PlayerController.AttackState.RECOVERY:
			pose = 3 if ranged or progress >= 0.5 else 2
	_sprite.pause()
	_sprite.set_frame_and_progress(pose, 0.0)
	return true


## 후보 목록을 앞에서부터 훑어 현재 시트에 실제로 있는 첫 애니메이션 이름을 고른다.
## 하나도 없으면 빈 문자열(= 이 프레임은 애니메이션을 바꾸지 않는다).
func _resolve_action(candidates: PackedStringArray, suffix: String) -> String:
	for action in candidates:
		var anim_name := "%s_%s" % [action, suffix]
		if _sprite.sprite_frames.has_animation(anim_name):
			return anim_name
	return ""


## 현재 재생해야 할 상태(동작) 이름 후보 — 앞이 우선이고, 뒤로 갈수록 "시트에 전용 상태가
## 없을 때의 대체"다. 상태 판정 순서는 컨트롤러의 _physics_process 분기 우선순위
## (사망 > 경직 > 대시 > 스킬 > 차지 > 기본 공격)와 같게 맞췄다.
func _action_candidates(is_charging: bool, move_input: Vector2) -> PackedStringArray:
	if _player.is_dead():
		return PackedStringArray(["death"])
	if _player.is_hit_stunned:
		return PackedStringArray(["hit"])
	if _player.is_dashing:
		## 회피 대시 — 전사 사이드스텝·궁수 후방 점프 모두 같은 dodge 시트(3프레임 도약).
		return PackedStringArray(["dodge", "walk", "idle"])
	if _player.skill_state != PlayerController.AttackState.NONE:
		return _skill_candidates()
	if is_charging:
		## 차지 홀드 — 상체를 젖혀 버티는 정지 자세(슈퍼아머가 자세로 읽힌다).
		return PackedStringArray(["charge", "attack"])
	return _neutral_candidates(move_input)


## 사망·경직·대시·스킬·차지가 아닐 때의 후보 — 기본 공격 / 조준 스탠스 / 이동 / 대기.
func _neutral_candidates(move_input: Vector2) -> PackedStringArray:
	if _player.attack_state != PlayerController.AttackState.NONE:
		return _attack_candidates()
	if _is_aiming():
		## 궁수 조준 스탠스 — 사격 사이클 사이의 "반쯤 당긴 무방비" 정지 자세.
		return PackedStringArray(["aim", "idle"])
	if move_input.length_squared() > 0.0:
		return PackedStringArray(["walk"])
	return PackedStringArray(["idle"])


## 스킬 시전 중 후보. 스킬 종류(데이터)로만 갈라 스킬 이름을 코드에 넣지 않는다.
##   BUFF_HEAL(응급 처치·결의의 외침·매의 눈) -> cast(포효/자가 버프 자세)
##   궁수 DASH(곡예 사격) -> rollshot(구르며 사격)
##   근접 DASH(질주·돌격·난입 강타) -> dodge(기존 아트 계획의 몸 낮춤 재사용)
##   그 외(강타·분쇄 베기·궁극기 등) -> attack
func _skill_candidates() -> PackedStringArray:
	var skill := _player.active_skill
	if skill == null:
		return PackedStringArray(["attack"])
	if skill.skill_type == WarriorSkillData.SkillType.BUFF_HEAL:
		return PackedStringArray(["cast", "idle"])
	if skill is ArcherSkillData and skill.skill_type == WarriorSkillData.SkillType.DASH:
		return PackedStringArray(["rollshot", "attack"])
	if skill.skill_type == WarriorSkillData.SkillType.DASH:
		return PackedStringArray(["dodge", "walk", "idle"])
	return PackedStringArray(["attack"])


func _is_travel_skill() -> bool:
	return (
		_player.skill_state != PlayerController.AttackState.NONE
		and _player.active_skill != null
		and not _player.active_skill is ArcherSkillData
		and _player.active_skill.skill_type == WarriorSkillData.SkillType.DASH
	)


## 기본 공격 콤보 중 후보. N타는 "attackN"을 먼저 찾고 없으면 attack으로 접는다 —
## 전사 대검 2타(횡베기 attack2)가 이 경로로 재생되고, 콤보가 3타로 늘어도 시트에
## attack3만 추가하면 코드 수정 없이 잡힌다(궁수 활은 1타라 항상 attack).
func _attack_candidates() -> PackedStringArray:
	if _attack_step_index >= 1:
		return PackedStringArray(["attack%d" % (_attack_step_index + 1), "attack"])
	return PackedStringArray(["attack"])


## 궁수 조준 스탠스(우클릭 홀드) 활성 여부. 원거리 모듈이 없는 씬/테스트에서는 false.
func _is_aiming() -> bool:
	return _shots != null and _shots.is_aiming


## 애니메이션 방향 판정에 쓸 기준 벡터. 공격/스킬 중에는 Facing 노드의 조준 각도를 그대로
## 쓴다(기본 공격은 STARTUP 동안 마우스/자동 조준으로 갱신되다가 ACTIVE 진입 시 고정된다,
## QoL③ _apply_attack_aim 참고). 그 외에는 이동 입력(없으면 마지막 이동 방향)을 쓴다.
func _facing_vector(
	is_charging: bool, move_input: Vector2, last_move_direction: Vector2, aim_rotation: float
) -> Vector2:
	if _is_travel_skill() and not _player.is_dashing:
		return _player.get_skill_travel_direction()
	if _uses_aim_facing(is_charging):
		return Vector2.RIGHT.rotated(aim_rotation)
	if move_input.length_squared() > 0.0:
		return move_input
	return last_move_direction


## 이동 방향 대신 조준 각도를 애니메이션 방향으로 쓰는 상태 여부.
##
## 공격·스킬·차지 중에 조준 방향을 쓰는 것은 종전과 같고, M3 3-A에서 둘을 추가했다:
##   ① 궁수 조준 스탠스 — 스탠스 자체가 "적을 겨눈 정지"이므로 조준 방향으로 서야 한다.
##   ② 궁수 후방 점프 회피 — 대시 방향은 조준의 반대이지만 적을 계속 겨눈 채 뒤로 뛰는
##      동작이라 몸은 조준 쪽을 향한다(시트 note "뒤로 뛰는 방향감은 이동·vfx가 보조").
##      대시 중에는 컨트롤러가 조준을 갱신하지 않으므로 회피 시작 시점의 각도가 유지된다.
##      전사 대시는 입력 방향으로 튀므로 종전대로 이동 방향을 쓴다.
func _uses_aim_facing(is_charging: bool) -> bool:
	if _player.is_dashing:
		return _player.combo_data != null and _player.combo_data.dodge_backward
	return (
		_player.attack_state != PlayerController.AttackState.NONE
		or _player.skill_state != PlayerController.AttackState.NONE
		or is_charging
		or _is_aiming()
	)


## 방향 벡터를 3방향 시트 행 이름으로 근사한다 — 상하 성분이 더 크면 정면/후면,
## 아니면 측면(좌우는 flip_h로 구분).
func _facing_suffix(direction: Vector2) -> String:
	if direction == Vector2.ZERO:
		return "front"
	if absf(direction.y) >= absf(direction.x):
		return "back" if direction.y < 0.0 else "front"
	return "side"
