## BGM 매니저 오토로드("BgmManager") — `docs\art\audio-direction.md` 3장(전환 규칙) 구현.
##
## 정식 BGM 6곡(리리아 3 생성, `docs\art\bgm-lyria-prompts.md` 6장)을 실제로 울리게 하는
## 유일한 재생 경로다. 씬·주야간·전투·전직에 따라 곡을 골라 크로스페이드로 갈아끼운다.
##
## 구조: AudioStreamPlayer 2개(_players)를 번갈아 쓰는 A/B 크로스페이드 + 팡파레 전용
## 플레이어 1개. 전부 "BGM" 버스로 보내므로(3-1장 버스 구조) 옵션 볼륨은 이 버스 하나만
## 조절하면 된다 — 매니저가 건드리는 player.volume_db는 페이드 전용이며 믹스 볼륨이
## 아니다(플레이어 볼륨으로 음량을 조절하면 페이드가 그 값을 덮어써 버린다).
##
## 곡 목록·씬 매핑·전환 수치는 전부 `res://data/audio/bgm_tracks.json`에 있다 — 기획 수치를
## 코드에 하드코딩하지 않는다. 새 지역 곡은 그 파일에 한 줄 추가하고 씬이 play_for_scene을
## 부르면 끝이다.
##
## 루프 처리(중요): `.ogg.import`는 프로젝트 전역 `.gitignore` 대상이라 임포트 시 지정한
## 루프 플래그가 저장소에 보존되지 않는다. 따라서 스트림을 물릴 때마다 코드에서
## stream.loop을 JSON의 loop 값으로 직접 지정한다(팡파레만 false).
##
## 전역 클래스 이름(MonsterBase 등)을 타입 힌트로 쓰지 않는 이유: 오토로드는 엔진 부팅 시점
## (전역 클래스 캐시가 비어 있을 수 있는 시점)에 파싱되므로 "Could not find type" 오류가 날 수
## 있다(scripts/combat/hit_feedback_manager.gd 헤더와 동일한 제약). 몬스터는 시그널·stats
## 유무만 보는 덕 타이핑으로 다룬다 — scripts/ai는 다른 담당 도메인이라 읽기만 한다.
extends Node

## 재생 곡이 바뀔 때(크로스페이드 시작 시점) 발신 — HUD/디버그 표시용.
signal track_changed(track_id: StringName)

const TRACK_TABLE_PATH := "res://data/audio/bgm_tracks.json"
## 3-1장 버스 구조의 BGM 버스. default_bus_layout.tres에 이미 존재한다.
const BUS_NAME := "BGM"
## 페이드 완전 정지 볼륨(dB) — Godot의 무음 하한.
const SILENT_DB := -80.0

## 현재 재생 중인 곡 ID(페이드인 중인 곡 기준). 무곡이면 빈 문자열.
var current_track_id: StringName = &""

var _tracks: Dictionary = {}
var _scene_tracks: Dictionary = {}
var _situations: Dictionary = {}
var _timings: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
## 플레이어별 진행 중인 페이드 트윈 — 전환이 연달아 일어날 때 이전 트윈이 새 곡의 볼륨을
## 덮어써 정지시키는 것을 막는다(항상 죽이고 새로 만든다).
var _fade_tweens: Array[Tween] = [null, null]
var _fanfare_player: AudioStreamPlayer = null
var _active_index: int = 0

## 지금 씬의 곡 매핑({"day": id, "night": id}) — 주야간 전환 시 다시 조회한다.
var _scene_entry: Dictionary = {}
var _battle_active: bool = false
## 교전 중인 정예 몬스터 목록(전멸 판정용).
var _engaged_elites: Array[Node] = []
var _battle_exit_timer: Timer = null
## 전투/팡파레로 중단된 곡과 그 중단 지점 — audio-direction 3-2 "필드 곡은 resume".
var _resume_track_id: StringName = &""
var _resume_position: float = 0.0
## 팡파레 때문에 비워 둔 곡 — 팡파레가 끝나면 이 곡으로 되돌린다.
var _suspended_track_id: StringName = &""


func _ready() -> void:
	_load_track_table()
	_create_players()
	GameClock.day_started.connect(_on_phase_changed)
	GameClock.night_started.connect(_on_phase_changed)


