## 분노 게이지 모듈 (M3 C-1) — m3-warrior-tier2-skills.md 2장.
##
## 전사 2차 전직(검투사)의 고유 자원이다. PlayerController에서 "게이지 상태"만 떼어낸
## 헬퍼로, 원거리 상태를 archer_shot_module.gd로 분리한 것과 같은 패턴이다(RefCounted,
## 씬 구조 변경 없음).
##
## 담당 범위 넷:
##   ① 충전 — 기본 공격 명중 +4 / 스킬 명중 +8 / 치명타 ×1.5 / 피격 +12 (2-2장)
##   ② 격노 — 게이지 ≥ 80이면 공격력 +12% (2-3장)
##   ③ 감쇠 — 전투 이탈 5초 후 초당 -5 (2-4장)
##   ④ 소모 — 처형 일격 발동 시 전량 소모 + 소모량 선형 비례 계수 3.5~5.0 (2-3·4-4장)
##
## **활성 조건과 수치의 출처**: 이 모듈은 "우클릭 격노 파생 스킬"(처형 일격 —
## GladiatorSkillData)이 배선돼 있을 때만 동작하고, 게이지 규칙 수치도 전부 그 리소스에서
## 읽는다. 즉 분노 게이지는 검투사 로드아웃(job_def_gladiator.tres)이 적용된 순간에만
## 켜지고, 1차 전사·궁수·모험가에서는 finisher가 null이라 완전히 비활성이다 —
## ArcherShotModule이 우클릭 슬롯의 is_aim_stance로 조준 모드 활성을 판정하는 것과 같은
## 방식이다. 기획서 9장은 충전량을 스킬마다 필드로 두는 안을 제시했지만("스키마 확장 방식
## 위임"), 충전량이 기본 4 / 스킬 8로 균일하므로 전 스킬에 같은 값을 복제하는 대신 게이지
## 규칙을 피니셔 1개 리소스에 모았다(튜닝 지점 단일화).
class_name PlayerRageModule
extends RefCounted

## 게이지 값이 바뀔 때마다 발신 — 분노 게이지 HUD(ui-dev) 연동 지점.
signal rage_changed(current_rage: float, max_rage: float)
## 격노 상태(공격력 +12%) 진입/해제 시 발신 — 게이지 발광 연출용.
signal enrage_changed(is_enraged: bool)

## 우클릭 격노 파생 스킬(처형 일격). null이면 이 직업은 분노 게이지를 쓰지 않는다.
var finisher: GladiatorSkillData = null
var current_rage: float = 0.0

var _is_enraged: bool = false
## 마지막 유효 전투 행동(명중·피격) 이후 경과 시간 — 5초를 넘기면 감쇠가 시작된다.
var _combat_idle_sec: float = 0.0
## 혈투의 함성 버프 상태(분노 충전 +50% · 흡혈) — 지속시간이 끝나면 전부 0으로 돌아간다.
var _buff_timer: float = 0.0
var _rage_gain_bonus: float = 0.0
var _lifesteal_percent: float = 0.0
var _lifesteal_budget: float = 0.0  ## 이번 발동에서 남은 흡혈 회복 한도(최대 HP 30%)


## 전직 로드아웃 교체 시 호출된다(우클릭 격노 파생 슬롯을 그대로 넘긴다). 직업이 바뀌면
## 게이지는 0에서 다시 시작한다(2-1장 "시작치 0").
func save_block_reason() -> String:
	return "cooldown_or_buff" if _buff_timer > 0.0 else ""


func refresh_job(rage_finisher: WarriorSkillData) -> void:
	finisher = rage_finisher as GladiatorSkillData
	reset()


## 이 직업이 분노 게이지를 쓰는지(검투사만 true).
func is_active() -> bool:
	return finisher != null


func max_rage() -> float:
	return finisher.rage_max if finisher != null else 0.0


func reset() -> void:
	current_rage = 0.0
	_combat_idle_sec = 0.0
	_buff_timer = 0.0
	_rage_gain_bonus = 0.0
	_lifesteal_percent = 0.0
	_lifesteal_budget = 0.0
	_set_enraged(false)
	rage_changed.emit(current_rage, max_rage())


# --- 충전 (2-2장) ---


## 공격 판정이 성립했을 때 호출된다. action은 판정 주체(기본 콤보 스텝 또는 스킬)이며,
## 스킬이면 +8 / 기본 공격이면 +4를 충전한다. 처형 일격 자신은 분노를 소모하는 스킬이므로
## 충전하지 않는다(4-4장).
func add_from_attack(action: Resource, is_critical: bool) -> void:
	if not is_active() or _is_finisher(action):
		return
	var amount: float = (
		finisher.rage_gain_skill_hit if action is WarriorSkillData else finisher.rage_gain_basic_hit
	)
	if is_critical:
		amount *= finisher.rage_gain_crit_multiplier
	_add(amount)


## 실제로 피해를 입었을 때 호출된다 — 전사 정체성 "맞으면서 밀어붙이기"의 최대 단일 충전원.
func add_from_hit_taken() -> void:
	if not is_active():
		return
	_add(finisher.rage_gain_on_hit_taken)


func _add(amount: float) -> void:
	_combat_idle_sec = 0.0  ## 명중·피격은 유효 전투 행동 — 감쇠 타이머를 되돌린다
	if amount <= 0.0:
		return
	current_rage = clampf(current_rage + amount * (1.0 + _rage_gain_bonus), 0.0, max_rage())
	rage_changed.emit(current_rage, max_rage())
	_refresh_enrage()


