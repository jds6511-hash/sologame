## M2 HUD — UI-1 (HP/MP 바, 스킬 슬롯 쿨다운, 미니맵, 게임 내 시간, 경험치 바, 상호작용 프롬프트).
##
## `docs\art\ux\ux-foundation.md` 5장 좌표 확정분을 그대로 구현한 CanvasLayer 씬이다.
## `docs\art\PIPELINE.md` 3장 "HUD/메뉴 등 UI는 반드시 CanvasLayer 하위에 배치 — Camera2D
## 자식으로 두면 줌이 적용되어 ux-foundation의 좌표가 어긋난다" 규칙을 따른다.
##
## player.tscn·eastern_frontier_starting_area.tscn은 다른 작업(CB/MP 태스크)과 충돌 위험이
## 있어 직접 수정하지 않았다 — 이 씬을 게임 월드 씬에 자식으로 추가하고 bind_player()를
## 호출하는 것만으로 부착된다. 부착 방법과 배선 지점은 결과 보고에 상세히 남긴다(실제 배선은
## 후속 통합 작업).
class_name Hud
extends CanvasLayer

var _exp_bar_width := 0.0

@onready var _status_panel: PlayerStatusPanel = $PlayerStatusPanel
@onready var _minimap: MinimapDisplay = $Minimap
@onready var _game_time: GameTimeDisplay = $GameTimeDisplay
@onready var _skill_bar: SkillSlotBar = $SkillSlotBar
@onready var _interaction_prompt: InteractionPrompt = $InteractionPrompt
@onready var _exp_bar: Control = $ExpBar
@onready var _exp_fill: ColorRect = $ExpBar/Fill


func _ready() -> void:
	_exp_bar_width = _exp_bar.size.x


## player: player.tscn 루트(PlayerController). stats: player.tscn의 "PlayerStats" 자식
## (PlayerStatsComponent). 통합 예시: 월드 씬에 이 HUD 씬을 추가한 뒤
## `hud.bind_player(player, player.get_node("PlayerStats"))` 호출.
func bind_player(player: PlayerController, stats: PlayerStatsComponent) -> void:
	_skill_bar.bind_player(player, stats)
	_minimap.bind_player(player)
	stats.hp_changed.connect(_status_panel.set_hp)
	stats.mp_changed.connect(_status_panel.set_mp)
	_status_panel.set_hp(stats.current_hp, stats.stats.max_hp)
	_status_panel.set_mp(stats.current_mp, stats.stats.max_mp)
	_status_panel.set_level_and_job(1, "전사")  ## 레벨 시스템 미구현 — 고정값(M2 범위)


## 경험치 시스템(growth.md, M2 미구현) 연동 지점 — 구현되면 exp_changed류 시그널에
## 이 함수를 연결하면 된다. 값이 없는 지금은 0으로 둔다(J행, 자리만 확보).
func set_exp_ratio(ratio: float) -> void:
	_exp_fill.size.x = _exp_bar_width * clampf(ratio, 0.0, 1.0)


## 게임 내 시간 시스템(M2 범위 밖) 연동 지점(더미) — 구현되면 주기 호출로 교체.
func set_game_time(day_number: int, hour: int, minute: int, is_day: bool) -> void:
	_game_time.set_time(day_number, hour, minute, is_day)


## 상호작용 판정 시스템(M2 미구현) 연동 지점 — 근접 대상 판정이 생기면 이 함수를 호출.
## key_label: 안내할 입력 키(기본 F) — interaction_prompt.gd 참고.
func show_interaction_prompt(
	verb: String, world_position: Vector2, key_label: String = "F"
) -> void:
	_interaction_prompt.show_prompt(verb, world_position, key_label)


func hide_interaction_prompt() -> void:
	_interaction_prompt.hide_prompt()
