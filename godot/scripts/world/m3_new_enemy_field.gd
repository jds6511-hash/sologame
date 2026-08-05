## M3 신규 적 검증 필드 (C-10) — 밴드가 시작 지역(노베라 들녘 Lv1~12)을 넘는 신규 적 5종을
## 밴드별 구역으로 나눠 배치한 전용 무대다.
##
## 왜 별도 씬인가: `world-structure.md` 2장 밴드 표대로면 신규 7종 중 시작 지역에 배치할 수
## 있는 것은 **숲거미 계열(Lv10, 밴드 8~16 하단)뿐**이다. 무법자(Lv14)·노상강도(Lv20)·
## 밀렵꾼(Lv36)·임프(Lv16)·포효 임프장(Lv16 정예)의 정식 서식 권역(동부 가도·중부 왕국 대로·
## 서부 수림길·균열 외곽)은 아직 씬이 없으므로, 이들을 Lv1~12 맵에 섞지 않고(즉사 방지)
## 이 검증 필드에 모아 행동 블록·무리 규칙·드랍·경험치 배선을 확인한다. 정식 배치 좌표
## 규격은 `docs\design\levels\m3-new-enemy-placement.md` 4장에 확정해 두었고, 해당 지역
## 씬이 만들어지면 그 규격대로 옮기고 이 필드는 폐기한다.
##
## 구역 배치 (한 구역 16×15타일, 3열 × 2행 — 구역 간 16타일 간격 > 최대 인지 범위 7타일이라
## 구역끼리 어그로가 새지 않는다):
##   [A1] 동부 들녘 숲 Lv8~16   [A2] 동부 가도 Lv10~18    [A3] 중부 왕국 대로 Lv18~24
##        숲거미 3(개별)              무법자 2~3(무리)          노상강도 3~4(무리)
##        + 그림자 숲거미 2(야간)
##   [B1] 서부 수림길 Lv33~39   [B2] 균열 외곽 Lv12~20    [B3] 균열 포인트(정예)
##        밀렵꾼 1~2(원거리)          임프 2~4(무리)            임프장 1 + 임프 2~3
##
## 배선은 시작 지역 씬(eastern_frontier_starting_area.gd)과 동일하다 — MonsterSpawner가
## 스폰하고, MonsterDropRegistry로 종별 드랍 테이블을 찾아 DropSystem(드랍)·
## PlayerProgression(처치 경험치)에 함께 등록한다.
##
## 스크린샷 캡처 모드: `godot --path godot res://scenes/world/m3_new_enemy_field.tscn -- --capture`
## 로 실행하면 아래 CAPTURE_STEPS 순서대로 플레이어를 각 구역에 세우고 교전 장면을
## `docs\qa\screenshots\`에 PNG로 저장한 뒤 종료한다(검증 재현용 — 일반 실행에는 영향 없음).
##
## 재스폰 캡처 모드: 같은 방식으로 `-- --capture-respawn`을 주면 무법자 무리를 전멸시킨 뒤
## 쿨다운을 빨리 감아(`MonsterSpawner.advance_respawn_tick`) 무리가 돌아오는 것을 3장으로
## 남긴다(D-3 검증 재현용 — 실시간으로는 쿨다운 30초를 기다려야 하기 때문이다).
class_name M3NewEnemyField
extends Node2D

const CAPTURE_FLAG := "--capture"
const RESPAWN_CAPTURE_FLAG := "--capture-respawn"
const CAPTURE_DIR := "res://../docs/qa/screenshots/"
## [경과 초, 플레이어를 세울 위치, 저장 파일명(빈 문자열이면 이동만)]
const CAPTURE_STEPS: Array = [
	[1.0, Vector2(368, 120), ""],
	[3.4, Vector2(368, 120), "C10_01_무법자_무리_교전.png"],
	[4.4, Vector2(168, 136), ""],
	[7.0, Vector2(168, 136), "C10_02_숲거미_도약_거미줄.png"],
	[8.0, Vector2(620, 376), ""],
	[11.6, Vector2(620, 376), "C10_03_포효임프장_정예_무리.png"],
	[12.6, Vector2(664, 128), ""],
	[16.0, Vector2(664, 128), "C10_04_노상강도_무리_돌진.png"],
]

