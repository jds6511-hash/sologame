## 정예 공용 프레임 검증 — 슈퍼아머 + 그로기 게이지(combat.md 5-2 정예 행,
## m3-monster-spec.md 7-4·7-5장). 정예 20종 전체가 쓰는 MonsterBase 공용 구현이라
## 대표 정예(포효 임프장 = 정예 아종)로 검증한다.
##
## 검증하는 계약:
##   - 게이지 최대치 = 유효 최대 HP × groggy_gauge_hp_ratio(0.25) — 야간 배율에도 자동 정합
##   - 평시 슈퍼아머(경직·넉백 무효) → 게이지 만충 시 그로기(3초, 무방비) → 복귀
##   - 플레이어 도메인 연동 API: add_groggy(절대값) / add_groggy_ratio(최대치 비율)
extends GutTest

const LORD_STATS_PATH := "res://data/monsters/imp_lord_stats.tres"
const IMP_STATS_PATH := "res://data/monsters/imp_stats.tres"

var _lord: ImpMonster


func before_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()
	_lord = _spawn_imp(LORD_STATS_PATH)


func after_each() -> void:
	GameClock.reset()
	PackAggroCoordinator.reset_all()


func _spawn_imp(stats_path: String, with_stagger: bool = true) -> ImpMonster:
	var imp := ImpMonster.new()
	imp.stats = load(stats_path)
	M3MonsterTestRig.attach_attack_hitbox(imp)
	if with_stagger:
		M3MonsterTestRig.attach_stagger(imp, true)  ## 경량 체급(spec 4-3 넉백 체급)
	add_child_autofree(imp)
	imp.global_position = Vector2.ZERO
	imp.home_position = Vector2.ZERO
	return imp


## 피격 경직 컴포넌트가 실제로 경직을 등록했는지 — 정예 슈퍼아머의 붕괴 여부를 그로기 상태와
## 분리해 확인한다(is_staggered()는 그로기 자체로도 true가 되므로 구분이 필요하다).
func _mob_stagger(monster: MonsterBase) -> MobStaggerComponent:
	return monster.get_node("MobStagger")


# --- 게이지 최대치 ---


func test_only_elite_and_boss_use_groggy_gauge() -> void:
	assert_true(_lord.uses_groggy_gauge(), "정예는 그로기 게이지를 쓴다")
	assert_false(_spawn_imp(IMP_STATS_PATH).uses_groggy_gauge(), "잡몹은 평시부터 경직 — 게이지 무의미")


func test_gauge_max_is_quarter_of_effective_max_hp() -> void:
	assert_almost_eq(_lord.groggy_gauge_max(), _lord.effective_max_hp() * 0.25, 0.01)


## 야간에는 정예 HP도 ×1.2(combat.md 2-3)이므로 게이지 최대치도 같은 비율로 커져야 한다
## (수치표 없이 배율과 자동 정합 — monster_stats_data.gd 산출 근거 주석).
func test_gauge_max_follows_night_multiplier() -> void:
	var day_max := _lord.groggy_gauge_max()
	GameClock.advance_time(1200.0)  ## 밤 진입
	var night_lord := _spawn_imp(LORD_STATS_PATH)
	assert_almost_eq(night_lord.groggy_gauge_max(), day_max * 1.2, 0.1)


# --- 축적 → 그로기 → 복귀 ---


func test_damage_accumulates_gauge_by_final_amount() -> void:
	_lord.take_damage(100.0)
	assert_almost_eq(_lord.groggy_gauge, 100.0, 0.01, "누적 단위 = 실제로 들어간 최종 피해량")


func test_jobmob_does_not_accumulate_gauge() -> void:
	var imp := _spawn_imp(IMP_STATS_PATH)
	imp.take_damage(100.0)
	assert_eq(imp.groggy_gauge, 0.0)
	assert_false(imp.is_groggy())


func test_elite_has_superarmor_before_gauge_fills() -> void:
	_lord.take_damage(10.0)
	assert_false(_lord.is_groggy())
	assert_false(_mob_stagger(_lord).is_staggered(), "combat.md 5-2 정예: 평시 슈퍼아머(경직·넉백 없음)")
	assert_false(_lord.is_staggered())


func test_full_gauge_starts_groggy_and_breaks_superarmor() -> void:
	watch_signals(_lord)
	_lord.take_damage(_lord.groggy_gauge_max())
	assert_signal_emitted(_lord, "groggy_started")
	assert_true(_lord.is_groggy(), "게이지 만충 → 3초 그로기")
	assert_true(_lord.is_staggered(), "그로기 중에는 행동 불가 — 상태머신이 멈춘다")
	assert_true(_mob_stagger(_lord).is_staggered(), "슈퍼아머 붕괴 — 경직이 정상 등록된다(무방비 딜 타임)")


