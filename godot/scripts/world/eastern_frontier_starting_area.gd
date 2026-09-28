class_name EasternFrontierStartingArea
extends Node2D

## 주야간 CanvasModulate 색조 — `docs\art\STYLE_GUIDE.md` 5-1장 확정값 그대로(EDG32 팔레트
## 내 색상). CanvasModulate는 같은 캔버스의 Node2D 하위 트리에만 적용되고 Hud/IntegratedMenu/
## OnboardingHintBar(전부 CanvasLayer)는 별도 레이어라 영향받지 않는다.
const DAY_COLOR := Color("ffffff")
const NIGHT_COLOR := Color("6d7ab5")
## 전환 페이드 길이(현실 초). STYLE_GUIDE 5-1의 "게임 시간 1시간 분량 선형 보간"(황혼·새벽
## 중간색 경유)은 M2 범위 밖 — 이번에는 낮/밤 대표색 사이를 수 초간 직선 보간하는 단순
## 페이드만 구현한다(G2-4 요구 "전환 페이드(수 초)").
const DAY_NIGHT_FADE_SEC := 3.0
const SaveSessionScript = preload("res://scripts/save/save_session.gd")
const SaveMenuScript = preload("res://scripts/save/save_menu.gd")
const JournalScript = preload("res://scripts/quests/quest_journal.gd")
const ControllerScript = preload("res://scripts/quests/quest_controller.gd")
const DialogScript = preload("res://scripts/ui/quest_dialog.gd")
const TrackerScript = preload("res://scripts/ui/quest_tracker.gd")
const NpcRegistry = preload("res://scripts/npc/npc_registry.gd")

@onready var _player: PlayerController = $Player
## Inventory의 combat_stats는 의도적으로 비배선이다(골드만 사용). M3에서는 성장 계층
## (PlayerStatGrowth)이 전투 스탯의 단독 권위이며, 장착 보너스를 같은 CombatantStats에
## 얹으면 이중 계산·스테일 base 문제가 생긴다 — docs\design\systems\m3-gear-growth-wiring.md
@onready var _inventory: InventoryComponent = $Player/Inventory
@onready var _progression: PlayerProgression = $Player/PlayerProgression
@onready var _drop_system: DropSystem = $DropSystem
@onready var _monster_spawner: MonsterSpawner = $MonsterSpawner
@onready var _hud: Hud = $Hud
@onready var _integrated_menu: IntegratedMenu = $IntegratedMenu
@onready var _onboarding_hint_bar: OnboardingHintBar = $OnboardingHintBar
@onready var _tutorial: TutorialController = $TutorialController
@onready var _day_night_modulate: CanvasModulate = $DayNightModulate


func _ready() -> void:
	var save_session = _create_save_session()
	save_session.name = "SaveSession"
	add_child(save_session)
	var journal := JournalScript.new(save_session.codec.schema.quest_catalog)
	_player.set_meta("quest_journal", journal)
	set_meta("save_boot_error", save_session.setup(self))
	if has_meta("save_boot") and not String(get_meta("save_boot_error")).is_empty():
		return
	if journal.export_state().is_empty():
		journal.accept("MQ-01-01")
	var quests := ControllerScript.new()
	quests.name = "QuestController"
	add_child(quests)
	quests.setup(_player, journal)
	_hud.bind_player(_player, _player.get_node("PlayerStats"))
	_integrated_menu.bind_player(_player)
	print("[통합] HUD 바인딩 완료")
	## gold_dropped는 (amount, world_position) 2인자이고 add_gold는 amount만 받으므로
	## unbind(1)로 위치 인자를 떼어 낸다 — 없으면 처치마다 인자 수 불일치 에러가 나고
	## 골드가 인벤토리에 들어가지 않는다.
	_drop_system.gold_dropped.connect(_inventory.add_gold.unbind(1))
	_monster_spawner.monster_spawned.connect(_on_monster_spawned)
	_setup_quest_ui(quests)
	_monster_spawner.rabbit_spawn_source_id = "yeoulmok_rabbit_habitat"
	_monster_spawner.wolf_spawn_source_id = "yeoulmok_dog_habitat"
	_monster_spawner.start()
	_start_tutorial()
	_init_day_night_modulate()
	_init_bgm()
	var save_menu := SaveMenuScript.new()
	save_menu.name = "SaveMenu"
	add_child(save_menu)
	save_menu.setup(save_session)


func _create_save_session() -> Node:
	return SaveSessionScript.new()


# --- 주야간 시각 연출 (G2-4) ---


