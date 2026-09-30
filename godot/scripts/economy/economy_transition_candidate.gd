extends PlayerJobTransition


func can_transition(job_id: StringName) -> bool:
	if not super.can_transition(job_id):
		return false
	if not get_parent().has_meta("economy_candidate"):
		return true
	var runtime = get_parent().get_meta("economy_candidate")
	var next: Dictionary = runtime.state()
	var previous: String = next.equipment.weapon
	return previous == "" or runtime.model.add(next.bag, previous, 1)
