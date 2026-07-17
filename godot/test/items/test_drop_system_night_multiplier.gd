## G2-4 검증 — 야간 아이템 드랍률 배율(combat.md 2-3장 ×1.15, 골드 제외·보스 제외)이
## should_drop_*() 판정에 정확히 반영되는지(결정론적 roll_01 경계값)와, DropSystem이
## 실제로 GameClock의 배율을 읽어오는지(_night_drop_multiplier 배선)를 확인한다.
## 확률 자체의 통계 검증(Monte Carlo)은 야간 배율이 없는 test_drop_system_rolls.gd에
## 이미 있으므로, 본 파일은 배율 곱셈 로직만 결정론적 경계값으로 검증한다.
extends GutTest

var _rate: DropRateConfig


func before_each() -> void:
	_rate = DropRateConfig.new()


func after_each() -> void:
	GameClock.reset()


# --- 판정 함수의 night_multiplier 파라미터 (결정론적 roll_01 경계) ---


func test_should_drop_material_boundary_shifts_with_night_multiplier() -> void:
	## material_chance_normal = 0.30 → 야간(x1.15) = 0.345
	assert_false(
		DropSystem.should_drop_material(
			_rate, DropTableData.MonsterTier.NORMAL, false, "약", 0.34, 1.0
		),
		"주간 배율(x1.0)에서는 0.34가 0.30 밖이라 드랍 실패"
	)
	assert_true(
		DropSystem.should_drop_material(
			_rate, DropTableData.MonsterTier.NORMAL, false, "약", 0.34, 1.15
		),
		"야간 배율(x1.15)에서는 0.34 < 0.345라 드랍 성공"
	)


func test_should_drop_material_default_multiplier_matches_pre_g2_4_behavior() -> void:
	## night_multiplier 인자를 생략하면 기본값 1.0 — 기존 호출부·테스트 영향 없음.
	assert_eq(
		DropSystem.should_drop_material(_rate, DropTableData.MonsterTier.NORMAL, false, "약", 0.29),
		true
	)


func test_should_drop_potion_boundary_shifts_with_night_multiplier() -> void:
	## potion_chance_normal = 0.02 → 야간(x1.15) = 0.023
	assert_false(
		DropSystem.should_drop_potion(_rate, DropTableData.MonsterTier.NORMAL, 0.0225, 1.0)
	)
	assert_true(
		DropSystem.should_drop_potion(_rate, DropTableData.MonsterTier.NORMAL, 0.0225, 1.15)
	)


func test_should_drop_equipment_grade_boundary_shifts_with_night_multiplier() -> void:
	## equip_c_chance_normal = 0.04 → 야간(x1.15) = 0.046
	assert_false(
		DropSystem.should_drop_equipment_grade(
			_rate, DropTableData.MonsterTier.NORMAL, ItemData.ItemGrade.C, 0.045, 1.0
		)
	)
	assert_true(
		DropSystem.should_drop_equipment_grade(
			_rate, DropTableData.MonsterTier.NORMAL, ItemData.ItemGrade.C, 0.045, 1.15
		)
	)


# --- DropSystem ↔ GameClock 배선 확인 (골드 제외·보스 제외) ---


func test_night_drop_multiplier_is_1_during_day() -> void:
	var drop_system := DropSystem.new()
	add_child_autofree(drop_system)
	assert_eq(drop_system._night_drop_multiplier(DropTableData.MonsterTier.NORMAL), 1.0)


func test_night_drop_multiplier_matches_night_value_for_normal_tier() -> void:
	var drop_system := DropSystem.new()
	add_child_autofree(drop_system)
	GameClock.advance_time(1200.0)  ## 밤 진입
	assert_eq(drop_system._night_drop_multiplier(DropTableData.MonsterTier.NORMAL), 1.15)


func test_night_drop_multiplier_excludes_boss_tier() -> void:
	var drop_system := DropSystem.new()
	add_child_autofree(drop_system)
	GameClock.advance_time(1200.0)  ## 밤 진입
	assert_eq(drop_system._night_drop_multiplier(DropTableData.MonsterTier.BOSS), 1.0)


func test_gold_calculation_ignores_night_state() -> void:
	## economy-foundation.md 9장·combat.md 2-3장 "골드 드랍량 x1.0" — calc_gold는 애초에
	## night_multiplier를 받지 않으므로 밤이어도 결과가 동일해야 한다.
	GameClock.advance_time(1200.0)
	var gold := DropSystem.calc_gold(10, DropTableData.MonsterTier.NORMAL, _rate)
	assert_eq(gold, roundi(2.0 * pow(10.0, 1.5)), "야간에도 골드 공식은 변하지 않는다")
