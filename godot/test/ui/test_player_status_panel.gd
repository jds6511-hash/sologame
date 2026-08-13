## UI-1 검증 — 플레이어 상태 패널(A요소)의 HP/MP 바 갱신, 잔상 감쇠, 저체력 테두리 점멸,
## 그리고 M3 정식 스프라이트 초상(28x36 시트 크롭·직업 시트 교체).
extends GutTest

const WARRIOR_FRAMES := preload("res://assets/sprites/player/player_warrior_v2_frames.tres")
const ARCHER_FRAMES := preload("res://assets/sprites/player/player_archer_frames.tres")
## STYLE_GUIDE 1-2절(2026-07-30 개정) 인간형 프레임 규격 — 초상 크롭의 상위 규격.
const HUMANOID_FRAME_SIZE := Vector2(28, 36)
## ux-foundation 5장 A행 초상 칸.
const PORTRAIT_SLOT_SIZE := Vector2(96, 96)

var _panel: PlayerStatusPanel


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/player_status_panel.tscn")
	_panel = scene.instantiate()
	add_child_autofree(_panel)


func test_set_hp_updates_fill_and_label() -> void:
	_panel.set_hp(50.0, 100.0)
	var fill: ColorRect = _panel.get_node("HPBar/Fill")
	var bar_width: float = _panel.get_node("HPBar").size.x
	var label: Label = _panel.get_node("HPBar/Label")
	assert_almost_eq(fill.size.x, bar_width * 0.5, 0.5)
	assert_eq(label.text, "50/100")


func test_set_mp_updates_fill_and_label() -> void:
	_panel.set_mp(20.0, 40.0)
	var fill: ColorRect = _panel.get_node("MPBar/Fill")
	var bar_width: float = _panel.get_node("MPBar").size.x
	var label: Label = _panel.get_node("MPBar/Label")
	assert_almost_eq(fill.size.x, bar_width * 0.5, 0.5)
	assert_eq(label.text, "20/40")


func test_low_hp_shows_border_blink() -> void:
	var border: Panel = _panel.get_node("HPBar/BorderBlink")
	_panel.set_hp(20.0, 100.0)  ## 30% 이하
	_panel._process(0.1)
	assert_true(border.visible)


func test_normal_hp_hides_border_blink() -> void:
	var border: Panel = _panel.get_node("HPBar/BorderBlink")
	_panel.set_hp(80.0, 100.0)
	_panel._process(0.1)
	assert_false(border.visible)


func test_ghost_bar_lags_behind_on_damage_then_catches_up() -> void:
	var ghost: ColorRect = _panel.get_node("HPBar/Ghost")
	var bar_width: float = _panel.get_node("HPBar").size.x
	_panel.set_hp(100.0, 100.0)
	_panel._process(0.1)  ## 잔상도 100%로 시작
	assert_almost_eq(ghost.size.x, bar_width, 0.5)

	_panel.set_hp(20.0, 100.0)  ## 급격한 데미지
	_panel._process(0.05)
	assert_true(ghost.size.x > bar_width * 0.2, "잔상은 즉시 따라가지 않고 서서히 감소해야 한다")

	for i in range(50):  ## 충분한 시간 경과 후 실제 HP를 따라잡아야 함
		_panel._process(0.1)
	assert_almost_eq(ghost.size.x, bar_width * 0.2, 0.5)


func test_set_level_and_job_updates_label() -> void:
	_panel.set_level_and_job(3, "전사")
	var label: Label = _panel.get_node("LevelJobLabel")
	assert_eq(label.text, "Lv.3 전사")


# --- M3 초상: 정식 스프라이트(28x36 시트) 크롭 ---


func _portrait_atlas() -> AtlasTexture:
	return _panel.get_node("Portrait").texture as AtlasTexture


## 시트가 실제로 28x36 규격이어야 초상 크롭(24x24)이 규격 안의 영역이라는 말이 성립한다.
func test_source_sheet_is_28x36_spec() -> void:
	var frame := WARRIOR_FRAMES.get_frame_texture(&"idle_front", 0) as AtlasTexture
	assert_not_null(frame, "정면 대기 프레임은 시트 안 AtlasTexture다")
	assert_eq(frame.region.size, HUMANOID_FRAME_SIZE, "인간형 프레임 규격 28x36")
	var crop: Rect2 = PlayerStatusPanel.PORTRAIT_CROP_RECT
	assert_true(
		Rect2(Vector2.ZERO, HUMANOID_FRAME_SIZE).encloses(crop), "초상 크롭은 프레임 28x36 안에 들어야 한다"
	)


## 씬 기본 초상은 M2 구 시트가 아니라 전사 신판 시트(28x36)를 봐야 한다.
func test_default_portrait_uses_v2_sheet() -> void:
	var atlas := _portrait_atlas()
	assert_not_null(atlas, "기본 초상이 배선돼 있어야 한다")
	assert_eq(atlas.atlas.resource_path, "res://assets/sprites/player/player_warrior_v2_idle.png")
	assert_eq(atlas.region, PlayerStatusPanel.PORTRAIT_CROP_RECT, "기본 초상도 상반신 크롭 규격")


## 초상 칸(96x96) / 크롭 변 = 정수배여야 한다(STYLE_GUIDE 1-1절 비정수 스케일 금지).
func test_portrait_scale_is_integer() -> void:
	var portrait: TextureRect = _panel.get_node("Portrait")
	assert_eq(portrait.size, PORTRAIT_SLOT_SIZE, "초상 칸은 ux 5장 A행의 96x96")
	var crop: Rect2 = PlayerStatusPanel.PORTRAIT_CROP_RECT
	var scale_x: float = PORTRAIT_SLOT_SIZE.x / crop.size.x
	assert_eq(crop.size.x, crop.size.y, "정사각 크롭이어야 칸을 letterbox 없이 채운다")
	assert_eq(scale_x, floorf(scale_x), "초상 배율이 정수가 아니다(픽셀 왜곡)")


func test_set_portrait_frames_swaps_to_archer_sheet() -> void:
	_panel.set_portrait_frames(ARCHER_FRAMES)
	var atlas := _portrait_atlas()
	assert_eq(atlas.atlas.resource_path, "res://assets/sprites/player/player_archer_idle.png")
	assert_eq(atlas.region, PlayerStatusPanel.PORTRAIT_CROP_RECT, "궁수 초상도 같은 상반신 크롭")


## 전용 시트가 없는 직업(검투사 = sprite_frames 비어 있음)은 현재 초상을 유지해야 한다.
func test_set_portrait_frames_keeps_portrait_when_frames_missing() -> void:
	_panel.set_portrait_frames(ARCHER_FRAMES)
	var before := _portrait_atlas()
	_panel.set_portrait_frames(null)
	assert_same(_portrait_atlas(), before, "시트가 없으면 초상을 바꾸지 않는다")


## 정면 대기 애니메이션이 없는 시트도 초상을 깨뜨리지 않는다(폴백 = 현행 유지).
func test_set_portrait_frames_ignores_sheet_without_idle_front() -> void:
	var before := _portrait_atlas()
	var empty := SpriteFrames.new()  ## 기본 "default" 애니메이션만 있고 idle_front는 없다
	_panel.set_portrait_frames(empty)
	assert_same(_portrait_atlas(), before, "정면 대기 프레임이 없으면 초상을 바꾸지 않는다")
