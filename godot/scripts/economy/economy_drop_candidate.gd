extends DropSystem


func _load_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	result.assign(preload("res://scripts/economy/economy_candidate.gd").new().items.values())
	return result


func current_weapon_series_prefix() -> String:
	var job: String = get_parent().get_node("Player/PlayerJobTransition").current_job_id
	return (
		{"adventurer": "WPN-SW-", "warrior": "WPN-GS-", "archer": "WPN-BW-", "gladiator": "WPN-GS-"}
		. get(job, "unsupported:")
	)
