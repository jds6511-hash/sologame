## 디버그 레벨 점프 키 (M3) — 상위 레벨 콘텐츠를 정상 플레이 시간 없이 확인하기 위한 도구.
##
## 필요 이유: 전직은 Lv10(약 1.8시간), 2차 전직은 Lv40(약 31.5시간) 지점이라(jobs.md 1장)
## 게이트 세션에서 정상 플레이로는 상위 콘텐츠에 도달할 수 없다. `PlayerProgression.add_exp`
## (B-1 공개 API)에 필요한 경험치를 한 번에 넣어 레벨을 끌어올린다 — 다중 레벨업은
## PlayerProgression이 내부 while 루프로 정상 처리하므로(spec 8-2) 레벨업 시그널·스탯 성장·
## 스킬 포인트 지급·전직 가능 판정이 모두 정상 경로로 발생한다.
##
## 키는 raw keycode로 처리한다 — 입력 액션을 추가하려면 project.godot를 고쳐야 하는데 그
## 파일은 다른 작업과 충돌하기 때문이다(player_job_transition.gd의 디버그 키와 동일 방식).
## 이미 쓰이는 디버그 키(디버그 전투장 F1~F10, 전직 실행 F11~F12)와 겹치지 않도록 함수키를
## 피해 Page Up으로 잡았다.
##
## HUD 씬의 자식으로 두고 HUD가 bind_progression으로 배선한다 — progression·player 씬을
## 고치지 않기 위한 배치다(UI 도메인 안에서만 해결).
class_name DebugLevelKeys
extends Node

## Page Up = +1 레벨. Shift와 함께 누르면 BULK_LEVEL_COUNT 레벨.
const LEVEL_UP_KEYCODE := KEY_PAGEUP
const BULK_LEVEL_COUNT := 10

## 끄면 키 입력을 완전히 무시한다(정식 빌드·플레이 테스트용).
@export var enabled: bool = true

var _progression: PlayerProgression = null


## progression: player.tscn의 "PlayerProgression" 자식. null이면 키가 아무 일도 하지 않는다.
func bind_progression(progression: PlayerProgression) -> void:
	_progression = progression


func _unhandled_key_input(event: InputEvent) -> void:
	if not enabled or _progression == null:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_pressed() or key_event.is_echo():
		return
	if key_event.keycode != LEVEL_UP_KEYCODE:
		return
	grant_levels(BULK_LEVEL_COUNT if key_event.shift_pressed else 1)
	get_viewport().set_input_as_handled()


## 현재 레벨에서 count 레벨만큼 올린다. 레벨당 남은 요구 경험치를 정확히 넣는 방식이라
## 레벨 곡선(LevelCurve)의 내부 수식에 의존하지 않는다. 만렙에 닿으면 그 자리에서 멈춘다.
func grant_levels(count: int) -> void:
	if _progression == null:
		return
	for _i in count:
		if _progression.is_max_level():
			break
		_progression.add_exp(_progression.exp_to_next())
	print(
		(
			"[디버그] 레벨 점프 → Lv%d (Page Up = +1레벨, Shift+Page Up = +%d레벨)"
			% [_progression.current_level, BULK_LEVEL_COUNT]
		)
	)
