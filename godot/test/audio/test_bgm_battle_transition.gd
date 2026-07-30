## BGM 매니저 검증 ② — 전투 곡 진입/이탈 판정과 전직 팡파레.
## 곡 카탈로그·루프·씬 매핑·주야간 검증은 `test_bgm_manager.gd` 참고
## (gdlint max-public-methods 20개 제한으로 파일 분리).
##
## 판정 기준(audio-direction 3-2): 잡몹 교전은 전환하지 않고 **정예**와 피해가 오간 순간에만
## 전투 곡으로 넘어간다. 이탈은 정예 전멸 즉시 또는 마지막 교전 후 5초(어그로 해제 유예).
extends GutTest

const TABLE_PATH := "res://data/audio/bgm_tracks.json"
const START_AREA_SCENE := "res://scenes/world/eastern_frontier_starting_area.tscn"
const FIELD_DAY_TRACK := &"field_eastern_frontier_south"
const BATTLE_TRACK := &"battle_normal_early"

const DummyEliteMonster := preload("res://test/audio/dummy_elite_monster.gd")
const DummyJobTransition := preload("res://test/audio/dummy_job_transition.gd")

var _table: Dictionary = {}


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))


func before_each() -> void:
	GameClock.reset()
	BgmManager.reset()


func after_each() -> void:
	BgmManager.reset()
	GameClock.reset()


# --- 전투 진입 ---


func test_elite_engagement_switches_to_battle_track() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	var elite := _add_monster()
	elite.took_damage.emit(10.0, 90.0)
	assert_true(BgmManager.is_battle_active(), "정예와 피해가 오가면 전투 진입")
	assert_eq(BgmManager.current_track_id, BATTLE_TRACK)


func test_elite_attack_also_triggers_battle() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	var elite := _add_monster()
	elite.attack_landed.emit(self)
	assert_eq(BgmManager.current_track_id, BATTLE_TRACK, "정예가 플레이어를 때려도 진입")


func test_normal_monster_does_not_switch_track() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	var mob := _add_monster(false)
	mob.took_damage.emit(10.0, 90.0)
	assert_false(BgmManager.is_battle_active(), "잡몹 교전은 BGM 전환 없음(audio-direction 3-2)")
	assert_eq(BgmManager.current_track_id, FIELD_DAY_TRACK)


# --- 전투 이탈 ---


func test_elite_death_resumes_field_track_from_stopped_position() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	await wait_seconds(0.4)
	var elite := _add_monster()
	elite.took_damage.emit(10.0, 90.0)
	elite.died.emit()
	assert_false(BgmManager.is_battle_active(), "정예 전멸 즉시 전투 이탈")
	assert_eq(BgmManager.current_track_id, FIELD_DAY_TRACK)
	assert_gt(BgmManager.get_playback_position(), 0.0, "필드 곡은 중단 지점에서 재개(resume)")


func test_battle_exit_grace_period_matches_spec() -> void:
	## 5초를 실제로 기다리지 않고, 유예 타이머가 규격값으로 걸렸는지와 타임아웃 경로가
	## 필드 곡으로 되돌리는지를 나눠 확인한다.
	BgmManager.play_for_scene(START_AREA_SCENE)
	var elite := _add_monster()
	elite.took_damage.emit(10.0, 90.0)
	var timer: Timer = BgmManager._battle_exit_timer
	var grace := float(_table["timings"]["battle_exit_grace_sec"])
	assert_almost_eq(timer.wait_time, grace, 0.001, "어그로 해제 유예 5초")
	assert_gt(timer.time_left, 0.0, "교전 이벤트마다 유예 타이머 재시작")
	timer.timeout.emit()
	assert_false(BgmManager.is_battle_active())
	assert_eq(BgmManager.current_track_id, FIELD_DAY_TRACK)


# --- 크로스페이드 ---


func test_battle_transition_crossfades_both_players() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	await wait_seconds(0.3)
	var previous_player: AudioStreamPlayer = BgmManager._active_player()
	var elite := _add_monster()
	elite.took_damage.emit(10.0, 90.0)
	var next_player: AudioStreamPlayer = BgmManager._active_player()
	assert_ne(previous_player, next_player, "A/B 플레이어를 번갈아 써야 겹침이 가능")
	assert_true(previous_player.playing, "교차 구간에는 두 곡이 동시에 울린다")
	assert_true(next_player.playing)
	await wait_seconds(0.6)  ## battle_fade_out 0.3초 + 여유
	assert_false(previous_player.playing, "페이드아웃이 끝나면 이전 플레이어는 정지")


# --- 팡파레 (전직) ---


func test_job_changed_plays_fanfare_and_pauses_bgm() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	var transition := _add_job_transition()
	transition.job_changed.emit(&"warrior")
	assert_true(BgmManager._fanfare_player.playing, "전직 시 팡파레 재생")
	assert_eq(BgmManager.current_track_id, &"", "팡파레 동안 BGM은 비운다")


func test_fanfare_end_resumes_previous_track() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	await wait_seconds(0.4)
	BgmManager.play_fanfare()
	## 7초 팡파레를 끝까지 기다리지 않고 종료 시그널로 복귀 경로만 확인한다.
	BgmManager._fanfare_player.finished.emit()
	assert_eq(BgmManager.current_track_id, FIELD_DAY_TRACK, "팡파레 후 원곡 복귀")
	assert_gt(BgmManager.get_playback_position(), 0.0, "중단 지점에서 재개")


## 팡파레를 실제로 트리거하는 쪽(scripts/progression)은 읽기 전용 도메인이라 대역으로
## 테스트한다 — 대역이 흉내내는 시그널이 진짜 스크립트에 있는지는 여기서 확인한다.
func test_real_job_transition_exposes_job_changed_signal() -> void:
	var transition := PlayerJobTransition.new()
	assert_true(transition.has_signal("job_changed"), "BgmManager가 구독하는 시그널 계약")
	transition.free()


# --- 헬퍼 ---


func _add_monster(is_elite: bool = true) -> Node:
	var monster := DummyEliteMonster.new()
	monster.stats.is_elite = is_elite
	add_child_autofree(monster)
	BgmManager.register_monster(monster)
	return monster


func _add_job_transition() -> Node:
	var transition := DummyJobTransition.new()
	add_child_autofree(transition)
	BgmManager.bind_job_transition(transition)
	return transition
