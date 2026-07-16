## CB-4 검증 — 몬스터(잡몹) 피격 경직 규칙(combat.md 5-2장) 재현.
## 일반 타격 0.15초 / 강타·치명타 0.25초 경직, 연속 경직 3회 후 1.5초 슈퍼아머,
## 슈퍼아머 중에는 경직이 걸리지 않고 종료 후 연속 횟수가 초기화됨을 확인한다.
extends GutTest

var _component: MobStaggerComponent


func before_each() -> void:
	_component = MobStaggerComponent.new()
	_component.rules = load("res://data/combat/mob_stagger_rules.tres")
	add_child_autofree(_component)


func test_light_hit_staggers_for_0_15_sec() -> void:
	var result := _component.register_hit(false)
	assert_true(result["staggered"])
	assert_false(result["superarmor"])
	assert_true(_component.is_staggered())
	_component.advance_time(0.14)
	assert_true(_component.is_staggered(), "0.15초 전에는 아직 경직 중")
	_component.advance_time(0.02)
	assert_false(_component.is_staggered(), "0.15초 경과 후 경직 종료")


func test_heavy_hit_staggers_for_0_25_sec() -> void:
	_component.register_hit(true)
	_component.advance_time(0.24)
	assert_true(_component.is_staggered())
	_component.advance_time(0.02)
	assert_false(_component.is_staggered())


func test_third_consecutive_stagger_triggers_superarmor_after_it_ends() -> void:
	_component.register_hit(false)
	_component.advance_time(0.15)
	_component.register_hit(false)
	_component.advance_time(0.15)
	var result := _component.register_hit(false)
	assert_true(result["staggered"], "3번째도 정상적으로 경직은 발생한다")

	_component.advance_time(0.15)  ## 3번째 경직 종료 시점
	assert_true(_component.is_superarmor(), "연속 경직 3회 후 슈퍼아머로 전환")
	assert_false(_component.is_staggered())


func test_hit_during_superarmor_is_ignored() -> void:
	_component.register_hit(false)
	_component.advance_time(0.15)
	_component.register_hit(false)
	_component.advance_time(0.15)
	_component.register_hit(false)
	_component.advance_time(0.15)  ## 슈퍼아머 진입

	var result := _component.register_hit(true)
	assert_false(result["staggered"], "슈퍼아머 중에는 경직 무시")
	assert_true(result["superarmor"])


func test_superarmor_lasts_1_5_sec_then_resets_chain() -> void:
	_component.register_hit(false)
	_component.advance_time(0.15)
	_component.register_hit(false)
	_component.advance_time(0.15)
	_component.register_hit(false)
	_component.advance_time(0.15)  ## 슈퍼아머 진입

	_component.advance_time(1.49)
	assert_true(_component.is_superarmor(), "1.5초 전에는 아직 슈퍼아머")
	_component.advance_time(0.02)
	assert_false(_component.is_superarmor(), "1.5초 경과 후 슈퍼아머 종료")

	## 슈퍼아머 종료 후 연속 횟수가 초기화되어 다시 경직이 걸려야 한다
	var result := _component.register_hit(false)
	assert_true(result["staggered"], "슈퍼아머 종료 후 연속 횟수 초기화 확인")
