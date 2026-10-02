extends RefCounted
## 의뢰 선택은 저널별 세션 UI 상태이며 저장 진행과 카탈로그 정의에 포함하지 않는다.


static func selected_id(journal: QuestJournal) -> String:
	return String(journal.get_meta("selected_quest_id", ""))


static func select_quest(journal: QuestJournal, id: String) -> bool:
	if id not in journal.catalog.available_ids(journal.export_state()):
		return false
	journal.set_meta("selected_quest_id", id)
	journal.changed.emit()
	return true
