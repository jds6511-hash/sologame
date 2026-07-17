## UI-1 검증 — 스킬 슬롯(SkillSlot) 쿨다운 오버레이·MP 부족 표시·궁극기 테두리 재현.
extends GutTest

var _slot: SkillSlot


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/skill_slot.tscn")
	_slot = scene.instantiate()
	add_child_autofree(_slot)


func test_set_cooldown_shows_overlay_and_remaining_seconds() -> void:
	_slot.set_cooldown(3.2, 5.0)
	var overlay: TextureProgressBar = _slot.get_node("CooldownOverlay")
	var label: Label = _slot.get_node("CooldownLabel")
	assert_almost_eq(overlay.value, (3.2 / 5.0) * 100.0, 0.01)
	assert_true(label.visible)
	assert_eq(label.text, "4")  ## ceili(3.2) == 4


func test_set_cooldown_zero_hides_overlay() -> void:
	_slot.set_cooldown(3.0, 5.0)
	_slot.set_cooldown(0.0, 5.0)
	var overlay: TextureProgressBar = _slot.get_node("CooldownOverlay")
	var label: Label = _slot.get_node("CooldownLabel")
	assert_eq(overlay.value, 0.0)
	assert_false(label.visible)


func test_set_mp_insufficient_toggles_block_overlay() -> void:
	var mp_block: ColorRect = _slot.get_node("MpBlock")
	assert_false(mp_block.visible)
	_slot.set_mp_insufficient(true)
	assert_true(mp_block.visible)
	_slot.set_mp_insufficient(false)
	assert_false(mp_block.visible)


func test_configure_ultimate_shows_border() -> void:
	_slot.configure(null, "R", true)
	var border: Panel = _slot.get_node("UltimateBorder")
	assert_true(border.visible)
	var key_label: Label = _slot.get_node("KeyLabel")
	assert_eq(key_label.text, "R")


func test_configure_non_ultimate_hides_border() -> void:
	_slot.configure(null, "1", false)
	var border: Panel = _slot.get_node("UltimateBorder")
	assert_false(border.visible)


func test_set_quantity_negative_hides_label() -> void:
	_slot.set_quantity(-1)
	var quantity_label: Label = _slot.get_node("QuantityLabel")
	assert_false(quantity_label.visible)


func test_set_quantity_shows_count() -> void:
	_slot.set_quantity(5)
	var quantity_label: Label = _slot.get_node("QuantityLabel")
	assert_true(quantity_label.visible)
	assert_eq(quantity_label.text, "x5")
