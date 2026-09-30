## 같은 레벨/직업에서 가상B 기준선과 실착C를 비교한다. 실제 TTK/체감 측정은 아니다.
extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var model = load("res://scripts/economy/economy_candidate.gd").new()
	var rows := []
	var max_ttk := 0.0
	var max_incoming := 0.0
	var combinations := 0
	for job in ["adventurer", "warrior", "archer", "gladiator"]:
		for level in range(model.job_gate(job), 101):
			var old = model.registry.max_stats(level, job)
			var current = model.stats(level, job, model.starter(level, job))
			var naked: Dictionary = model.starter(level, job)
			for slot in naked:
				naked[slot] = ""
			var bare = model.stats(level, job, naked)
			max_ttk = maxf(max_ttk, old.attack_power / current.attack_power)
			max_incoming = maxf(max_incoming, (100 + old.defense) / (100 + current.defense))
			combinations += 1
			if level in [1, 10, 20, 40, 80, 100]:
				rows.append(
					{
						"job": job,
						"level": level,
						"old_attack": old.attack_power,
						"c_attack": current.attack_power,
						"bare_attack": bare.attack_power,
						"old_defense": old.defense,
						"c_defense": current.defense,
						"bare_defense": bare.defense
					}
				)
	var output := "res://../docs/qa/screenshots/m6-balance.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"combinations": combinations,
				"max_attack_only_ttk_ratio": max_ttk,
				"max_incoming_ratio": max_incoming,
				"rows": rows
			},
			"\t"
		)
	)
	file.close()
	print(
		"M6_BALANCE: ", combinations, " / 공격력만의 TTK비 상한 ", max_ttk, " / 방어만의 피격비 상한 ", max_incoming
	)
	quit(0)
