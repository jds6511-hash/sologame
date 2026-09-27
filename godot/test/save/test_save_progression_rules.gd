extends GutTest

const Codec = preload("res://scripts/save/character_save_codec.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
const Rules = preload("res://scripts/save/save_progression_rules.gd")
var codec: RefCounted
var account: Dictionary
var data: Dictionary


class MissingJobRules:
	extends Rules.Legacy

	func transition_level(_job_id: String) -> int:
		return -1


func before_each() -> void:
	codec = Codec.new()
	account = codec.new_account()
	var player = PLAYER.instantiate()
	var inventory := InventoryComponent.new()
	inventory.name = "Inventory"
	player.add_child(inventory)
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	data = codec.capture(player, account.account_id)
	data.character_save_version = 2
	data.player.level = 20
	data.player.skill_points = 19
	data.player.exp = 50000


func after_each() -> void:
	GameClock.reset()


func test_legacy_validation_does_not_follow_runtime_curve_or_points() -> void:
	var curve = codec.registry.CURVE
	var rule = codec.registry.RULE
	var original_coefficient: float = curve.req_coefficient
	var original_points: int = rule.points_per_level
	curve.req_coefficient = 1.0
	var result: String = codec.schema.character_error(data, account)
	curve.req_coefficient = original_coefficient
	rule.points_per_level = 7
	var points_result: String = codec.schema.character_error(data, account)
	rule.points_per_level = original_points
	assert_eq(result, "", "구 저장 검증은 런타임 리소스 변경과 독립")
	assert_eq(points_result, "", "스킬 예산도 런타임 규칙 변경과 독립")


func test_candidate_alternates_versions_without_changing_product_acceptance() -> void:
	assert_true(codec.schema.has_method("candidate_character_error"))
	if not codec.schema.has_method("candidate_character_error"):
		return
	var original := data.duplicate(true)
	for version in [3, 2, 1, 3, 1, 2]:
		data.character_save_version = version
		assert_eq(
			codec.schema.candidate_character_error(data, account),
			"exp_overflow" if version == 3 else ""
		)
	data.character_save_version = 3
	data.player.exp = 0
	assert_eq(codec.schema.candidate_character_error(data, account), "")
	assert_true(codec.prepare_loaded(data, account).ok)
	data.character_save_version = 2
	data.player.exp = 50000
	assert_eq(data, original, "검증은 payload를 변환하지 않는다")


func test_candidate_quests_validate_ids_states_counts_and_prerequisites() -> void:
	assert_true(codec.schema.has_method("candidate_character_error"))
	if not codec.schema.has_method("candidate_character_error"):
		return
	data.player.exp = 0
	var cases := [
		[{"MQ-01-99": {"state": "active", "counts": [0]}}, "unknown_quest"],
		[{"MQ-01-01": {"state": "bogus", "counts": [0, 0]}}, "quest_state"],
		[{"MQ-01-01": {"state": "active", "counts": [999, 0]}}, "quest_counts"],
		[{"MQ-01-02": {"state": "active", "counts": [0]}}, "quest_prerequisite"],
		[{"MQ-01-01": {"state": "completed", "counts": [1, 1]}}, ""]
	]
	for version in [2, 3]:
		data.character_save_version = version
		for entry in cases:
			data.progress.quests = entry[0]
			assert_eq(codec.schema.candidate_character_error(data, account), entry[1])
	data.character_save_version = 1
	assert_eq(codec.schema.candidate_character_error(data, account), "reserved_progress")


func test_frozen_tables_match_engine_rounding_for_all_levels() -> void:
	var legacy = Rules.for_version(2)
	var candidate = Rules.for_version(3)
	var early_total := 0
	var c1_total := 0
	for level in range(1, 100):
		assert_eq(
			legacy.req(level),
			load("res://test/save/legacy_level_curve.tres").req(level),
			"구 REQ %d" % level
		)
		var multiplier := 0.45 if level < 10 else 1.0
		if level > 10:
			multiplier = pow(0.4, float(level - 10) / 10.0) if level < 20 else 0.4
		var expected := roundi(55.0 * pow(float(level), 2.5) * multiplier)
		assert_eq(candidate.req(level), expected, "C1 REQ %d" % level)
		assert_eq(Rules.for_version(1).req(level), legacy.req(level))
		c1_total += candidate.req(level)
		if level < 10:
			early_total += candidate.req(level)
	assert_eq(early_total, 18612)
	assert_eq(c1_total, 61860102)
	assert_null(Rules.for_version(4))
	for level in [0, -1, 100, 101]:
		assert_eq(legacy.req(level), 0)
		assert_eq(candidate.req(level), 0)


func test_all_versions_exp_boundaries_and_level_cap() -> void:
	for version in [1, 2, 3]:
		data.character_save_version = version
		var rules = Rules.for_version(version)
		for level in range(1, 101):
			data.player.level = level
			data.player.skill_points = level - 1
			var limit: int = 1 if level == 100 else rules.req(level)
			for exp_value in [0, limit - 1]:
				data.player.exp = exp_value
				assert_eq(codec.schema.candidate_character_error(data, account), "")
			data.player.exp = limit
			assert_eq(codec.schema.candidate_character_error(data, account), "exp_overflow")
		data.player.level = 101
		assert_eq(codec.schema.candidate_character_error(data, account), "level_exp")


func test_jobs_vitals_and_spent_points_unchanged_across_versions() -> void:
	for job in ["adventurer", "warrior", "archer", "gladiator"]:
		data.player.job_id = job
		data.player.level = 40
		data.player.exp = 0
		data.player.spent_points = 2
		data.player.skill_levels = {"skill_slot1_strike": 3}
		data.player.skill_costs = {"skill_slot1_strike": 2}
		data.player.skill_points = 37 + 2 * codec.registry.tier(job)
		for version in [3, 1, 2]:
			data.character_save_version = version
			var snapshot := data.duplicate(true)
			assert_eq(codec.schema.candidate_character_error(data, account), "", job)
			assert_eq(data, snapshot)
			data.player.skill_costs.skill_slot1_strike = 1
			assert_eq(codec.schema.candidate_character_error(data, account), "skill_cost")
			data.player.skill_costs.skill_slot1_strike = 2
			data.player.hp = 999999
			assert_eq(codec.schema.candidate_character_error(data, account), "vitals")
			data.player.hp = snapshot.player.hp


func test_candidate_keeps_identity_transfer_and_content_blocks() -> void:
	data.player.exp = 0
	data.character_save_version = 3
	var snapshot := data.duplicate(true)
	data.account_id = "f".repeat(32)
	assert_eq(codec.schema.candidate_character_error(data, account), "account_mismatch")
	data = snapshot.duplicate(true)
	data.pending_transfer = {}
	assert_eq(codec.schema.candidate_character_error(data, account), "pending_transfer")
	data = snapshot.duplicate(true)
	for version in [0, -1, 4, 1e30]:
		data.character_save_version = version
		assert_eq(codec.schema.candidate_character_error(data, account), "unsupported_version")
	data = snapshot.duplicate(true)
	for exp_value in [-1, 0.5, INF, NAN]:
		data.player.exp = exp_value
		assert_eq(codec.schema.candidate_character_error(data, account), "level_exp")
	data = snapshot.duplicate(true)
	var definition = codec.schema.quest_catalog.definitions["MQ-01-02"].duplicate(true)
	definition.reward_exp = -1
	codec.schema.quest_catalog.definitions["MQ-01-02"] = definition
	assert_eq(codec.schema.candidate_character_error(data, account), "quest_content_error")


func test_json_numeric_versions_keep_validation_after_decode() -> void:
	data.player.exp = 0
	for version in [1, 2, 3]:
		data.character_save_version = version
		var decoded: Dictionary = JSON.parse_string(JSON.stringify(data))
		assert_eq(codec.schema.candidate_character_error(decoded, account), "")
		assert_eq(codec.schema.character_error(decoded, account), "")


func test_missing_snapshot_job_gate_fails_closed() -> void:
	data.player.job_id = "warrior"
	data.player.skill_points = 21
	assert_eq(codec.schema.player_error(data.player, MissingJobRules.new()), "unknown_job")
	var registered: Array = codec.registry.JOBS.keys()
	var frozen: Array = Rules.Legacy.JOB_LEVELS.keys()
	registered.sort()
	frozen.sort()
	assert_eq(frozen, registered, "새 직업 등록 시 저장 규칙 누락 금지")
