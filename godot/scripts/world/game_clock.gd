## 게임 내 시간 오토로드 (G2-4) — 현실 30분 = 게임 하루, 낮 20분 : 밤 10분(2:1).
##
## `reputation-territory.md` 4장·`combat.md` 2-3장 확정 수치는 GameTimeData(Resource,
## `data/world/game_time_data.tres`)로 분리했다 — 이 스크립트는 그 값을 읽어 흐르는
## 시계와 파생 API(시각 조회·야간 배율)만 제공한다.
##
## 시각 모델(가정 — 기획 문서에 낮/밤의 정확한 게임 시계 경계가 없어 systems-dev가
## 채택): 게임 시계는 항상 일정 배속(현실 1초 = 게임 48초, 현실 30분 = 게임 24시간)으로
## 흐르고, 낮은 00:00~16:00(16시간)·밤은 16:00~24:00(8시간)이다. 현실 시간 비율(20분:10분)과
## 게임 시계 비율(16시간:8시간)이 둘 다 2:1이 되도록 고정해, 배속 전환 없이 단일 상수
## (real_seconds_day_phase)만으로 낮/밤 경계를 판정할 수 있게 했다.
##
## 일시정지 연동: 이 노드는 기본 process_mode(PROCESS_MODE_INHERIT)를 그대로 두므로,
## integrated_menu.gd가 get_tree().paused = true로 메뉴를 열면 이 오토로드도 함께 멈춘다
## (reputation-territory.md 4장 "컷신·대화·메뉴 중 정지" 요구를 별도 코드 없이 만족).
## 히트스톱(Engine.time_scale=0, combat.md 5-3)도 _process(delta)의 delta 자체가
## time_scale의 영향을 받으므로 자연히 함께 멈춘다 — 수 프레임 수준이라 체감상 무해하다.
extends Node

signal day_started(day_number: int)
signal night_started(day_number: int)

## 게임 하루 = 24시간 = 86400게임초 (고정, 상단 헤더 시각 모델 참고)
const GAME_SECONDS_PER_DAY := 86400.0

@export var time_data: GameTimeData = preload("res://data/world/game_time_data.tres")

var day_number: int = 1
var is_day: bool = true

var _elapsed_real_sec_in_day: float = 0.0


func _process(delta: float) -> void:
	advance_time(delta)


## 현실 초(delta_real_sec)만큼 시계를 흘린다. 하루 이상 흐르면 day_number를 갱신하고,
## 낮/밤 경계를 넘으면 day_started/night_started를 발신한다.
func advance_time(delta_real_sec: float) -> void:
	if delta_real_sec <= 0.0:
		return
	_elapsed_real_sec_in_day += delta_real_sec
	while _elapsed_real_sec_in_day >= time_data.real_seconds_per_game_day:
		_elapsed_real_sec_in_day -= time_data.real_seconds_per_game_day
		day_number += 1
	_refresh_phase()


func _refresh_phase() -> void:
	var was_day := is_day
	is_day = _elapsed_real_sec_in_day < time_data.real_seconds_day_phase
	if is_day == was_day:
		return
	if is_day:
		day_started.emit(day_number)
	else:
		night_started.emit(day_number)


## 게임 하루 안에서 경과한 게임초(0~86400 미만) — get_hour/get_minute의 공용 계산식.
func get_game_seconds_of_day() -> float:
	return _elapsed_real_sec_in_day * GAME_SECONDS_PER_DAY / time_data.real_seconds_per_game_day


func get_hour() -> int:
	return int(get_game_seconds_of_day() / 3600.0) % 24


func get_minute() -> int:
	return int(get_game_seconds_of_day() / 60.0) % 60


## 야간 몬스터 HP/공격력 배율 (combat.md 2-3장 — 보스 제외, 낮에는 항상 1.0).
func get_monster_stat_multiplier(is_boss: bool = false) -> float:
	if is_boss or is_day:
		return 1.0
	return time_data.night_monster_stat_multiplier


## 야간 아이템 드랍률 배율 (combat.md 2-3장 — 골드 제외·보스 제외, 낮에는 항상 1.0).
## 호출자(DropSystem)가 골드 판정에는 이 함수를 쓰지 않아야 "골드 ×1.0 유지"가 지켜진다.
func get_item_drop_rate_multiplier(is_boss: bool = false) -> float:
	if is_boss or is_day:
		return 1.0
	return time_data.night_item_drop_rate_multiplier


## 디버그 전용 — 게임 시계를 hours(게임 시간)만큼 즉시 앞으로 돌린다.
## (디버그 전투장 F10, scripts/debug/debug_combat_arena.gd)
func debug_jump_hours(hours: float) -> void:
	var real_sec := hours * 3600.0 * time_data.real_seconds_per_game_day / GAME_SECONDS_PER_DAY
	advance_time(real_sec)


## 테스트 전용 — GUT 테스트 간 상태 오염 방지(오토로드는 전체 테스트 실행 동안 하나만
## 존재한다). 시그널은 발신하지 않는다(리셋은 상태 초기화이지 실제 낮/밤 전환이 아니다).
func reset() -> void:
	_elapsed_real_sec_in_day = 0.0
	day_number = 1
	is_day = true