## 그로기 지속(3초)이 끝나면 게이지가 비고 슈퍼아머가 복귀한다. 경직 컴포넌트 없이 검증해
## is_staggered()가 그로기만 반영하게 한다(컴포넌트가 있으면 만충 타격의 경직 0.15초가 섞인다).
func test_groggy_ends_after_duration_and_resets_gauge() -> void:
	var lord := _spawn_imp(LORD_STATS_PATH, false)
	watch_signals(lord)
	lord.take_damage(lord.groggy_gauge_max())
	lord._process(1.0)
	assert_true(lord.is_groggy(), "지속 3.0초 — 1초 경과로는 끝나지 않는다")
	lord._process(2.1)
	assert_signal_emitted(lord, "groggy_ended")
	assert_false(lord.is_groggy())
	assert_eq(lord.groggy_gauge, 0.0, "그로기 종료 시 게이지 초기화")
	assert_false(lord.is_staggered(), "슈퍼아머 복귀")


func test_gauge_does_not_accumulate_while_groggy() -> void:
	_lord.take_damage(_lord.groggy_gauge_max())
	_lord.take_damage(50.0)
	assert_eq(_lord.groggy_gauge, _lord.groggy_gauge_max(), "그로기 중 추가 축적은 무시")


## 그로기(3초)는 경직(0.15~0.25초)보다 훨씬 길다 — 경직이 끝난 뒤에는 넉백 속도가 남아
## 그로기 내내 밀려나가지 않아야 한다(그 동안에도 is_staggered()는 true = 행동 불가 유지).
func test_knockback_stops_when_stagger_expires_during_groggy() -> void:
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.global_position = Vector2(-32.0, 0.0)
	_lord.take_damage(_lord.groggy_gauge_max(), "약", attacker)
	assert_ne(_lord.stagger_velocity(), Vector2.ZERO, "만충 타격의 넉백은 적용된다")
	_mob_stagger(_lord).advance_time(1.0)  ## 경직 0.15초 종료 (그로기는 아직 3초 중)
	assert_true(_lord.is_groggy())
	assert_eq(_lord.stagger_velocity(), Vector2.ZERO, "경직이 끝나면 넉백 이동은 멈춘다")


## 슈퍼아머로 넉백이 무효였던 직전 타격의 속도가 그로기 진입 시 남아 있지 않아야 한다.
func test_groggy_entry_clears_stale_knockback() -> void:
	var lord := _spawn_imp(LORD_STATS_PATH, false)  ## 경직 컴포넌트 없음 = 넉백 산출 없음
	lord.take_damage(lord.groggy_gauge_max())
	assert_true(lord.is_groggy())
	assert_eq(lord.stagger_velocity(), Vector2.ZERO)


func test_gauge_is_capped_at_max() -> void:
	_lord.add_groggy(_lord.groggy_gauge_max() * 10.0)
	assert_eq(_lord.groggy_gauge, _lord.groggy_gauge_max())


# --- 플레이어 도메인 연동 API 계약 (호출부는 gameplay-dev 몫) ---


func test_add_groggy_ratio_accumulates_share_of_max() -> void:
	watch_signals(_lord)
	_lord.add_groggy_ratio(0.4)  ## 예: 전사 2차 "난입 강타" 대량 축적
	assert_almost_eq(_lord.groggy_gauge, _lord.groggy_gauge_max() * 0.4, 0.01)
	assert_signal_emitted(_lord, "groggy_gauge_changed")
	_lord.add_groggy_ratio(0.4)
	_lord.add_groggy_ratio(0.4)  ## 누적 120% → 만충
	assert_signal_emitted(_lord, "groggy_started", "비율 축적만으로도 그로기가 성립해야 한다")


func test_add_groggy_on_jobmob_is_ignored() -> void:
	var imp := _spawn_imp(IMP_STATS_PATH)
	imp.add_groggy_ratio(2.0)
	assert_false(imp.is_groggy(), "잡몹에 대한 축적 호출은 무해하게 무시된다")


func test_reset_groggy_gauge_clears_accumulation() -> void:
	_lord.add_groggy_ratio(0.5)
	_lord.reset_groggy_gauge()  ## 보스 페이즈 전환 시 초기화(combat.md 5-2 보스 행) 공용 API
	assert_eq(_lord.groggy_gauge, 0.0)
