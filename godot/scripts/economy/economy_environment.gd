## 검토용 격리 환경. 기본 프로젝트와 V4 파일을 바꾸지 않는다.
extends RefCounted

const BaseCodec = preload("res://scripts/save/character_save_codec.gd")
const BaseSchema = preload("res://scripts/save/save_schema.gd")
const BaseStore = preload("res://scripts/save/save_file_store.gd")
const BaseSession = preload("res://scripts/save/save_session.gd")
const BaseWorld = preload("res://scripts/world/eastern_frontier_starting_area.gd")
const SaveCandidate = preload("res://scripts/economy/economy_save_candidate.gd")
const Runtime = preload("res://scripts/economy/economy_runtime.gd")


static func instantiate_world(region: String = "eastern_frontier_start") -> Node:
	var world = load(load("res://scripts/world/region_registry.gd").SCENES[region]).instantiate()
	world.set_script(CandidateWorld)
	world.map_id = region
	var growth = world.get_node("Player/PlayerStatGrowth")
	var values := [growth.job, growth.formula, growth.combat_stats]
	growth.set_script(load("res://scripts/economy/economy_growth_candidate.gd"))
	growth.job = values[0]
	growth.formula = values[1]
	growth.combat_stats = values[2]
	var transition = world.get_node("Player/PlayerJobTransition")
	var jobs := [transition.available_jobs, transition.tier2_jobs]
	transition.set_script(load("res://scripts/economy/economy_transition_candidate.gd"))
	transition.available_jobs = jobs[0]
	transition.tier2_jobs = jobs[1]
	world.get_node("Player/Inventory").set_script(
		load("res://scripts/economy/economy_inventory_candidate.gd")
	)
	var drops = world.get_node("DropSystem")
	var drop_values := [drops.rate_config, drops.world_item_scene, drops.job_transition]
	drops.set_script(load("res://scripts/economy/economy_drop_candidate.gd"))
	drops.rate_config = drop_values[0]
	drops.world_item_scene = drop_values[1]
	drops.job_transition = drop_values[2]
	return world


class CandidateSchema:
	extends BaseSchema
	var conversion = SaveCandidate.new()

	func _init() -> void:
		registry.items = conversion.model.items

	func character_error(data: Dictionary, account: Dictionary) -> String:
		return conversion.validate(data, account)


class CandidateCodec:
	extends BaseCodec

	func _init() -> void:
		schema = CandidateSchema.new()
		registry = schema.registry

	func character_version() -> int:
		return 5

	func prepare_loaded(data: Dictionary, account: Dictionary) -> Dictionary:
		return schema.conversion.upgrade(data, account)

	func capture(player: Node2D, account_id: String, carry: Dictionary = {}) -> Dictionary:
		var data := super.capture(player, account_id, carry)
		data.inventory.overflow = player.get_meta("economy_candidate").overflow.duplicate(true)
		return data

	func restore_into(player: Node2D, data: Dictionary, account: Dictionary) -> String:
		var error := super.restore_into(player, data, account)
		if error != "":
			return error
		var runtime := Runtime.new()
		runtime.name = "Economy"
		player.add_child(runtime)
		runtime.install(player, false)
		runtime.overflow = data.inventory.overflow.duplicate(true)
		return ""


class CandidateStore:
	extends BaseStore

	func current_version(kind: String) -> int:
		return 5 if kind == "character" else 1

	func supported_versions(kind: String) -> Array:
		return [1, 2, 3, 4, 5] if kind == "character" else [1]


class CandidateSession:
	extends BaseSession

	func _init() -> void:
		codec = CandidateCodec.new()

	func setup(owner_world: Node) -> String:
		var directory: String = owner_world.get_meta("save_directory", "")
		if not directory.begins_with("user://m6_candidate_") or ".." in directory:
			return "candidate_directory"
		return super.setup(owner_world)

	func _create_store(directory: String) -> RefCounted:
		return CandidateStore.new(directory)

	func _instantiate_world() -> Node:
		return load("res://scripts/economy/economy_environment.gd").instantiate_world(_destination)

	func save_slot(slot: int) -> Dictionary:
		if world.get_node("Player").get_meta("economy_candidate").busy:
			return _failure("transaction_busy")
		return super.save_slot(slot)

	func travel(destination: String) -> Dictionary:
		if world.get_node("Player").get_meta("economy_candidate").busy:
			return _failure("transaction_busy")
		return super.travel(destination)

	func _change_blocked() -> bool:
		return (
			world.get_node("Player").get_meta("economy_candidate").busy or super._change_blocked()
		)


class CandidateWorld:
	extends BaseWorld

	func _create_save_session() -> Node:
		return CandidateSession.new()

	func _ready() -> void:
		super._ready()
		if String(get_meta("save_boot_error", "")) != "":
			return
		var actor := get_node("Player")
		if not actor.has_meta("economy_candidate"):
			var runtime := Runtime.new()
			runtime.name = "Economy"
			actor.add_child(runtime)
			runtime.install(actor, true)
		var panel = load("res://scripts/economy/economy_panel.gd").new()
		panel.name = "EconomyPanel"
		add_child(panel)
		panel.setup(actor.get_meta("economy_candidate"))
		var hint := Label.new()
		hint.position = Vector2(40, 250)
		hint.text = "M6 후보 · 가방 [B]\n상점: MQ01~05 후 노베라 입구 보급상 [F]\n지도 [M] · 설정/종료 [Esc]"
		UiStyle.apply_label_font(hint, 24)
		hint.add_theme_constant_override("outline_size", 6)
		hint.add_theme_color_override("font_outline_color", Color.BLACK)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(hint)
		if map_id == "novera_gate":
			var merchant = load("res://scripts/economy/economy_merchant.gd").new()
			merchant.name = "Merchant"
			merchant.position = Vector2(216, 440)
			add_child(merchant)
			merchant.configure(actor, panel)
			get_node("WorldInteraction").candidates.append(merchant)
