## 스킬 슬롯 시전 모듈 (CB-2, m2-warrior-skills.md) — PlayerController에서 "스킬 슬롯이 어떻게
## 굴러가는가"만 떼어낸 헬퍼다. 원거리 상태를 archer_shot_module.gd로, 분노 게이지를
## player_rage_module.gd로, 애니메이션을 player_visual_module.gd로 분리한 것과 같은 패턴이다
## (RefCounted, 씬 구조 변경 없음). 동작은 종전과 완전히 동일한 순수 추출이다.
##
## 담당 범위 셋:
##   ① 슬롯 입력 -> 사용 게이트(쿨다운·MP) -> 시전 시작
##   ② 시전 진행 상태머신(선딜 -> 판정 -> 후딜)과 판정 발동·해제
##   ③ 쿨다운 장부(슬롯별 + 우클릭 전용)
##
## **컨트롤러에 남긴 것**: `skill_state`·`active_skill`은 HUD·비주얼·AI가 읽는 공개 상태라
## 컨트롤러 변수로 유지한다(이 모듈이 그 값을 갱신한다 — is_dashing 등 다른 공개 상태와 같은
## 구조). 판정 실행 수단(히트박스·화살 발사)과 자기 버프 실적용도 근접/원거리·HP/MP 소관이라
## 컨트롤러에 남기고 여기서는 호출만 한다.
class_name PlayerSkillModule
extends RefCounted

var _player: PlayerController = null

var _phase_timer: float = 0.0
var _dash_direction := Vector2.ZERO
var _cooldowns: Dictionary = {}  ## key: String(슬롯 이름) -> 남은 쿨다운(초)
var _secondary_cooldown: float = 0.0


func setup(player: PlayerController) -> void:
	_player = player


# --- 슬롯 입력 -> 사용 게이트 ---


func process_slot_input() -> void:
	if Input.is_action_just_pressed("skill_slot_1"):
		try_use("slot1", _player.skill_slot_1)
	elif Input.is_action_just_pressed("skill_slot_2"):
		try_use("slot2", _player.skill_slot_2)
	elif Input.is_action_just_pressed("skill_slot_3"):
		try_use("slot3", _player.skill_slot_3)
	elif Input.is_action_just_pressed("skill_slot_4"):
		try_use("slot4", _player.skill_slot_4)
	elif Input.is_action_just_pressed("skill_slot_5"):  ## Q(돌격) — ux-foundation 슬롯5 매핑
		try_use("slot_q", _player.skill_slot_q)
	elif Input.is_action_just_pressed("skill_slot_6"):  ## E(결의의 외침) — 슬롯6 매핑
		try_use("slot_e", _player.skill_slot_e)
	elif Input.is_action_just_pressed("ultimate"):
		try_use("ultimate", _player.skill_ultimate)


## 쿨다운·MP를 확인해 스킬 사용을 시도한다. 성공 시 true.
func try_use(key: String, skill: WarriorSkillData) -> bool:
	if skill == null:
		return false
	if float(_cooldowns.get(key, 0.0)) > 0.0:
		return false
	var cost := mp_cost(skill)
	var stats := _player._stats
	if stats and not stats.has_mp(cost):
		return false
	if stats:
		stats.spend_mp(cost)
	_cooldowns[key] = skill.cooldown_sec
	start(skill)
	return true


func mp_cost(skill: WarriorSkillData) -> float:
	var stats := _player._stats
	if stats == null or stats.stats == null:
		return 0.0
	return stats.stats.max_mp * skill.mp_cost_percent


func start(skill: WarriorSkillData) -> void:
	_player.active_skill = skill
	_player.skill_state = PlayerController.AttackState.STARTUP
	_phase_timer = 0.0
	_player.skill_used.emit(skill.skill_name)