# --- 공용 API ---


## 씬 진입 시 그 씬의 기본 곡을 건다(주야간 정책 반영). scene_file_path를 그대로 넘기면 된다.
## 매핑이 없는 씬은 무곡으로 처리한다(곡 없는 씬에서 이전 곡이 계속 울리는 것을 막는다).
func play_for_scene(scene_path: String) -> void:
	_scene_entry = _scene_tracks.get(scene_path, {})
	_clear_battle_state()
	var track_id := _context_track_id()
	if track_id.is_empty():
		stop(_timing("scene_fade_out_sec"))
		return
	play_track(track_id, _timing("scene_fade_out_sec"), _timing("scene_fade_in_sec"))


## 곡을 크로스페이드로 교체한다. 이미 같은 곡이 울리고 있으면 아무것도 하지 않는다
## (audio-direction 3-2 "같은 트랙 ID면 전환하지 않고 이어서 재생" — 권역 공유 곡 왕복 피로 방지).
func play_track(
	track_id: StringName, fade_out_sec: float, fade_in_sec: float, from_position: float = 0.0
) -> void:
	if track_id.is_empty() or not _tracks.has(String(track_id)):
		push_warning("[BGM] 알 수 없는 트랙 ID: %s" % track_id)
		return
	if track_id == current_track_id and _active_player().playing:
		return
	var previous_index := _active_index
	_active_index = 1 - _active_index
	var next := _active_player()
	next.stream = _resolve_stream(track_id)
	next.volume_db = SILENT_DB
	next.play(from_position)
	_fade(_active_index, 0.0, 1.0, fade_in_sec)
	if _players[previous_index].playing:
		_fade(previous_index, 1.0, 0.0, fade_out_sec)
	current_track_id = track_id
	print("[BGM] 곡 전환 → %s (%.2f초 지점부터)" % [track_id, from_position])
	track_changed.emit(track_id)


func stop(fade_out_sec: float = 0.0) -> void:
	current_track_id = &""
	if _active_player().playing:
		_fade(_active_index, 1.0, 0.0, fade_out_sec)


## 정예 몬스터의 교전 시그널을 구독한다(씬 스포너 배선 지점에서 몬스터마다 1회 호출).
## 잡몹은 등록해도 무시한다 — audio-direction 3-2 "일반(잡몹) 교전은 BGM 전환 없음".
func register_monster(monster: Node) -> void:
	if monster == null or not monster.has_signal("took_damage"):
		return
	var stats: Variant = monster.get("stats")
	if stats == null or not bool(stats.get("is_elite")):
		return
	if not monster.took_damage.is_connected(_on_elite_took_damage.bind(monster)):
		monster.took_damage.connect(_on_elite_took_damage.bind(monster))
	if not monster.attack_landed.is_connected(_on_elite_attack_landed.bind(monster)):
		monster.attack_landed.connect(_on_elite_attack_landed.bind(monster))
	if not monster.died.is_connected(_on_elite_died.bind(monster)):
		monster.died.connect(_on_elite_died.bind(monster))


## 전직·승급 팡파레(S10)를 걸 PlayerJobTransition을 연결한다. scripts/progression은 다른
## 담당 도메인이라 시그널만 구독한다(그쪽 코드는 수정하지 않는다).
func bind_job_transition(job_transition: Node) -> void:
	if job_transition == null or not job_transition.has_signal("job_changed"):
		return
	if not job_transition.job_changed.is_connected(_on_job_changed):
		job_transition.job_changed.connect(_on_job_changed)


## 팡파레(논루프)를 재생한다. 현재 곡은 짧게 페이드아웃하고, 팡파레가 끝나면 중단 지점에서
## 되돌린다. 기획서 3-2 표에 팡파레 중 BGM 처리 규칙이 없어 systems-dev가 채택한 규칙이다
## (7초 팡파레를 필드 곡 위에 겹치면 화성이 충돌해 의전 연출이 지저분해진다).
func play_fanfare() -> void:
	var track_id := StringName(_situations.get("fanfare", ""))
	if track_id.is_empty() or not _tracks.has(String(track_id)):
		return
	_suspended_track_id = current_track_id
	_resume_position = _active_player().get_playback_position()
	stop(_timing("fanfare_fade_out_sec"))
	_fanfare_player.stream = _resolve_stream(track_id)
	_fanfare_player.volume_db = 0.0
	_fanfare_player.play()