func _init_day_night_modulate() -> void:
	_day_night_modulate.color = DAY_COLOR if GameClock.is_day else NIGHT_COLOR
	GameClock.night_started.connect(_on_night_started)
	GameClock.day_started.connect(_on_day_started)


func _on_night_started(_day_number: int) -> void:
	print("[G2-4] 밤 시작 (%d일차) — 야간 몬스터 강화 x1.2·드랍률 x1.15 적용" % _day_number)
	_fade_day_night_modulate(NIGHT_COLOR)


func _on_day_started(_day_number: int) -> void:
	print("[G2-4] 낮 시작 (%d일차) — 야간 배율 해제" % _day_number)
	_fade_day_night_modulate(DAY_COLOR)


func _fade_day_night_modulate(target_color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(_day_night_modulate, "color", target_color, DAY_NIGHT_FADE_SEC)


# --- BGM (M3 오디오) ---


## 씬 기본 곡(주간 동부 변경 남측 / 야간 공용)을 걸고, 전직 팡파레 시그널을 연결한다.
## 곡 매핑·주야간 전환·크로스페이드는 BgmManager가 data/audio/bgm_tracks.json을 보고 처리한다.
func _init_bgm() -> void:
	BgmManager.play_for_scene(scene_file_path)
	BgmManager.bind_job_transition(_player.get_node_or_null("PlayerJobTransition"))


## 온보딩 튜토리얼(UI-4) 배선 — MonsterSpawner가 이미 스폰해 둔 뿔토끼만 골라 넘긴다.
func _start_tutorial() -> void:
	var rabbits: Array[RabbitMonster] = []
	for monster in _monster_spawner.get_children():
		if monster is RabbitMonster:
			rabbits.append(monster)
	_tutorial.start(
		_player,
		_player.get_node("PlayerStats"),
		_inventory,
		_drop_system,
		_hud,
		_onboarding_hint_bar,
		rabbits
	)


func _on_monster_spawned(monster: MonsterBase) -> void:
	_register_monster(monster)
	var quests := get_node("QuestController") as QuestController
	if monster.has_meta("content_id"):
		monster.died.connect(
			quests.journal.record_event.bind(
				"KILL",
				String(monster.get_meta("content_id")),
				String(monster.get_meta("spawn_source_id", "")),
				monster.get_instance_id()
			)
		)


## 드랍 테이블 조회는 MonsterDropRegistry(scripts/world) 한 곳으로 통일했다 — M3 신규 종은
## 한 스크립트가 여러 종(무법자/노상강도/밀렵꾼 등)을 담당해 클래스 분기로 아종을 구분할 수
## 없기 때문이다(레지스트리 헤더 참고).
func _register_monster(monster: Node) -> void:
	## 전투 곡 전환용 — 정예만 구독하고 잡몹은 무시한다(BgmManager.register_monster 참고).
	BgmManager.register_monster(monster)
	var drop_table := MonsterDropRegistry.table_for(monster)
	if drop_table == null:
		return
	_drop_system.register_monster(monster, drop_table)
	## 처치 경험치 지급(B-1) — 드랍과 동일하게 몬스터 레벨·등급을 DropTableData에서 재사용한다.
	_progression.register_monster(monster, drop_table)
	print("[통합] 몬스터 등록: %s" % monster.name)


func _setup_quest_ui(quests: QuestController) -> void:
	_integrated_menu.bind_quests(quests.journal)
	var dialog := DialogScript.new()
	dialog.name = "QuestDialog"
	add_child(dialog)
	dialog.setup(quests)
	var tracker := TrackerScript.new()
	tracker.name = "QuestTracker"
	add_child(tracker)
	tracker.setup(quests)
	var npc = load(NpcRegistry.SCENES["yeoulmok_receptionist"]).instantiate()
	npc.name = "QuestReceptionist"
	npc.position = get_node("Markers/NPCs/NPC_조합순회접수원").position
	add_child(npc)
	npc.setup(_player, quests, dialog, _hud)
	var site = load("res://scripts/quests/rift_investigation.gd").new()
	site.name = "RiftInvestigation"
	site.position = get_node("Markers/QuestPoints/INTERACT_균열표식_MQ0104").position
	add_child(site)
	site.setup(_player, quests, get_node("Markers/QuestPoints/REACH_균열굴어귀_MQ0104").global_position)
	var interaction = load("res://scripts/quests/world_interaction.gd").new()
	interaction.name = "WorldInteraction"
	add_child(interaction)
	interaction.setup(_player, _hud)
	interaction.candidates.assign([npc, site])
