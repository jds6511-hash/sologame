## 사망 연출 중 통합 메뉴 차단 검증 (디렉터 확정 — D-3 통합 사전 리포트 비차단 이슈 3).
##
## 왜 막는가: 두 가지가 동시에 깨진다. ① `open_menu()`의 `get_tree().paused = true`가
## `PlayerDeathSequence._process()`를 멈춰 사망 연출이 그 자리에 정지한다 ② 암전
## CanvasLayer(20)가 메뉴(10)보다 위라, 암전 구간에 열면 메뉴가 검은 화면 **아래** 깔려
## 보이지도 않는다.
##
## `test_integrated_menu.gd`가 아니라 별도 파일인 이유: 그쪽이 이미 gdlint의 공개 메서드
## 20개 상한에 닿아 있다(테스트 함수가 전부 공개 메서드로 계산된다).
extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _menu: IntegratedMenu


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/integrated_menu.tscn")
	_menu = scene.instantiate()
	add_child_autofree(_menu)


func after_each() -> void:
	## 메뉴가 열린 채 끝나면 SceneTree.paused=true가 남아 다른 테스트에 영향을 준다.
	get_tree().paused = false


func _spawn_dead_player() -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	_menu.bind_player(player)
	player.get_node("PlayerStats").take_damage(9999.0)
	return player


func test_menu_does_not_open_while_death_sequence_active() -> void:
	_spawn_dead_player()

	_menu.open_menu()

	assert_true(_menu.is_menu_blocked(), "사망 연출 중에는 차단 상태여야 한다")
	assert_false(_menu.is_open(), "메뉴가 열리면 안 된다")
	assert_false(get_tree().paused, "일시정지가 걸리면 사망 연출이 그 자리에 멈춘다")


## 탭 단축키 경로도 같은 규칙 — 열리지도 않는데 탭만 조용히 바뀌면 다음에 열었을 때
## 엉뚱한 탭이 나온다.
func test_tab_shortcut_does_not_switch_tab_while_blocked() -> void:
	var tabs: TabContainer = _menu.get_node("Tabs")
	var before := tabs.current_tab
	_spawn_dead_player()

	_menu._on_tab_shortcut(before + 1)

	assert_false(_menu.is_open())
	assert_eq(tabs.current_tab, before, "차단 중에는 탭도 바뀌지 않는다")


func test_menu_opens_again_after_death_sequence_finishes() -> void:
	var player := _spawn_dead_player()
	var sequence: PlayerDeathSequence = player.get_node("PlayerDeathSequence")

	## 단계마다 1회씩 — 한 번의 _process 에서는 전이가 한 번만 일어난다.
	sequence._process(sequence.rules.death_motion_sec + 0.01)
	sequence._process(sequence.rules.fade_out_sec + 0.01)
	sequence._process(sequence.rules.blackout_hold_sec + 0.01)
	sequence._process(sequence.rules.fade_in_sec + 0.01)

	assert_false(_menu.is_menu_blocked(), "연출이 끝나면 차단이 풀린다")
	_menu.open_menu()
	assert_true(_menu.is_open())


## 플레이어를 바인드하지 않은 씬(메뉴 단독 화면 등)에서는 막을 근거가 없으므로 통과시킨다.
func test_menu_not_blocked_without_bound_player() -> void:
	assert_false(_menu.is_menu_blocked())

	_menu.open_menu()

	assert_true(_menu.is_open())
