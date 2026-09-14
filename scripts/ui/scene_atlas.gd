extends RefCounted
## Original scene plates extracted from the user's 99-page reference atlas.
static var data: Dictionary = {}
static var textures: Dictionary = {}
static func catalog() -> Dictionary:
	if data.is_empty(): data = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/scene_atlas.json"))
	return data
static func street(place: String) -> Dictionary:
	if place == "park" and GameState.current_minute >= WorldGraph.LOOKOUT_OPEN: return catalog().lookout_open
	return catalog().street.get(place,{})
static func room(id: String) -> Dictionary:
	return catalog().rooms.get(id,{})
static func phase(minute: int) -> int:
	return 2 if minute >= 1140 or minute < 360 else 1 if minute >= 1020 else 0
static func plate(row: Dictionary) -> Texture2D:
	if row.is_empty(): return null
	var page := int(row.pages[phase(GameState.current_minute)])
	if not textures.has(page):
		# Keep only the most recently visited plates, not all 99 full-resolution images.
		if textures.size() >= 32: textures.erase(textures.keys()[0])
		textures[page] = load("res://art/scene_atlas/%02d.jpg" % page)
	return textures[page]
static func object_x(room_id: String, index: int) -> float:
	var points: Array = catalog().room_objects.get(room_id,[])
	return float(points[index]) if index < points.size() else 800.0