func is_playing() -> bool:
	return _active_player().playing


func get_playback_position() -> float:
	return _active_player().get_playback_position()


func is_battle_active() -> bool:
	return _battle_active


## 테스트 전용 — 오토로드는 GUT 전체 실행 동안 하나뿐이라 테스트 간 상태를 씻어낸다
## (GameClock.reset()과 같은 목적).
func reset() -> void:
	for index in _players.size():
		if _fade_tweens[index] != null and _fade_tweens[index].is_valid():
			_fade_tweens[index].kill()
		_fade_tweens[index] = null
		_players[index].stop()
		_players[index].volume_db = 0.0
	_fanfare_player.stop()
	current_track_id = &""
	_scene_entry = {}
	_suspended_track_id = &""
	_resume_track_id = &""
	_resume_position = 0.0
	_clear_battle_state()


# --- 초기화 ---


func _load_track_table() -> void:
	var text := FileAccess.get_file_as_string(TRACK_TABLE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[BGM] 트랙 표를 읽지 못했다: %s" % TRACK_TABLE_PATH)
		return
	_tracks = parsed.get("tracks", {})
	_scene_tracks = parsed.get("scenes", {})
	_situations = parsed.get("situations", {})
	_timings = parsed.get("timings", {})


func _create_players() -> void:
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		player.name = "BgmPlayer%d" % index
		add_child(player)
		_players.append(player)
	_fanfare_player = AudioStreamPlayer.new()
	_fanfare_player.bus = BUS_NAME
	_fanfare_player.name = "FanfarePlayer"
	add_child(_fanfare_player)
	_fanfare_player.finished.connect(_on_fanfare_finished)
	_battle_exit_timer = Timer.new()
	_battle_exit_timer.one_shot = true
	_battle_exit_timer.name = "BattleExitTimer"
	add_child(_battle_exit_timer)
	_battle_exit_timer.timeout.connect(_exit_battle)


# --- 곡 선택 ---


func _active_player() -> AudioStreamPlayer:
	return _players[_active_index]


## 지금 씬·시각에 해당하는 기본 곡. 야간 곡이 없는 씬은 주간 곡을 그대로 쓴다
## (audio-direction 2-2 "야간 활성 지역만 곡 교체").
func _context_track_id() -> StringName:
	var day_id := String(_scene_entry.get("day", ""))
	if GameClock.is_day:
		return StringName(day_id)
	return StringName(_scene_entry.get("night", day_id))


## JSON의 loop 값을 스트림에 직접 지정한다(헤더 "루프 처리" 참고).
func _resolve_stream(track_id: StringName) -> AudioStream:
	var entry: Dictionary = _tracks[String(track_id)]
	var stream: AudioStream = load(String(entry["path"]))
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = bool(entry.get("loop", true))
	return stream


func _timing(key: String) -> float:
	return float(_timings.get(key, 0.0))


# --- 크로스페이드 (audio-direction 3-2 "등파워 크로스페이드") ---


## from_gain -> to_gain(진폭 0~1)으로 페이드한다. 진폭을 sqrt로 보간해 교차 구간의
## 합성 에너지를 일정하게 유지한다(dB 선형 보간은 교차 지점에서 음량이 꺼진다).
func _fade(index: int, from_gain: float, to_gain: float, duration_sec: float) -> void:
	var player := _players[index]
	if _fade_tweens[index] != null and _fade_tweens[index].is_valid():
		_fade_tweens[index].kill()
	_fade_tweens[index] = null
	if duration_sec <= 0.0:
		_apply_gain(to_gain, player)
		if to_gain <= 0.0:
			player.stop()
		return
	var tween := create_tween()
	tween.tween_method(_apply_gain.bind(player), from_gain, to_gain, duration_sec)
	if to_gain <= 0.0:
		tween.tween_callback(player.stop)
	_fade_tweens[index] = tween


func _apply_gain(gain: float, player: AudioStreamPlayer) -> void:
	var amplitude := sqrt(clampf(gain, 0.0, 1.0))
	player.volume_db = SILENT_DB if amplitude <= 0.0 else linear_to_db(amplitude)


# --- 주야간 (GameClock 구독) ---


func _on_phase_changed(_day_number: int) -> void:
	var track_id := _context_track_id()
	if track_id.is_empty():
		return
	## 전투 중이면 곡을 바꾸지 않고, 전투가 끝났을 때 돌아갈 곡만 갈아둔다.
	if _battle_active:
		_resume_track_id = track_id
		_resume_position = 0.0
		return
	var fade := _timing("day_night_crossfade_sec")
	play_track(track_id, fade, fade)


# --- 전투 진입/이탈 ---
#
# 판정 기준(audio-direction 3-2 표 그대로):
#   진입 — "정예 몬스터 조우"에 한정한다. 잡몹 교전은 전환하지 않는다(250시간 플레이에서
#          교전마다 곡이 바뀌면 피로가 크다는 기획 판단). 정예를 "봤을 때"가 아니라 실제
#          피해가 오간 순간(정예가 맞음 took_damage / 정예가 때림 attack_landed)을 조우로
#          삼는다 — 시야 진입을 기준으로 하면 정예 캠프 옆을 지나가는 동안 곡이 왔다 갔다
#          한다. 정예 목표 TTK는 약 30초(combat.md 8-1)라 첫 타격 시점이면 충분히 이르다.
#          MonsterBase에는 어그로 상태 시그널이 없고 scripts/ai는 읽기 전용 도메인이라,
#          기존 공용 시그널만으로 판정할 수 있는 이 기준을 택했다.
#   이탈 — 교전한 정예 전멸(died) 즉시, 또는 마지막 교전 이벤트 후 battle_exit_grace_sec(5초)
#          동안 추가 교전이 없을 때("어그로 해제 후 5초"). 이탈은 필드 곡을 중단 지점에서
#          resume한다.


func _on_elite_took_damage(_amount: float, _remaining_hp: float, monster: Node) -> void:
	_on_elite_engaged(monster)


func _on_elite_attack_landed(_target: Node, monster: Node) -> void:
	_on_elite_engaged(monster)


func _on_elite_engaged(monster: Node) -> void:
	if not _engaged_elites.has(monster):
		_engaged_elites.append(monster)
	_battle_exit_timer.start(_timing("battle_exit_grace_sec"))
	_enter_battle()


func _on_elite_died(monster: Node) -> void:
	_engaged_elites.erase(monster)
	if _engaged_elites.is_empty():
		_exit_battle()


func _enter_battle() -> void:
	var battle_id := StringName(_situations.get("battle", ""))
	if _battle_active or battle_id.is_empty() or battle_id == current_track_id:
		return
	_battle_active = true
	_resume_track_id = current_track_id
	_resume_position = _active_player().get_playback_position()
	play_track(battle_id, _timing("battle_fade_out_sec"), _timing("battle_fade_in_sec"))


func _exit_battle() -> void:
	_battle_exit_timer.stop()
	_engaged_elites.clear()
	if not _battle_active:
		return
	_battle_active = false
	var back_id := _resume_track_id if not _resume_track_id.is_empty() else _context_track_id()
	if back_id.is_empty():
		return
	var fade := _timing("battle_exit_crossfade_sec")
	play_track(back_id, fade, fade, _resume_position)


func _clear_battle_state() -> void:
	_battle_active = false
	_engaged_elites.clear()
	if _battle_exit_timer != null:
		_battle_exit_timer.stop()


# --- 팡파레 (PlayerJobTransition.job_changed 구독) ---


func _on_job_changed(_job_id: StringName) -> void:
	play_fanfare()


## 팡파레 종료 시 중단했던 곡으로 되돌린다. 팡파레 도중 다른 전환(전투 진입 등)이
## 곡을 이미 채워 넣었다면(current_track_id 비어 있지 않음) 그쪽을 존중해 아무것도 하지 않는다.
func _on_fanfare_finished() -> void:
	if _suspended_track_id.is_empty() or not current_track_id.is_empty():
		_suspended_track_id = &""
		return
	var track_id := _suspended_track_id
	_suspended_track_id = &""
	play_track(track_id, 0.0, _timing("fanfare_resume_fade_in_sec"), _resume_position)
