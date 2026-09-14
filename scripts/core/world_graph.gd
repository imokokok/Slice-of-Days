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
	for segment in config.get("segments", []):
		if segment.locations.has(location): return segment
	return config.segments[0]

const JUNCTION_X := 5600.0

func location_x(location: String) -> float:
	var route := segment_for(location)
	var offset := float(route.get("offset", 0))
	return offset + (route.locations.find(location) + 0.5) * (float(route.width) - offset) / route.locations.size()

func walking_distance(from: String, destination: String, from_x := -1.0) -> float:
	var a := segment_for(from)
	var b := segment_for(destination)
	var ax := location_x(from) if from_x < 0 else from_x
	var bx := location_x(destination)
	if a.id == b.id: return absf(ax - bx)
	var a_entry := 8000.0 if a.id == "lookout_route" else JUNCTION_X
	var b_entry := 8000.0 if b.id == "lookout_route" else JUNCTION_X
	if a.id == "main_street": return absf(ax - b_entry) + bx
	if b.id == "main_street": return ax + absf(a_entry - bx)
	return ax + absf(a_entry - b_entry) + bx

func directions(from: String, destination: String) -> String:
	var a := segment_for(from)
	var b := segment_for(destination)
	if a.id == b.id: return "沿路往右" if location_x(destination) > location_x(from) else "沿路往左"
	var prefix := "先往左回到主街，" if a.id != "main_street" else ""
	match str(b.id):
		"residential": return prefix + "在主街拱门路口向上进入住宅区"
		"cultural_street": return prefix + "在主街拱门路口向下进入文化街"
		"lookout_route": return prefix + "经过社区中心，继续向右走到海边"
	return prefix + "沿主街找到" + TravelSystem.location_name(destination)

func legacy_segment_for(location: String) -> Dictionary:
	var segments: Array = config.get("legacy_segments", [])
	for segment in segments:
		if segment.locations.has(location): return segment
	return segments[0] if not segments.is_empty() else {}

func walk_minutes(from: String, destination: String) -> int:
	return int(ceil(walking_distance(from, destination) / 300.0 / 4.0))
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
