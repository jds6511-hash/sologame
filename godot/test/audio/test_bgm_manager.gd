## BGM 매니저(오토로드 BgmManager) 검증 ① — 곡 카탈로그·루프 플래그·씬 매핑·주야간 전환·
## 실제 재생 여부. `docs\art\audio-direction.md` 2-2·3-2장과 `data/audio/bgm_tracks.json` 정합.
##
## 전투 전환·팡파레 검증은 `test_bgm_battle_transition.gd` 참고
## (gdlint max-public-methods 20개 제한으로 파일 분리).
##
## 헤드리스 환경에는 오디오 하드웨어가 없지만 Godot이 더미 오디오 드라이버로 믹싱 스레드를
## 돌리므로 AudioStreamPlayer.get_playback_position()이 실제로 전진한다 — 그 전진을 "정말
## 재생되고 있다"는 근거로 삼는다(test_playback_position_advances_without_audio_hardware).
extends GutTest

const TABLE_PATH := "res://data/audio/bgm_tracks.json"
const START_AREA_SCENE := "res://scenes/world/eastern_frontier_starting_area.tscn"
const ARENA_SCENE := "res://scenes/debug/debug_combat_arena.tscn"
const FIELD_DAY_TRACK := &"field_eastern_frontier_south"
const FIELD_NIGHT_TRACK := &"field_night_common"
const BATTLE_TRACK := &"battle_normal_early"
## GameClock은 00:00~16:00이 낮이다 — 17시간 점프로 밤에 들어가고, 8시간 더 점프하면 다음 날 낮.
const HOURS_INTO_NIGHT := 17.0
const HOURS_BACK_TO_DAY := 8.0

var _table: Dictionary = {}


func before_all() -> void:
	_table = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))


func before_each() -> void:
	GameClock.reset()
	BgmManager.reset()


func after_each() -> void:
	BgmManager.reset()
	GameClock.reset()


# --- 곡 카탈로그·루프 플래그 ---


func test_all_six_tracks_exist_on_disk() -> void:
	var tracks: Dictionary = _table["tracks"]
	assert_eq(tracks.size(), 6, "정식 BGM 6곡이 카탈로그에 등록돼 있어야 함")
	for track_id: String in tracks:
		var path: String = tracks[track_id]["path"]
		assert_true(ResourceLoader.exists(path), "%s 음원 파일 존재: %s" % [track_id, path])


func test_loop_tracks_get_loop_flag_set_in_code() -> void:
	## .ogg.import가 .gitignore 대상이라 저장소에는 루프 플래그가 없다 — 매니저가 코드에서
	## 켜 주지 않으면 곡이 한 번 울리고 끝난다.
	for track_id: String in _table["tracks"]:
		if not bool(_table["tracks"][track_id]["loop"]):
			continue
		BgmManager.play_track(StringName(track_id), 0.0, 0.0)
		var stream: AudioStream = BgmManager._active_player().stream
		assert_true(stream is AudioStreamOggVorbis, "%s는 OGG 스트림" % track_id)
		assert_true((stream as AudioStreamOggVorbis).loop, "%s 루프 플래그가 켜져야 함" % track_id)


func test_fanfare_stream_is_not_looped() -> void:
	BgmManager.play_fanfare()
	var stream: AudioStream = BgmManager._fanfare_player.stream
	assert_true(stream is AudioStreamOggVorbis, "팡파레도 OGG 스트림")
	assert_false((stream as AudioStreamOggVorbis).loop, "팡파레(S10)는 논루프여야 함")


# --- 씬 매핑 ---


func test_start_area_plays_day_field_track() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	assert_eq(BgmManager.current_track_id, FIELD_DAY_TRACK)
	assert_true(BgmManager.is_playing(), "씬 진입 즉시 재생 상태로 들어가야 함")


func test_unmapped_scene_stops_music() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	BgmManager.play_for_scene("res://scenes/world/존재하지_않는_씬.tscn")
	assert_eq(BgmManager.current_track_id, &"", "매핑 없는 씬은 무곡 — 이전 곡이 남지 않아야 함")


func test_same_track_is_not_restarted() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	await wait_seconds(0.3)
	var position_before := BgmManager.get_playback_position()
	BgmManager.play_track(FIELD_DAY_TRACK, 0.0, 0.0)
	assert_almost_eq(
		BgmManager.get_playback_position(),
		position_before,
		0.2,
		"같은 트랙 ID면 전환하지 않고 이어서 재생(audio-direction 3-2)"
	)


# --- 주야간 전환 (GameClock 구독) ---


func test_night_started_switches_to_night_track() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	GameClock.debug_jump_hours(HOURS_INTO_NIGHT)
	assert_false(GameClock.is_day, "17시간 점프면 밤이어야 함(테스트 전제 확인)")
	assert_eq(BgmManager.current_track_id, FIELD_NIGHT_TRACK, "야간 공용 곡으로 교체")


func test_day_started_returns_to_field_track() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	GameClock.debug_jump_hours(HOURS_INTO_NIGHT)
	GameClock.debug_jump_hours(HOURS_BACK_TO_DAY)
	assert_true(GameClock.is_day, "다음 날 낮으로 넘어와야 함(테스트 전제 확인)")
	assert_eq(BgmManager.current_track_id, FIELD_DAY_TRACK)


func test_scene_without_night_track_keeps_day_track_at_night() -> void:
	BgmManager.play_for_scene(ARENA_SCENE)
	GameClock.debug_jump_hours(HOURS_INTO_NIGHT)
	assert_eq(BgmManager.current_track_id, BATTLE_TRACK, "야간 곡이 없는 씬은 같은 곡 유지")


# --- 실제 재생·버스 라우팅 ---


func test_playback_position_advances_without_audio_hardware() -> void:
	BgmManager.play_for_scene(START_AREA_SCENE)
	var first := BgmManager.get_playback_position()
	await wait_seconds(0.5)
	var second := BgmManager.get_playback_position()
	assert_true(BgmManager.is_playing(), "스트림이 재생 상태여야 함")
	assert_gt(second, first, "더미 오디오 드라이버에서도 재생 위치가 전진해야 함")


func test_all_players_route_through_bgm_bus() -> void:
	assert_ne(AudioServer.get_bus_index("BGM"), -1, "BGM 버스가 default_bus_layout에 있어야 함")
	for player: AudioStreamPlayer in BgmManager._players:
		assert_eq(player.bus, "BGM", "볼륨 조절은 버스 경유(audio-direction 3-1장 버스 구조)")
	assert_eq(BgmManager._fanfare_player.bus, "BGM")
