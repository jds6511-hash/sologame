extends RefCounted

const Rules = preload("res://scripts/save/save_progression_rules.gd")
const MAX_SIGNED_INT := 9223372036854775807


## codec가 계정 연결을 포함한 원본 스키마 검증 후 호출한다. 파일 쓰기/보상 지급 없음.
static func upgrade(data: Dictionary) -> Dictionary:
	return upgrade_candidate(data)


## 제품과 기존 후보 호출자가 공유하는 순수 V1/V2→V3 변환.
static func upgrade_candidate(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("character_save_version")
	if not _integer_between(version, 1, 3):
		return _failure("unsupported_version")
	var player: Variant = data.get("player")
	if not player is Dictionary:
		return _failure("player_fields")
	var old_rules = Rules.for_version(int(version))
	var new_rules = Rules.for_version(3)
	var level: Variant = player.get("level")
	if not _integer_between(level, 1, old_rules.max_level()):
		return _failure("level_exp")
	var limit: int = 1 if level == old_rules.max_level() else old_rules.req(int(level))
	var exp_value: Variant = player.get("exp")
	if not _integer_between(exp_value, 0, limit - 1):
		return _failure("level_exp")
	var converted := 0
	if level < old_rules.max_level():
		converted = _rescale_exp(int(exp_value), limit, new_rules.req(int(level)))
		if converted < 0:
			return _failure("migration_exp_range")
	# 원본 전체 검증 후 복사한다. V1 예약 필드는 그대로 보존한다.
	var result := {"ok": true, "code": "ok", "data": data.duplicate(true)}
	result.data.character_save_version = 3
	result.data.player.exp = converted
	return result


## 유효 결과는 0 이상. 정수 곱셈 전에 범위를 확인하고 나눗셈은 정수 절삭한다.
static func _rescale_exp(exp_value: int, old_req: int, new_req: int) -> int:
	if old_req <= 0 or new_req <= 0 or exp_value < 0 or exp_value >= old_req:
		return -1
	@warning_ignore("integer_division")
	var max_factor: int = MAX_SIGNED_INT / new_req
	if exp_value > max_factor:
		return -1
	@warning_ignore("integer_division")
	var converted: int = (exp_value * new_req) / old_req
	return converted if converted < new_req else -1


static func _integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(value)
		and value == floor(value)
		and value >= minimum
		and value <= maximum
	)


static func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code, "data": {}}
