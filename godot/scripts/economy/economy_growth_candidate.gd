extends PlayerStatGrowth


func recompute_stats(level: int) -> void:
	var actor := get_parent()
	if actor.has_meta("economy_candidate"):
		actor.get_meta("economy_candidate").recompute()
	else:
		super.recompute_stats(level)