# --- 격노 (2-3장) ---


func is_enraged() -> bool:
	return _is_enraged


## 격노 중 전 데미지에 곱해지는 배율(공격력 +12%). 게이지 비활성·미격노 시 1.0.
##
## 데미지는 공격력과 계수에 각각 선형이므로(combat.md 6장), 리졸버가 계수에 이 배율을
## 곱하는 것과 공격력에 곱하는 것은 결과가 동일하다 — 공유 CombatantStats를 런타임에
## 덮어쓰지 않기 위해 계수 쪽에 곱한다.
func attack_multiplier() -> float:
	if not is_active() or not _is_enraged:
		return 1.0
	return 1.0 + finisher.enrage_attack_buff_percent


func _refresh_enrage() -> void:
	_set_enraged(is_active() and current_rage >= finisher.rage_enrage_threshold)


func _set_enraged(value: bool) -> void:
	if _is_enraged == value:
		return
	_is_enraged = value
	enrage_changed.emit(value)


# --- 감쇠 (2-4장) ---


## 매 프레임 컨트롤러가 호출한다 — 혈투의 함성 버프 지속시간과 전투 이탈 감쇠를 진행한다.
func advance(delta: float) -> void:
	if not is_active():
		return
	_advance_buff(delta)
	var idle_before := _combat_idle_sec
	_combat_idle_sec += delta
	var exit_sec: float = finisher.rage_combat_exit_sec
	if current_rage <= 0.0 or _combat_idle_sec <= exit_sec:
		return
	## 이번 delta 구간 중 전투 이탈 판정을 "넘어선" 부분만 감쇠에 반영한다 — 경계를 넘는
	## 프레임의 delta 전부를 감쇠로 치지 않기 위한 처리(PlayerStatsComponent 자연 회복과 동일).
	var overlap_sec: float = _combat_idle_sec - maxf(idle_before, exit_sec)
	current_rage = maxf(current_rage - finisher.rage_decay_per_sec * overlap_sec, 0.0)
	rage_changed.emit(current_rage, max_rage())
	_refresh_enrage()


# --- 소모·처형 일격 (2-3·4-4장) ---


## 지금 처형 일격을 쓸 수 있는지 — 게이지가 발동 하한(50) 이상인지.
func can_use_finisher() -> bool:
	return is_active() and current_rage >= finisher.rage_finisher_min


## 보유 분노를 전량 소모하고 소모량을 돌려준다(발동 불가면 0).
func consume_for_finisher() -> float:
	if not can_use_finisher():
		return 0.0
	var consumed := current_rage
	current_rage = 0.0
	_combat_idle_sec = 0.0
	rage_changed.emit(current_rage, max_rage())
	_refresh_enrage()
	return consumed


## 소모 분노에 선형 비례하는 처형 일격 계수 — 하한 소모(50) 3.5 ~ 만땅(100) 5.0.
func finisher_coefficient(consumed_rage: float) -> float:
	if not is_active():
		return 0.0
	var span: float = maxf(finisher.rage_max - finisher.rage_finisher_min, 0.0001)
	var ratio := clampf((consumed_rage - finisher.rage_finisher_min) / span, 0.0, 1.0)
	return lerpf(finisher.rage_coefficient_at_min, finisher.rage_coefficient_at_max, ratio)


# --- 혈투의 함성 버프 (4-3장 — 흡혈 + 분노 충전 가속) ---


## 혈투의 함성 발동 시 호출된다. mult는 스킬 강화 배율(+8%/레벨)이고 max_hp는 흡혈 총량
## 상한(최대 HP 30%) 계산 기준이다. 검투사 버프가 아니면(다른 직업의 버프·힐) 무시한다.
func apply_buff(skill: GladiatorSkillData, mult: float, max_hp: float) -> void:
	if skill == null or skill.buff_duration_sec <= 0.0:
		return
	_buff_timer = skill.buff_duration_sec * mult
	_rage_gain_bonus = skill.rage_gain_buff_percent * mult
	_lifesteal_percent = skill.lifesteal_percent * mult
	## 회복 총량 상한은 강화 배율을 곱하지 않는다 — combat.md 7장 "버프·힐 총 회복 20~30%"
	## 하드 캡이라 강화로 넘길 수 없어야 한다(4-3장).
	_lifesteal_budget = max_hp * skill.lifesteal_total_cap_percent


## 가한 피해에서 흡혈로 회복할 양(총량 상한 안에서). 버프가 없으면 0.
func lifesteal_heal(damage: float) -> float:
	if _lifesteal_percent <= 0.0 or _lifesteal_budget <= 0.0 or damage <= 0.0:
		return 0.0
	var healed: float = minf(damage * _lifesteal_percent, _lifesteal_budget)
	_lifesteal_budget -= healed
	return healed


func _advance_buff(delta: float) -> void:
	if _buff_timer <= 0.0:
		return
	_buff_timer = maxf(_buff_timer - delta, 0.0)
	if _buff_timer <= 0.0:
		_rage_gain_bonus = 0.0
		_lifesteal_percent = 0.0
		_lifesteal_budget = 0.0


func _is_finisher(action: Resource) -> bool:
	var skill := action as GladiatorSkillData
	return skill != null and skill.is_rage_finisher
