extends Node

const ROUTES_PATH := "res://data/world/travel_routes.json"
const LOCATIONS_PATH := "res://data/world/locations.json"

var adjacency: Dictionary = {}
var transport: Dictionary = {}
var location_names: Dictionary = {}


func _ready() -> void:
	load_route_data(ROUTES_PATH)
	load_location_names(LOCATIONS_PATH)


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
	transport = parsed.get("transport", {})
	for edge in parsed.get("edges", []):
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		var minutes := int(edge.get("walk_minutes", 10))
		_add_edge(from_id, to_id, minutes)
		if bool(edge.get("bidirectional", true)):
			_add_edge(to_id, from_id, minutes)


func load_location_names(path: String) -> void:
	location_names.clear()
	if not FileAccess.file_exists(path):
		push_warning("Location data not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Unable to open location data: %s" % path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("Invalid location data: %s" % path)
		return
	for item in parsed.get("locations", []):
		if item is Dictionary:
			var location_id := str(item.get("id", ""))
			if not location_id.is_empty():
				location_names[location_id] = str(item.get("name", location_id))


func location_name(location_id: String) -> String:
	return str(location_names.get(location_id, location_id))


func _add_edge(from_id: String, to_id: String, minutes: int) -> void:
	if from_id.is_empty() or to_id.is_empty():
		return
	var rows: Array = adjacency.get(from_id, [])
	rows.append({"to": to_id, "minutes": max(minutes, 1)})
	adjacency[from_id] = rows


func route(from_id: String, to_id: String, method: String, _role: String, minute: int) -> Dictionary:
	if from_id == to_id: return {"available":false, "reason":"已经在这里。"}
	var walking := _shortest_walk_minutes(from_id, to_id)
	if walking < 0: return {"available":false, "reason":"没有连接的路线。"}
	var wait := 0
	var cost := 0
	var duration := walking
	var label := "步行"
	match method:
		"walk": pass
		"bus":
			if not transport.bus_stops.has(from_id) or not transport.bus_stops.has(to_id): return {"available":false, "reason":"请在公交站或住宅、观景台站点上下车。"}
			var interval := int(transport.bus_night_interval if minute >= int(transport.bus_night_start) else transport.bus_interval)
			var departure := maxi(int(transport.bus_first), int(ceil(float(minute) / interval)) * interval)
			if departure > int(transport.bus_last): return {"available":false, "reason":"今天的末班车已经开走。"}
			wait = departure - minute
			cost = int(transport.bus_fare)
			duration = maxi(int(transport.bus_minimum), int(ceil(walking * float(transport.bus_factor)))) + wait
			label = "公交"
		"taxi":
			wait = int(transport.taxi_wait)
			cost = int(transport.taxi_cost)
			duration = maxi(int(transport.taxi_minimum), int(ceil(walking * float(transport.taxi_factor)))) + wait
			label = "出租车"
		"friend":
			var npc := str(transport.friend_npc)
			var relationship: Dictionary = GameState.relationships.get(npc, {})
			var activity := ScheduleSystem.activity_at(npc, GameState.current_day, minute)
			var used: Array = GameState.shared_state.get("used_rides", [])
			var token := "%d_%s" % [GameState.current_day, npc]
			if not transport.get("friend_destinations",[]).has(to_id) or int(relationship.get("encounters", 0)) < int(transport.friend_encounters) or str(activity.get("location", "")) != from_id or minute < int(transport.friend_start) or minute + int(transport.friend_minutes) > int(transport.friend_end) or used.has(token):
				return {"available":false, "reason":"现在没有相熟且有空的居民顺路。"}
			duration = int(transport.friend_minutes)
			label = "熟人顺路接送"
		_: return {"available":false, "reason":"没有这种交通方式。"}
	var conflicts: Array[String] = []
	for appointment in GameState.appointments:
		if int(appointment.get("day", 0)) == GameState.current_day and str(appointment.get("status", "")) in ["scheduled", "active"] and minute < int(appointment.get("end", 1440)) and minute + duration > int(appointment.get("start", 1440)):
			conflicts.append(str(appointment.get("label", "已知预约")))
	return {"available":true, "minutes":duration, "cost":cost, "wait":wait, "arrival":minute+duration, "label":label, "conflicts":conflicts}

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
	if GameState.current_minute + duration >= 1440:
		return {"ok": false, "message": "今天已没有足够时间完成这段路程。"}
	if cost > 0 and GameState.money < cost:
		return {"ok": false, "message": "余额不足。"}
	if cost > 0:
		GameState.spend_money(cost)
	GameState.spend_time(duration)
	if method == "friend":
		var used: Array = GameState.shared_state.get("used_rides", [])
		used.append("%d_%s" % [GameState.current_day, str(transport.friend_npc)])
		GameState.shared_state["used_rides"] = used
	if method == "bus":
		GameState.add_journal_entry({"kind":"ticket", "text":"一张公交票 · " + location_name(to_id)})
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
