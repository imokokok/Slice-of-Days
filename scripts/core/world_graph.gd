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
	if from == destination: return "你已经在这里。"
	var names := {"main_street":"主街","residential":"住宅区","cultural_street":"文化街","lookout_route":"海边观景路线"}
	return str(names.get(str(segment_for(destination).id),"小镇"))+"
选择步行或打车前往。"

func legacy_segment_for(location: String) -> Dictionary:
	var segments: Array = config.get("legacy_segments", [])
	for segment in segments:
		if segment.locations.has(location): return segment
	return segments[0] if not segments.is_empty() else {}

func walk_minutes(from: String, destination: String) -> int:
	return maxi(0,TravelSystem._shortest_walk_minutes(from,destination))
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
