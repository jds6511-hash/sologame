extends "res://scripts/economy/economy_candidate.gd"
const ProductRegistry = preload("res://scripts/save/product_content_registry.gd")


func _init() -> void:
	super._init()
	registry = ProductRegistry.new()
	items[registry.NEW_ITEM.item_id] = registry.NEW_ITEM
	registry.items = items
	job_families["sharpshooter"] = "bow"
	catalog.families[registry.NEW_ITEM.item_id] = "bow"
	catalog.prices[registry.NEW_ITEM.item_id] = {
		"buy": registry.NEW_ITEM.price,
		"sell": registry.NEW_ITEM.price / 10,
		"offered": false,
		"source": "경제 정본 B급 무기 산식"
	}


func job_gate(job: String) -> int:
	return 40 if job == "sharpshooter" else super.job_gate(job)