## 재스폰 캡처 단계 — [경과 초, 플레이어 위치(INF면 이동 없음), 동작, 저장 파일명]
## 동작: ""=없음 / "kill"=전 몬스터 즉사 / "fastforward"=재스폰 쿨다운 빨리 감기
## 위치 이동과 촬영을 같은 단계에 두면 Camera2D가 아직 따라오지 않아 빈 화면이 찍힌다 —
## 이동 단계와 촬영 단계를 1초 이상 떼어 놓는다(기존 CAPTURE_STEPS와 같은 이유).
const RESPAWN_CAPTURE_STEPS: Array = [
	[0.8, Vector2(400, 120), "", ""],
	[2.2, Vector2.INF, "", "D03_01_재스폰_전_무법자_무리.png"],
	[2.4, Vector2.INF, "kill", ""],
	[3.8, Vector2.INF, "", "D03_02_전멸_직후_무리_없음.png"],
	## 거리 게이트(무법자 인지 6타일 + 1타일) 밖으로 물러나야 재스폰이 진행된다.
	[4.0, Vector2(900, 560), "fastforward", ""],
	[5.2, Vector2(400, 120), "", ""],
	[6.6, Vector2.INF, "", "D03_03_재스폰_후_무법자_무리_복귀.png"],
]
## 정예 캠프 쿨다운 180초 + 마커 수만큼의 틱을 넉넉히 덮는 빨리 감기 횟수.
const RESPAWN_FASTFORWARD_TICKS := 220

var _capture_mode: bool = false
var _respawn_capture_mode: bool = false
var _capture_elapsed: float = 0.0
var _capture_index: int = 0

@onready var _player: PlayerController = $Player
@onready var _progression: PlayerProgression = $Player/PlayerProgression
@onready var _inventory: InventoryComponent = $Player/Inventory
@onready var _drop_system: DropSystem = $DropSystem
@onready var _monster_spawner: MonsterSpawner = $MonsterSpawner
@onready var _hud: Hud = $Hud
@onready var _info_label: Label = $InfoLayer/InfoLabel


func _ready() -> void:
	_hud.bind_player(_player, _player.get_node("PlayerStats"))
	## unbind(1) 이유는 eastern_frontier_starting_area.gd 동일 배선 주석 참조.
	_drop_system.gold_dropped.connect(_inventory.add_gold.unbind(1))
	_monster_spawner.monster_spawned.connect(_register_monster)
	for monster in _monster_spawner.get_children():
		_register_monster(monster)
	var user_args := OS.get_cmdline_user_args()
	_capture_mode = user_args.has(CAPTURE_FLAG)
	_respawn_capture_mode = user_args.has(RESPAWN_CAPTURE_FLAG)
	## 검증 필드 BGM — 매핑상 일반 전투 곡을 그대로 쓴다(bgm-lyria-prompts 1-1 판단 사항 2).
	BgmManager.play_for_scene(scene_file_path)
	BgmManager.bind_job_transition(_player.get_node_or_null("PlayerJobTransition"))


func _process(delta: float) -> void:
	if _capture_mode:
		_advance_capture(delta)
	elif _respawn_capture_mode:
		_advance_respawn_capture(delta)
	_info_label.text = (
		"[C-10 신규 적 검증 필드] 상단: 숲거미(Lv10) · 무법자(Lv14) · 노상강도(Lv20)\n"
		+ "하단: 밀렵꾼(Lv36) · 임프(Lv16) · 포효 임프장(Lv16 정예 + 호위 임프)\n"
		+ (
			"그림자 숲거미(야간 전용)는 밤에만 상단 좌측에 출현 — 현재 %s · 몬스터 %d마리 · FPS %d"
			% [
				"밤" if not GameClock.is_day else "낮",
				_monster_spawner.get_child_count(),
				Engine.get_frames_per_second(),
			]
		)
	)


