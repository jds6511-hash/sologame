## HUD F요소 — 스킬 슬롯 1칸 (아이콘 + 키 라벨 + 쿨다운 원형 오버레이).
##
## `docs\art\ux\ux-foundation.md` 5장 F행: "각 칸: 스킬 아이콘 + 키 라벨(좌상, 보조 27px) +
## 쿨다운(어두운 원형 오버레이 + 남은 초, 본문 33px). MP 부족 시 아이콘 청색 반투명 처리.
## R(궁극기) 칸은 테두리 강조. 퀵슬롯(5,6)은 소비 아이템 아이콘+보유 수량." (2026-07-18
## 1920x1080 재기준)
class_name SkillSlot
extends Panel

@onready var _icon: TextureRect = $Icon
@onready var _key_label: Label = $KeyLabel
@onready var _cooldown_overlay: TextureProgressBar = $CooldownOverlay
@onready var _cooldown_label: Label = $CooldownLabel
@onready var _mp_block: ColorRect = $MpBlock
@onready var _ultimate_border: Panel = $UltimateBorder
@onready var _quantity_label: Label = $QuantityLabel


func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.make_panel_stylebox())
	UiStyle.apply_label_font(_key_label)
	UiStyle.apply_body_font(_cooldown_label)
	UiStyle.apply_label_font(_quantity_label)
	_key_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	_cooldown_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT)
	_quantity_label.add_theme_color_override("font_color", UiStyle.COLOR_TEXT_SUB)

	_cooldown_overlay.texture_progress = load(UiStyle.COOLDOWN_RADIAL_MASK_PATH)
	_cooldown_overlay.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	_cooldown_overlay.tint_progress = Color(UiStyle.COLOR_OUTLINE, 0.75)
	_cooldown_overlay.min_value = 0.0
	_cooldown_overlay.max_value = 100.0
	_cooldown_overlay.value = 0.0

	_mp_block.color = Color(UiStyle.COLOR_MP, 0.45)
	var ultimate_border_box := StyleBoxFlat.new()
	ultimate_border_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ultimate_border_box.set_border_width_all(2)
	ultimate_border_box.border_color = UiStyle.COLOR_EXP
	ultimate_border_box.set_corner_radius_all(2)
	_ultimate_border.add_theme_stylebox_override("panel", ultimate_border_box)

	_cooldown_label.visible = false
	_mp_block.visible = false
	_ultimate_border.visible = false
	_quantity_label.visible = false


## icon: 슬롯 아이콘(null이면 빈 칸). key_label_text: 좌상단에 표시할 키(예: "1", "Q", "R").
## is_ultimate: R 슬롯 여부(테두리 강조, ux 5장 F행).
func configure(icon: Texture2D, key_label_text: String, is_ultimate: bool = false) -> void:
	_icon.texture = icon
	_key_label.text = key_label_text
	_ultimate_border.visible = is_ultimate


## remaining_sec: 남은 쿨다운(초). total_sec: 스킬의 전체 쿨다운(초, 0 이하면 오버레이 숨김).
func set_cooldown(remaining_sec: float, total_sec: float) -> void:
	if total_sec <= 0.0 or remaining_sec <= 0.0:
		_cooldown_overlay.value = 0.0
		_cooldown_label.visible = false
		return
	_cooldown_overlay.value = (remaining_sec / total_sec) * 100.0
	_cooldown_label.text = str(ceili(remaining_sec))
	_cooldown_label.visible = true


## MP 부족 시 아이콘 위에 청색 반투명 오버레이(ux 5장 F행 "MP 부족 시 아이콘 청색 반투명 처리").
func set_mp_insufficient(is_insufficient: bool) -> void:
	_mp_block.visible = is_insufficient


## 미개방 슬롯 표시 — 칸 전체를 어둡게 낮춘다(전직 전 4/Q/E/R 슬롯). 호출자가 아이콘도 함께
## 비우므로 "어두움 + 아이콘 없음"의 이중 신호가 되어 색만으로 상태를 구분하지 않는다(ux 1장).
func set_locked(is_locked: bool) -> void:
	modulate.a = 0.35 if is_locked else 1.0


## 퀵슬롯(포션 등) 보유 수량 표시. quantity < 0이면 라벨을 숨긴다 — 인벤토리 시스템(IT-3)
## 연동 전에는 수량 정보 자체가 없으므로 기본은 숨김 상태다.
func set_quantity(quantity: int) -> void:
	if quantity < 0:
		_quantity_label.visible = false
		return
	_quantity_label.text = "x%d" % quantity
	_quantity_label.visible = true
