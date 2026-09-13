extends Node
var config: Dictionary = {}
func _ready() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/town_graph.json"))
func segment_for(location: String) -> Dictionary:
	for segment in config.get("segments", []):
		if segment.locations.has(location): return segment
	return config.segments[0]
func neighbours(location: String) -> Array:
	return TravelSystem.adjacency.get(location, [])
func pins() -> Array:
	return GameState.shared_state.get("pins_" + GameState.current_role, [])
func toggle_pin(location: String) -> void:
	var list := pins().duplicate()
	if list.has(location): list.erase(location)
	else: list.append(location)
	GameState.shared_state["pins_" + GameState.current_role] = list
	SaveManager.save_game()
