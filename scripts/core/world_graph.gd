extends Node
var config: Dictionary = {}
func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/town_graph.json"))
	if parsed is Dictionary:
		config = parsed
	else:
		config = {}
		push_error("Invalid town graph data")
func segment_for(location: String) -> Dictionary:
	var segments: Array = config.get("segments", [])
	for segment in segments:
		if segment.locations.has(location): return segment
	return segments[0] if not segments.is_empty() else {}
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
