## M3 3-A 검증 — HUD 초상의 직업별 스프라이트 시트 교체.
##
## 초상 시트는 JobDefinition.sprite_frames(gameplay-dev 배선)가 유일한 출처이고 HUD는
## PlayerJobTransition.job_changed를 구독해 따라간다. 여기서는 그 경로를 **실제 전직 API로**
## 태워 검증한다 — 레벨은 PlayerProgression에 실제 경험치를 넣어 올리므로 전직 가능 판정부터
## 시트 교체까지 게임과 같은 순서로 일어난다.
##
## 크롭 규격(28x36 시트에서 24x24 상반신)·폴백 자체의 단위 검증은
## `test_player_status_panel.gd` 참고.
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
## available_jobs 순서(player.tscn) — 0=전사, 1=궁수.
const WARRIOR_INDEX := 0
const ARCHER_INDEX := 1
## 2차 후보(전사의 상위 계통)는 검투사 1종뿐이라 카드 번호는 항상 1번(index 0)이다.
const GLADIATOR_INDEX := 0
const TIER2_LEVEL := 40

const WARRIOR_SHEET := "res://assets/sprites/player/player_warrior_v2_idle.png"
const ARCHER_SHEET := "res://assets/sprites/player/player_archer_idle.png"

var _hud: Hud
var _player: PlayerController
var _progression: PlayerProgression
var _transition: PlayerJobTransition


func before_each() -> void:
	GameClock.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_progression = _player.get_node("PlayerProgression")
	_transition = _player.get_node("PlayerJobTransition")
	_hud = load("res://scenes/ui/hud.tscn").instantiate()
	add_child_autofree(_hud)
	_hud.bind_player(_player, _player.get_node("PlayerStats"))


func after_each() -> void:
	GameClock.reset()


func _portrait_sheet_path() -> String:
	var portrait: TextureRect = _hud.get_node("PlayerStatusPanel/Portrait")
	var atlas := portrait.texture as AtlasTexture
	assert_not_null(atlas, "초상은 시트 크롭 AtlasTexture여야 한다")
	return atlas.atlas.resource_path


## 인게임 플레이어 스프라이트가 지금 쓰는 시트 — 초상은 항상 이것과 같아야 한다.
func _world_sheet_path() -> String:
	var sprite: AnimatedSprite2D = _player.get_node("Sprite")
	var frame := sprite.sprite_frames.get_frame_texture(&"idle_front", 0) as AtlasTexture
	return frame.atlas.resource_path


func _level_up_to(level: int) -> void:
	while _progression.current_level < level:
		_progression.add_exp(_progression.exp_to_next())


func _transition_to(index: int) -> void:
	_level_up_to(10)
	assert_true(_transition.request_transition_by_index(index), "전직이 실행돼야 한다")


## 모험가는 전용 시트가 없다 — 씬 기본값(전사 신판 시트)이 그대로 남고, 그것이 화면의 플레이어
## 스프라이트(player.tscn 기본 시트)와 같아야 폴백이 맞은 것이다.
func test_adventurer_portrait_matches_world_sprite() -> void:
	assert_eq(_transition.current_job_id, &"adventurer", "시작은 미전직(모험가)")
	assert_eq(_portrait_sheet_path(), WARRIOR_SHEET)
	assert_eq(_portrait_sheet_path(), _world_sheet_path(), "초상과 인게임 스프라이트가 같은 시트")


func test_warrior_transition_keeps_warrior_portrait() -> void:
	_transition_to(WARRIOR_INDEX)
	assert_eq(_portrait_sheet_path(), WARRIOR_SHEET)
	assert_eq(_portrait_sheet_path(), _world_sheet_path())


func test_archer_transition_swaps_portrait() -> void:
	_transition_to(ARCHER_INDEX)
	assert_eq(_portrait_sheet_path(), ARCHER_SHEET, "궁수로 전직하면 초상도 궁수 시트")
	assert_eq(_portrait_sheet_path(), _world_sheet_path())


## 초상 크롭 규격은 시트를 바꿔도 유지된다(직업마다 크롭이 흔들리면 얼굴 위치가 튄다).
func test_portrait_crop_is_stable_across_jobs() -> void:
	_transition_to(ARCHER_INDEX)
	var portrait: TextureRect = _hud.get_node("PlayerStatusPanel/Portrait")
	var atlas := portrait.texture as AtlasTexture
	assert_eq(atlas.region, PlayerStatusPanel.PORTRAIT_CROP_RECT)


## 검투사(2차)는 sprite_frames가 비어 있다 = "전사 시트 유지"가 데이터로 표현된 상태.
func test_gladiator_transition_keeps_warrior_portrait() -> void:
	_transition_to(WARRIOR_INDEX)
	_level_up_to(TIER2_LEVEL)
	assert_true(_transition.request_transition_by_index(GLADIATOR_INDEX), "2차 전직이 실행돼야 한다")
	assert_eq(_transition.current_job_id, &"gladiator")
	assert_eq(_portrait_sheet_path(), WARRIOR_SHEET, "전용 시트가 없으면 전사 초상 유지")
	assert_eq(_portrait_sheet_path(), _world_sheet_path())
