extends Node

const ROUTES_PATH := "res://data/world/travel_routes.json"

var adjacency: Dictionary = {}


func _ready() -> void:
	load_route_data(ROUTES_PATH)


func load_route_data(path: String) -> void:
	adjacency.clear()
	if not FileAccess.file_exists(path):
		push_warning("Travel route data not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid travel route data: %s" % path)
		return
	for edge in parsed.get("edges", []):
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		var minutes := int(edge.get("walk_minutes", 10))
		_add_edge(from_id, to_id, minutes)
		if bool(edge.get("bidirectional", true)):
			_add_edge(to_id, from_id, minutes)


func _add_edge(from_id: String, to_id: String, minutes: int) -> void:
	if from_id.is_empty() or to_id.is_empty():
		return
	var rows: Array = adjacency.get(from_id, [])
	rows.append({"to": to_id, "minutes": max(minutes, 1)})
	adjacency[from_id] = rows


func route(from_id: String, to_id: String, method: String, role: String, minute: int) -> Dictionary:
	if from_id == to_id:
		return {"available": false, "reason": "已经在这里。"}
	var walk_minutes := _shortest_walk_minutes(from_id, to_id)
	if walk_minutes < 0:
		return {"available": false, "reason": "当前没有通往这里的路线。"}
	match method:
		"walk":
			return {"available": true, "minutes": walk_minutes, "cost": 0, "label": "步行"}
		"bus":
			var wait := (15 - minute % 15) % 15
			return {
				"available": true,
				"minutes": max(8, int(ceil(walk_minutes * 0.55))) + wait,
				"cost": 2,
				"label": "公交",
			}
		"taxi":
			return {
				"available": true,
				"minutes": max(6, int(ceil(walk_minutes * 0.35))),
				"cost": 20,
				"label": "打车",
			}
		"friend":
			var available := role == "B" and minute >= 1140 and minute <= 1200
			return {
				"available": available,
				"minutes": max(8, int(ceil(walk_minutes * 0.45))),
				"cost": 0,
				"label": "朋友顺路",
				"reason": "朋友只在19:00至20:00顺路。" if not available else "",
			}
	return {"available": false, "reason": "不支持的交通方式。"}


func travel(to_id: String, method: String) -> Dictionary:
	var option := route(
		GameState.current_location,
		to_id,
		method,
		GameState.current_role,
		GameState.current_minute
	)
	if not bool(option.get("available", false)):
		return {"ok": false, "message": str(option.get("reason", "当前无法使用。"))}
	var duration := int(option.get("minutes", 0))
	var cost := int(option.get("cost", 0))
	if not GameState.can_fit_now(duration):
		return {"ok": false, "message": "当前时间块放不下这段路程。"}
	if cost > 0 and GameState.money < cost:
		return {"ok": false, "message": "余额不足。"}
	if cost > 0:
		GameState.spend_money(cost)
	GameState.use_free_time(duration)
	GameState.current_location = to_id
	GameState.commit_active_role_state()
	GameState.state_changed.emit()
	return {
		"ok": true,
		"message": "%s用了%d分钟，花费%d元。" % [str(option.get("label", "移动")), duration, cost],
		"path_minutes": duration,
	}


func _shortest_walk_minutes(from_id: String, to_id: String) -> int:
	if not adjacency.has(from_id) or not adjacency.has(to_id):
		return -1
	var distances: Dictionary = {from_id: 0}
	var unvisited: Array = adjacency.keys()
	while not unvisited.is_empty():
		var current := ""
		var best := 1 << 30
		for node_id in unvisited:
			var distance := int(distances.get(node_id, 1 << 30))
			if distance < best:
				best = distance
				current = str(node_id)
		if current.is_empty() or best == 1 << 30:
			break
		if current == to_id:
			return best
		unvisited.erase(current)
		for edge in adjacency.get(current, []):
			var neighbor := str(edge.get("to", ""))
			var candidate := best + int(edge.get("minutes", 0))
			if candidate < int(distances.get(neighbor, 1 << 30)):
				distances[neighbor] = candidate
	return -1
