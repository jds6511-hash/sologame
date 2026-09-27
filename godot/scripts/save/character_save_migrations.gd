extends RefCounted


## codec가 계정 연결을 포함한 원본 스키마 검증 후 호출한다. 파일 쓰기/보상 지급 없음.
static func upgrade(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("character_save_version")
	if (
		not (version is int or version is float)
		or not is_finite(version)
		or version != floor(version)
		or int(version) not in [1, 2]
	):
		return {"ok": false, "code": "unsupported_version", "data": {}}
	var upgraded := data.duplicate(true)
	upgraded.character_save_version = 2
	return {"ok": true, "code": "ok", "data": upgraded}