## 시작 지역 씬과 동일한 배선 — 드랍 테이블 1개로 드랍·처치 경험치를 함께 등록한다.
func _register_monster(monster: Node) -> void:
	BgmManager.register_monster(monster)  ## 포효 임프장(정예) 교전 시 전투 곡 전환
	var drop_table := MonsterDropRegistry.table_for(monster)
	if drop_table == null:
		return
	_drop_system.register_monster(monster, drop_table)
	_progression.register_monster(monster, drop_table)


# --- 스크린샷 캡처 모드 (헤더 참고 — 검증 재현용) ---


func _advance_capture(delta: float) -> void:
	_capture_elapsed += delta
	while _capture_index < CAPTURE_STEPS.size():
		var step: Array = CAPTURE_STEPS[_capture_index]
		if _capture_elapsed < float(step[0]):
			return
		_capture_index += 1
		_player.global_position = step[1]
		_player.velocity = Vector2.ZERO
		var file_name: String = step[2]
		if not file_name.is_empty():
			_save_screenshot(file_name)
	get_tree().quit()


## 재스폰 캡처 — 전멸 → 쿨다운 빨리 감기 → 복귀를 3장으로 남긴다(D-3 검증 재현용).
func _advance_respawn_capture(delta: float) -> void:
	_capture_elapsed += delta
	while _capture_index < RESPAWN_CAPTURE_STEPS.size():
		var step: Array = RESPAWN_CAPTURE_STEPS[_capture_index]
		if _capture_elapsed < float(step[0]):
			return
		_capture_index += 1
		var move_to: Vector2 = step[1]
		if move_to.is_finite():
			_player.global_position = move_to
			_player.velocity = Vector2.ZERO
		match String(step[2]):
			"kill":
				_kill_all_monsters()
			"fastforward":
				var started_usec := Time.get_ticks_usec()
				for _i in RESPAWN_FASTFORWARD_TICKS:
					_monster_spawner.advance_respawn_tick(MonsterSpawner.RESPAWN_TICK_SEC)
				## 실제 게임은 초당 1틱이므로 이 수치는 "전 마커 동시 재스폰"의 최악값이다.
				print(
					(
						"[D-3 캡처] 재스폰 %d틱 일괄 처리 %.2f ms · 몬스터 %d마리 · FPS %d"
						% [
							RESPAWN_FASTFORWARD_TICKS,
							(Time.get_ticks_usec() - started_usec) / 1000.0,
							_monster_spawner.get_child_count(),
							Engine.get_frames_per_second(),
						]
					)
				)
		var file_name: String = step[3]
		if not file_name.is_empty():
			_save_screenshot(file_name)
	get_tree().quit()


func _kill_all_monsters() -> void:
	for child in _monster_spawner.get_children():
		var monster := child as MonsterBase
		if monster != null and not monster.is_dead():
			monster.take_damage(999999.0, "강")


func _save_screenshot(file_name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(CAPTURE_DIR) + file_name
	var error := image.save_png(path)
	print("[C-10 캡처] %s (%s)" % [path, "성공" if error == OK else "실패 %d" % error])
	_print_nearby_monsters()


## 캡처 시점의 화면 내 몬스터 목록 — 스크린샷과 함께 남기는 검증 로그.
func _print_nearby_monsters() -> void:
	var lines: Array[String] = []
	for child in _monster_spawner.get_children():
		var monster := child as MonsterBase
		if monster == null:
			continue
		var distance := monster.global_position.distance_to(_player.global_position) / 16.0
		if distance > 12.0:
			continue
		lines.append(
			(
				"%s(HP %.0f/%.0f, %.1f타일)"
				% [monster.stats.display_name, monster.hp, monster.effective_max_hp(), distance]
			)
		)
	print(
		(
			"   화면 내 몬스터 %d: %s / 플레이어 HP %.0f"
			% [lines.size(), ", ".join(lines), _player.get_node("PlayerStats").current_hp]
		)
	)
