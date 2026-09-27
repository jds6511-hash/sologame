## 엔진의 실제 리소스 결과를 Python 계산기와 대조할 임시 JSON으로 출력한다.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var current = load("res://data/progression/level_curve.tres")
	var legacy = load("res://test/save/legacy_level_curve.tres")
	var result := {"c1": [], "legacy": [], "mob": [], "ties": [-2.5, 0.5, 2.5], "rounded": []}
	for level in range(1, 100):
		result.c1.append(current.req(level))
		result.legacy.append(legacy.req(level))
	for level in range(1, 101):
		result.mob.append(current.mob_exp(level))
	for value in result.ties:
		result.rounded.append(roundi(value))
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(result))
	file.close()
	print("C1_CURVE_EXPORT_PASS")
	quit(0)
