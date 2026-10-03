extends PlayerJobTransition


func can_transition(job_id: StringName) -> bool:
	if not super.can_transition(job_id):
		return false
	if not trial_error(job_id).is_empty():
		return false
	if not get_parent().has_meta("economy_candidate"):
		return true
	var runtime = get_parent().get_meta("economy_candidate")
	var next: Dictionary = runtime.state()
	var previous: String = next.equipment.weapon
	return previous == "" or runtime.model.add(next.bag, previous, 1)


func trial_error(job_id: StringName) -> String:
	var required: String = {"gladiator": "TR-WAR-02", "sharpshooter": "TR-ARC-02"}.get(job_id, "")
	if required.is_empty():
		return ""
	var quests := get_parent().get_parent().get_node_or_null("QuestController")
	# 동결 후보/단독 전투장은 시련 카탈로그를 사용하지 않는다.
	if quests == null or not quests.journal.catalog.definitions.has(required):
		return ""
	var state: Dictionary = quests.journal.export_state().get(required, {})
	return "두르간 훈련장에서 계열 시련을 마치세요" if state.get("state", "") != "completed" else ""