## 차지 강타처럼 홀드 단계가 이미 시전(startup)을 대신한 경우, ACTIVE부터 바로 시작한다.
func begin_active(skill: WarriorSkillData) -> void:
	_player.active_skill = skill
	_player.skill_state = PlayerController.AttackState.ACTIVE
	_phase_timer = 0.0
	_player.skill_used.emit(skill.skill_name)
	_activate(skill)


# --- 시전 진행 상태머신 ---


func process_state(delta: float) -> void:
	var skill := _player.active_skill
	_phase_timer += delta
	match _player.skill_state:
		PlayerController.AttackState.STARTUP:
			_player.velocity = Vector2.ZERO
			if _phase_timer >= skill.startup_sec:
				_player.skill_state = PlayerController.AttackState.ACTIVE
				_phase_timer = 0.0
				_activate(skill)
		PlayerController.AttackState.ACTIVE:
			if skill.skill_type == WarriorSkillData.SkillType.DASH:
				## max()는 인자 타입에 따라 가변 반환 타입을 갖는 엔진 내장 함수라 :=로는
				## 정적 타입을 추론할 수 없다 — 명시적으로 float 타입을 지정한다.
				var safe_duration_sec: float = maxf(skill.dash_duration_sec, 0.0001)
				var speed_px: float = (
					_player.movement_data.tile_size_px
					* skill.dash_distance_tiles
					/ safe_duration_sec
				)
				_player.velocity = _dash_direction * speed_px
			else:
				_player.velocity = Vector2.ZERO
			if _phase_timer >= skill.get_active_duration_sec():
				_player.skill_state = PlayerController.AttackState.RECOVERY
				_phase_timer = 0.0
				_player._disable_attack_hitbox()
		PlayerController.AttackState.RECOVERY:
			_player.velocity = Vector2.ZERO
			if _phase_timer >= skill.recovery_sec:
				finish()


## 스킬 판정 발동. 궁수 스킬(arrow 보유)은 근접 히트박스 대신 화살을 발사한다 — 곡예 사격은
## 이동 방향(입력)과 사격 방향(조준)이 독립이므로 DASH 분기에서 둘을 함께 처리한다(4-2장).
func _activate(skill: WarriorSkillData) -> void:
	match skill.skill_type:
		WarriorSkillData.SkillType.DASH:
			_dash_direction = _player._last_move_direction
			if not _player._try_fire_arrows(skill) and skill.hitbox_range_tiles > 0.0:
				_player._enable_attack_hitbox(skill)
		WarriorSkillData.SkillType.BUFF_HEAL:
			_player._apply_self_buff(skill)
		_:  ## INSTANT · CHARGE · ULTIMATE
			if not _player._try_fire_arrows(skill) and skill.hitbox_range_tiles > 0.0:
				_player._enable_attack_hitbox(skill)


func cancel() -> void:
	_player._disable_attack_hitbox()
	_player._shots.cancel_burst()
	_player.skill_state = PlayerController.AttackState.NONE
	_player.active_skill = null


func finish() -> void:
	_player.skill_state = PlayerController.AttackState.NONE
	_player.active_skill = null


# --- 쿨다운 장부 ---


func advance_cooldowns(delta: float) -> void:
	for key in _cooldowns.keys():
		if _cooldowns[key] > 0.0:
			_cooldowns[key] = max(_cooldowns[key] - delta, 0.0)
	if _secondary_cooldown > 0.0:
		_secondary_cooldown = max(_secondary_cooldown - delta, 0.0)


func remaining(key: String) -> float:
	return float(_cooldowns.get(key, 0.0))


## 우클릭(차지 강타·처형 일격) 전용 쿨다운 — 슬롯 장부와 분리돼 있다.
func secondary_ready() -> bool:
	return _secondary_cooldown <= 0.0


func set_secondary_cooldown(sec: float) -> void:
	_secondary_cooldown = sec


## 전직 로드아웃 교체 시 잔여 쿨다운을 전부 지운다.
func clear_cooldowns() -> void:
	_cooldowns.clear()
	_secondary_cooldown = 0.0
