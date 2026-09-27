extends GutTest

const Codec = preload("res://scripts/save/character_save_codec.gd")
const Rules = preload("res://scripts/save/save_progression_rules.gd")
const Migrations = preload("res://scripts/save/character_save_migrations.gd")
const Schema = preload("res://scripts/save/save_schema.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
var codec: RefCounted
var account: Dictionary
var data: Dictionary


class RejectConvertedSchema:
	extends Schema

	func character_error(payload: Dictionary, owner: Dictionary) -> String:
		if payload.character_save_version == 3:
			return "vitals"
		return super.character_error(payload, owner)


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


func test_old_exp_converts_but_claimed_v3_does_not() -> void:
	assert_true(codec.has_method("prepare_candidate_loaded"))
	if not codec.has_method("prepare_candidate_loaded"):
		return
	var snapshot := data.duplicate(true)
	var result: Dictionary = codec.prepare_candidate_loaded(data, account)
	assert_true(result.ok)
	if not result.ok:
		return
	assert_eq(result.data.character_save_version, 3)
	assert_eq(result.data.player.exp, 20000)
	assert_eq(data, snapshot)
	assert_eq(codec.prepare_candidate_loaded(result.data, account).data, result.data)
	data.character_save_version = 3
	assert_eq(codec.prepare_candidate_loaded(data, account).code, "exp_overflow")
	assert_eq(codec.prepare_loaded(result.data, account).data, result.data)


func test_invalid_source_is_not_repaired_by_conversion() -> void:
	assert_true(codec.has_method("prepare_candidate_loaded"))
	if not codec.has_method("prepare_candidate_loaded"):
		return
	for exp_value in [-1, 0.5, INF, NAN, 98387]:
		data.player.exp = exp_value
		var result: Dictionary = codec.prepare_candidate_loaded(data, account)
		assert_false(result.ok)
		assert_eq(result.data, {})
	data.player.exp = 50000
	data.character_save_version = 1
	data.progress.quests = {"MQ-01-01": {"state": "active", "counts": [0, 0]}}
	assert_eq(codec.prepare_candidate_loaded(data, account).code, "reserved_progress")


func test_every_level_preserves_integer_ratio_and_early_exp() -> void:
	var old_rules = Rules.for_version(2)
	var new_rules = Rules.for_version(3)
	for version in [1, 2]:
		data.character_save_version = version
		for level in range(1, 100):
			data.player.level = level
			data.player.skill_points = level - 1
			var old_req: int = old_rules.req(level)
			var new_req: int = new_rules.req(level)
			for exp_value in [0, 1, old_req - 1]:
				data.player.exp = exp_value
				var snapshot := data.duplicate(true)
				var result: Dictionary = codec.prepare_loaded(data, account)
				assert_true(result.ok)
				if not result.ok:
					return
				var converted: int = result.data.player.exp
				assert_lt(converted, new_req)
				# floor 조건을 곱셈 부등식으로 검사한다. 같은 나눗셈 구현을 반복하지 않는다.
				assert_lte(converted * old_req, exp_value * new_req)
				assert_gt((converted + 1) * old_req, exp_value * new_req)
				if level <= 10:
					assert_eq(converted, exp_value)
				assert_eq(data, snapshot)
				var expected := snapshot.duplicate(true)
				expected.character_save_version = 3
				expected.player.exp = converted
				assert_eq(result.data, expected)


func test_max_level_zero_and_candidate_idempotence_after_json() -> void:
	for version in [1, 2, 3]:
		data.character_save_version = version
		data.player.level = 100
		data.player.skill_points = 99
		data.player.exp = 0
		var decoded: Dictionary = JSON.parse_string(JSON.stringify(data))
		var result: Dictionary = codec.prepare_loaded(decoded, account)
		assert_true(result.ok)
		assert_eq(result.data.player.exp, 0)
		var second: Dictionary = codec.prepare_loaded(result.data, account)
		assert_eq(second.data, result.data)
		second.data.inventory.gold = 7
		assert_eq(result.data.inventory.gold, decoded.inventory.gold)
		decoded.player.exp = 1
		assert_eq(codec.prepare_loaded(decoded, account).code, "exp_overflow")


func test_four_jobs_equipment_and_quest_states_preserve_every_other_field() -> void:
	data.player.level = 40
	data.player.exp = 50000
	data.player.spent_points = 2
	data.player.skill_levels = {"skill_slot1_strike": 3}
	data.player.skill_costs = {"skill_slot1_strike": 2}
	data.inventory.gold = 456
	data.inventory.bag = [{"item_id": "POT-HP-1", "quantity": 3}]
	for slot in codec.registry.slots:
		for item in codec.registry.items.values():
			if item.equip_slot == codec.registry.slots[slot]:
				data.inventory.equipment[slot] = item.item_id
				break
	data.world.position = [101.25, 45.5]
	data.world.day_number = 7
	data.world.elapsed_real_sec_in_day = 129.0
	for job in ["adventurer", "warrior", "archer", "gladiator"]:
		data.player.job_id = job
		data.player.skill_points = 37 + 2 * codec.registry.tier(job)
		for state in ["active", "ready", "completed"]:
			data.progress.quests = {
				"MQ-01-01": {"state": "completed", "counts": [1, 1]},
				"MQ-01-02": {"state": "completed", "counts": [2]},
				"MQ-01-03": {"state": state, "counts": [1 if state == "active" else 2]}
			}
			var snapshot := data.duplicate(true)
			var result: Dictionary = codec.prepare_loaded(data, account)
			assert_true(result.ok)
			if not result.ok:
				return
			var expected := snapshot.duplicate(true)
			expected.character_save_version = 3
			expected.player.exp = result.data.player.exp
			assert_eq(result.data, expected)
			assert_eq(data, snapshot)
			result.data.progress.quests["MQ-01-03"].counts[0] = 0
			result.data.inventory.bag[0].quantity = 1
			assert_eq(data, snapshot, "중첩 컨테이너 공유 금지")


func test_post_conversion_validation_is_required() -> void:
	codec.schema = RejectConvertedSchema.new()
	var snapshot := data.duplicate(true)
	var result: Dictionary = codec.prepare_loaded(data, account)
	assert_false(result.ok)
	assert_eq(result.code, "vitals")
	assert_eq(result.data, {})
	assert_eq(data, snapshot)


func test_integer_arithmetic_and_overflow_guards() -> void:
	assert_eq(Migrations._rescale_exp(50000, 98387, 39355), 20000)
	assert_eq(Migrations._rescale_exp(9007199254740992, 9007199254740993, 1), 0)
	assert_eq(Migrations._rescale_exp(4611686018427387903, 9223372036854775807, 2), 0)
	assert_eq(Migrations._rescale_exp(4611686018427387904, 9223372036854775807, 2), -1)
	for args in [[0, 0, 1], [0, 1, 0], [-1, 5, 2], [5, 5, 2], [1, 5, -1]]:
		assert_eq(Migrations._rescale_exp(args[0], args[1], args[2]), -1)


func test_direct_migration_rejects_bad_arithmetic_inputs() -> void:
	for payload in [
		{},
		{"character_save_version": 1e30},
		{"character_save_version": 3, "player": []},
		{"character_save_version": 2, "player": {"level": 101, "exp": 0}},
		{"character_save_version": 2, "player": {"level": 20, "exp": 1e30}}
	]:
		var result: Dictionary = Migrations.upgrade_candidate(payload)
		assert_false(result.ok)
		assert_eq(result.data, {})


func test_source_protections_and_product_v3_conversion() -> void:
	var original := data.duplicate(true)
	var account_snapshot := account.duplicate(true)
	var expected := original.duplicate(true)
	expected.character_save_version = 3
	expected.player.exp = 20000
	assert_eq(codec.prepare_loaded(data, account).data, expected)
	assert_eq(data, original)
	for version in [0, -1, 4, 1e30]:
		data.character_save_version = version
		assert_eq(codec.prepare_candidate_loaded(data, account).code, "unsupported_version")
	data = original.duplicate(true)
	data.pending_transfer = {}
	assert_eq(codec.prepare_candidate_loaded(data, account).code, "pending_transfer")
	data = original.duplicate(true)
	data.account_id = "f".repeat(32)
	assert_eq(codec.prepare_candidate_loaded(data, account).code, "account_mismatch")
	data = original.duplicate(true)
	data.progress.quests = {"MQ-01-99": {"state": "active", "counts": [0]}}
	assert_eq(codec.prepare_candidate_loaded(data, account).code, "unknown_quest")
	assert_eq(account, account_snapshot)
