extends Node
const LOOKOUT_OPEN := 1260
var config: Dictionary = {}
var street_locations: Array[String] = []
func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/town_graph.json"))
	if parsed is Dictionary:
		config = parsed
	else:
		config = {}
		push_error("Invalid town graph data")
	var places = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/locations.json"))
	for place in places.get("locations", []):
		street_locations.append(str(place.id))
func segment_for(location: String) -> Dictionary:
	return {"id": "coast", "locations": street_locations, "anchor": 800}

func legacy_segment_for(location: String) -> Dictionary:
	var segments: Array = config.get("segments", [])
	for segment in segments:
		if segment.locations.has(location): return segment
	return segments[0] if not segments.is_empty() else {}

func walk_minutes(from: String, destination: String) -> int:
	return int(ceil(abs(street_locations.find(from) - street_locations.find(destination)) * 1600.0 / 300.0 / 4.0))
func neighbours(location: String) -> Array:
	return TravelSystem.adjacency.get(location, [])
func pins() -> Array:
	return GameState.shared_state.get("pins_" + GameState.current_role, [])
func toggle_pin(location: String) -> void:
	var list := pins().duplicate()
	if list.has(location): list.erase(location)
	else: list.append(location)
	GameState.shared_state["pins_" + GameState.current_role] = list
	SaveManager.save_or_report("世界状态保存失败")
