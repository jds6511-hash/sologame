## 도시 방문과 이동 견적. 실제 월드 교체 성공 후에만 commit한다.
# gdlint: disable=max-returns
extends RefCounted
const Model = preload("res://scripts/territory/territory_model.gd")
const Content = preload("res://scripts/content/game_content.gd")
const TERRITORY_GATE := Vector2(320, 488)
const JAETGOL_GATE := Vector2(320, 488)
const HOLDING_MAPS := {"yeoulmok": "eastern_frontier_start", "jaetgol": "jaetgol"}
const HOLDING_NAMES := {"yeoulmok": "여울목", "jaetgol": "잿골"}
const CITIES := {
	"novera": {"map_id": "novera_commons", "level": 10, "index": 0},
	"gransia": {"map_id": "gransia", "level": 18, "index": 1},
	"brantel": {"map_id": "brantel", "level": 22, "index": 2},
	"saleno": {"map_id": "saleno", "level": 26, "index": 3},
	"arsel": {"map_id": "arsel", "level": 30, "index": 4},
	"misran": {"map_id": "misran", "level": 34, "index": 5},
	"durgan": {"map_id": "durgan", "level": 40, "index": 6}
}
const SOURCES := {
	"jaetgol": "novera",
	"jaetgol_approach": "novera",
	"pilgrimage_path": "saleno",
	"eastern_frontier_start": "novera",
	"yeoulmok_defense": "novera",
	"novera_gate": "novera",
	"novera_outskirts": "novera",
	"novera_rift": "novera",
	"novera_commons": "novera",
	"han_gilmok": "novera",
	"gransia": "gransia",
	"brantel": "brantel",
	"saleno": "saleno",
	"saleno_coast": "saleno",
	"reed_marsh": "saleno",
	"arsel": "arsel",
	"arsel_library": "arsel",
	"misran": "misran",
	"forest_edge": "misran",
	"mosswood": "misran",
	"sylvien": "misran",
	"durgan": "durgan",
	"iron_mine": "durgan",
	"karndurum": "durgan",
	"frost_pass": "durgan",
	"durgan_training": "durgan"
}
const RETURN_MS := 900000


static func initial(quests: Dictionary, map_id: String) -> Dictionary:
	var data := {"revision": 1, "unlocked": [], "return_ms": 0}
	if Model.completed(quests, "MQ-01-05"):
		data.unlocked.append("novera")
	visit(data, map_id)
	return data


static func visit(data: Dictionary, map_id: String) -> void:
	var city := ""
	if map_id in ["novera_gate", "novera_commons"]:
		city = "novera"
	elif CITIES.has(map_id):
		city = map_id
	if city != "" and city not in data.unlocked:
		data.unlocked.append(city)


static func advance(data: Dictionary, elapsed_ms: int) -> void:
	data.return_ms = maxi(0, int(data.return_ms) - maxi(0, elapsed_ms))


static func validate(data: Variant) -> String:
	if not data is Dictionary or not Model.keys(data, ["revision", "unlocked", "return_ms"]):
		return "travel_structure"
	if not Model.integer(data.revision, 1) or data.revision != 1:
		return "travel_revision"
	if not Model.integer(data.return_ms, RETURN_MS) or not data.unlocked is Array:
		return "travel_counter"
	var seen := []
	for city in data.unlocked:
		if not city is String or not CITIES.has(city) or city in seen:
			return "travel_city"
		seen.append(city)
	return ""


static func quote(
	travel: Dictionary,
	territory: Dictionary,
	source_map: String,
	destination: String,
	reputation: int,
	returning: bool = false
) -> Dictionary:
	var result := {
		"error": "", "cost": 0, "destination": destination, "map_id": "", "returning": returning
	}
	if not SOURCES.has(source_map):
		result.error = "source"
		return result
	if returning:
		if not HOLDING_MAPS.has(destination) or not territory.get("holdings", {}).has(destination):
			result.error = "ownership"
		elif travel.return_ms > 0:
			result.error = "cooldown"
		else:
			result.map_id = HOLDING_MAPS[destination]
		return result
	var holding_id := holding_for_map(source_map)
	if not is_city(source_map) and holding_id == "":
		result.error = "warp_departure"
		return result
	if holding_id != "" and not territory.get("holdings", {}).has(holding_id):
		result.error = "ownership"
		return result
	if is_city(source_map) and SOURCES[source_map] not in travel.unlocked:
		result.error = "locked"
		return result
	if not CITIES.has(destination) or destination not in travel.unlocked:
		result.error = "locked"
		return result
	result.map_id = CITIES[destination].map_id
	if source_map == result.map_id:
		result.error = "same_destination"
		return result
	var distance := absi(int(CITIES[SOURCES[source_map]].index) - int(CITIES[destination].index))
	var coefficient := 25 if distance <= 1 else (40 if distance == 2 else 60)
	var discount := 1.0
	if reputation >= 7500:
		discount = 0.0
	elif reputation >= 5500:
		discount = 0.7
	elif reputation >= 500:
		discount = 0.9
	var unit := roundi(2.0 * pow(float(CITIES[destination].level), 1.5))
	result.cost = int(ceil(coefficient * unit * discount))
	return result


static func is_city(map_id: String) -> bool:
	for city in CITIES.values():
		if city.map_id == map_id:
			return true
	return false


static func departure_error(map_id: String, position: Vector2, territory: Dictionary) -> String:
	var holding_id := holding_for_map(map_id)
	if holding_id != "":
		if not territory.get("holdings", {}).has(holding_id):
			return "ownership"
		return "" if position.distance_to(TERRITORY_GATE) <= 40.0 else "warp_departure"
	if not is_city(map_id):
		return "warp_departure"
	return "" if position.distance_to(Content.WARP_ARRIVALS[map_id]) <= 40.0 else "warp_departure"


static func commit(travel: Dictionary, economy: Dictionary, offer: Dictionary) -> String:
	if offer.get("error", "invalid") != "":
		return offer.get("error", "invalid")
	if not Model.integer(offer.get("cost"), Model.LIMIT):
		return "cost"
	if economy.gold < offer.cost:
		return "gold"
	if offer.returning and travel.return_ms > 0:
		return "cooldown"
	economy.gold -= offer.cost
	if offer.returning:
		travel.return_ms = RETURN_MS
	return ""


static func holding_for_map(map_id: String) -> String:
	for holding_id in HOLDING_MAPS:
		if HOLDING_MAPS[holding_id] == map_id:
			return holding_id
	return ""
