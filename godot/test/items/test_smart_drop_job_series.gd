## 스마트 드랍 직업 연동 검증 (jobs.md 5-2장 · economy-foundation.md 3-5장).
##
## M2 유산으로 무기 계열이 "WPN-GS-"(대검) 고정이던 문제를 직업 조회로 대체한 뒤,
## ① 직업 id -> 계열 프리픽스 매핑이 실제 .tres 데이터대로인지 ② 전직으로 계열이 바뀌는지
## ③ 각 직업이 자기 계열 무기를 실제로 드랍 후보로 얻는지(모험가 소검·전사 대검·궁수 활)를
## 실제 data/items/*.tres 전체를 후보로 두고 확인한다.
extends GutTest

const RATE_CONFIG_PATH := "res://data/items/drop_rate_config.tres"
const ARCHER_JOB_PATH := "res://data/jobs/job_def_archer.tres"
const WARRIOR_JOB_PATH := "res://data/jobs/job_def_warrior.tres"
const ITEMS_DIR := "res://data/items"

var _rate: DropRateConfig
var _items: Array[ItemData]


func before_all() -> void:
	_rate = load(RATE_CONFIG_PATH)
	_items = _load_all_items()


# --- 직업 -> 무기 계열 매핑 (DropRateConfig 데이터) ---


func test_config_maps_each_job_to_its_weapon_series() -> void:
	assert_eq(_rate.weapon_series_prefix_for_job(&"adventurer"), "WPN-SW-", "모험가 = 소검")
	assert_eq(_rate.weapon_series_prefix_for_job(&"warrior"), "WPN-GS-", "전사 = 대검")
	assert_eq(_rate.weapon_series_prefix_for_job(&"archer"), "WPN-BW-", "궁수 = 활")


func test_config_falls_back_to_short_sword_for_unknown_job() -> void:
	assert_eq(_rate.weapon_series_prefix_for_job(&"unknown_job"), "WPN-SW-")


# --- DropSystem의 현재 직업 조회 ---


func test_drop_system_uses_adventurer_series_without_job_transition() -> void:
	var drop_system := DropSystem.new()
	drop_system.rate_config = _rate
	autofree(drop_system)
	assert_eq(drop_system.current_weapon_series_prefix(), "WPN-SW-", "미전직 = 모험가 소검")


func test_drop_system_series_follows_current_job_id() -> void:
	var transition := PlayerJobTransition.new()
	autofree(transition)
	var drop_system := DropSystem.new()
	drop_system.rate_config = _rate
	drop_system.job_transition = transition
	autofree(drop_system)

	transition.current_job_id = &"warrior"
	assert_eq(drop_system.current_weapon_series_prefix(), "WPN-GS-")
	transition.current_job_id = &"archer"
	assert_eq(drop_system.current_weapon_series_prefix(), "WPN-BW-", "전직 후 계열이 바뀌어야 함")


func test_drop_system_finds_job_transition_in_subtree() -> void:
	var root := Node.new()
	var player := Node.new()
	var transition := PlayerJobTransition.new()
	player.add_child(transition)
	root.add_child(player)
	add_child_autofree(root)

	assert_eq(DropSystem._find_job_transition(root), transition)


func test_series_follows_real_transition_to_archer() -> void:
	var transition := PlayerJobTransition.new()
	transition.available_jobs = [load(WARRIOR_JOB_PATH), load(ARCHER_JOB_PATH)]
	transition.transition_available = true
	var parent := Node.new()
	parent.add_child(transition)
	add_child_autofree(parent)
	var drop_system := DropSystem.new()
	drop_system.rate_config = _rate
	drop_system.job_transition = transition
	autofree(drop_system)

	assert_eq(drop_system.current_weapon_series_prefix(), "WPN-SW-", "전직 전에는 모험가 소검")
	assert_true(transition.perform_transition(&"archer"), "Lv10 전직 가능 상태에서 궁수 전직 성공")
	assert_eq(drop_system.current_weapon_series_prefix(), "WPN-BW-", "궁수 전직 후 활 계열")


# --- 실제 아이템 데이터로 계열별 드랍 후보 해석 ---


func test_adventurer_drops_short_sword() -> void:
	var picked := _resolve_weapon(8, ItemData.ItemGrade.C, "WPN-SW-")
	assert_not_null(picked, "모험가 구간(Lv1~9)에 소검 C급 후보가 있어야 함")
	assert_eq(picked.item_id, "WPN-SW-01-C")
	assert_eq(_resolve_weapon(8, ItemData.ItemGrade.B, "WPN-SW-").item_id, "WPN-SW-01-B")


func test_warrior_drops_great_sword() -> void:
	assert_eq(_resolve_weapon(14, ItemData.ItemGrade.C, "WPN-GS-").item_id, "WPN-GS-10-C")
	assert_eq(_resolve_weapon(20, ItemData.ItemGrade.B, "WPN-GS-").item_id, "WPN-GS-20-B")


func test_archer_drops_bow() -> void:
	var picked := _resolve_weapon(14, ItemData.ItemGrade.C, "WPN-BW-")
	assert_not_null(picked, "궁수 전직 후 활 드랍 후보가 있어야 함(공백 1 재발 방지)")
	assert_eq(picked.item_id, "WPN-BW-10-C")
	assert_eq(_resolve_weapon(20, ItemData.ItemGrade.B, "WPN-BW-").item_id, "WPN-BW-20-B")
	assert_eq(_resolve_weapon(36, ItemData.ItemGrade.C, "WPN-BW-").item_id, "WPN-BW-30-C")


func test_other_series_never_drops_for_current_job() -> void:
	## 스마트 드랍 규칙: 궁수에게 대검·소검이 뜨면 안 된다.
	for level in [8, 14, 20, 36]:
		var picked := _resolve_weapon(level, ItemData.ItemGrade.C, "WPN-BW-")
		if picked != null:
			assert_true(picked.item_id.begins_with("WPN-BW-"), "궁수는 활만: %s" % picked.item_id)


func _resolve_weapon(monster_level: int, grade: ItemData.ItemGrade, prefix: String) -> ItemData:
	return DropSystem.resolve_equipment_item(
		_items, monster_level, grade, ItemData.EquipSlot.WEAPON, prefix
	)


func _load_all_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	var dir := DirAccess.open(ITEMS_DIR)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: Resource = load("%s/%s" % [ITEMS_DIR, file_name])
			if res is ItemData:
				items.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return items
