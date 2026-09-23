extends Node

const ROUTES_PATH := "res://data/world/travel_routes.json"
const LOCATIONS_PATH := "res://data/world/locations.json"

var adjacency: Dictionary = {}
var transport: Dictionary = {}
var location_names: Dictionary = {}
var arrivals: Dictionary = {}
var travel_in_progress := false


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
	arrivals = parsed.get("arrivals", {})
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


func route(from_id: String, to_id: String, method: String, role: String, minute: int) -> Dictionary:
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
			cost = _distance_fare(walking, transport.get("taxi_fares", {}), 40, 65, 95)
			if _crosses_street(from_id, to_id):
				cost = maxi(cost, int(transport.get("taxi_cross_street_minimum", 50)))
			duration = maxi(int(transport.taxi_minimum), int(ceil(walking * float(transport.taxi_factor)))) + wait
			label = "出租车"
		"friend":
			if ride_friend().is_empty(): return {"available":false,"reason":"和居民熟悉后，才方便开口借车。"}
			wait = int(transport.get("friend_wait", 8))
			cost = _distance_fare(walking, transport.get("friend_fares", {}), 10, 20, 35)
			duration = maxi(int(transport.get("friend_minimum", 8)), int(ceil(walking * float(transport.get("friend_factor", 0.45))))) + wait
			label = "找人借车"
		_: return {"available":false, "reason":"没有这种交通方式。"}
	var homeward := to_id==("residence" if role=="A" else "dorm") and minute>=1320 and minute+duration<=1439
	if not homeward and not GameState.can_fit_at(role, GameState.current_day, minute, duration):
		return {"available":false, "reason":"当前空闲时段不足以完成这段路程。"}
	var conflicts: Array[String] = []
	for opportunity in CoreLoopSystem.opportunities():
		if int(opportunity.day)==GameState.current_day and str(opportunity.status)!="missed" and minute+duration>int(opportunity.end):
			conflicts.append(str(opportunity.text))
	for appointment in GameState.appointments:
		if int(appointment.get("day", 0)) == GameState.current_day and str(appointment.get("status", "")) in ["scheduled", "active"] and str(appointment.get("location", "")) != to_id and minute < int(appointment.get("end", 1440)) and minute + duration > int(appointment.get("start", 1440)):
			conflicts.append(str(appointment.get("label", "已知预约")))
	return {"available":true, "minutes":duration, "cost":cost, "wait":wait, "arrival":minute+duration, "label":label, "conflicts":conflicts}

func travel(to_id: String, method: String) -> Dictionary:
	if travel_in_progress: return {"ok":false,"message":"还在路上。"}
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
	if GameState.current_day>5 and GameState.current_minute + duration >= 1440:
		return {"ok": false, "message": "今天已没有足够时间完成这段路程。"}
	if cost > 0 and GameState.money < cost:
		return {"ok": false, "message": "余额不足。"}
	var snapshot := GameState.to_save_data().duplicate(true)
	var from_id := GameState.current_location
	travel_in_progress = true
	var homeward := to_id==CoreLoopSystem.home() and GameState.current_minute>=1320
	if not (GameState.spend_time(duration) if homeward else GameState.use_free_time(duration)):
		travel_in_progress = false
		GameState.load_save_data(snapshot)
		return {"ok":false,"message":"当前空闲时段不足以完成这段路程。"}
	if cost > 0 and not GameState.spend_money(cost, "%s前往%s" % [str(option.get("label", "交通")), location_name(to_id)]):
		travel_in_progress = false
		GameState.load_save_data(snapshot)
		return {"ok":false,"message":"余额不足，本次出行已撤销。"}
	if method == "bus":
		GameState.add_journal_entry({"kind":"ticket", "text":"一张公交票 · " + location_name(to_id)})
	GameState.current_location = to_id
	if method == "walk": _walk_keepsake(from_id,to_id)
	elif method == "bus":
		_journey_fact("bus_park_notice","公交线路图上，观景台站被圈了出来。晚上九点后可以去看星星。","车上的线路图","park")
	elif method == "taxi" and to_id in ["night_market","produce_stall"]:
		_journey_fact("beetman_shopping","司机指了指菜摊旁的小路：从这里到饭店，可以少绕一个弯。","出租车司机","produce_stall")
	elif method == "friend":
		var resident := ride_friend()
		if not resident.is_empty():
			RelationshipSystem.record_encounter(resident,"shared_ride_d%d_%s" % [GameState.current_day,to_id],["shared_a_ride"])
			_journey_fact("ride_"+resident+"_"+to_id,"和"+GuidanceSystem.source_name(resident)+"一起前往"+location_name(to_id)+"，记下了这段同行的路。",resident,to_id)
	GameState.commit_active_role_state()
	GameState.state_changed.emit()
	travel_in_progress = false
	return {
		"ok": true,
		"message": "%s用了%d分钟，花费%d元。" % [str(option.get("label", "移动")), duration, cost],
		"path_minutes": duration,
	}

func ride_friend() -> String:
	for id in GameState.relationships:
		var relationship: Dictionary=GameState.relationships[id]
		if str(relationship.get("confirmation",""))=="granted" or relationship.get("flags",[]).has("ride_offered"): return str(id)
		var meaningful: Array=relationship.get("encounter_events",[]).filter(func(event: Variant) -> bool: return not str(event).begins_with("visit_") and not str(event).begins_with("chat_"))
		if meaningful.size()>=2: return str(id)
	return ""

func _journey_fact(id: String, words: String, source: String, location: String) -> void:
	# Join the same transaction as the fare/time. SceneRouter saves or restores all of it.
	var key := "knowledge_"+GameState.current_role
	var facts: Array=GameState.shared_state.get(key,[])
	if facts.any(func(fact: Dictionary) -> bool: return str(fact.get("id",""))==id): return
	facts.append({"id":id,"text":words,"source_npc_id":source,"subject_id":location,"predicate":"lead","confidence":1.0,"learned_day":GameState.current_day,"learned_time":GameState.current_minute})
	GameState.shared_state[key]=facts


func _distance_fare(walking: int, fares: Dictionary, short_fare: int, medium_fare: int, long_fare: int) -> int:
	if walking <= 18:
		return int(fares.get("short", short_fare))
	if walking <= 35:
		return int(fares.get("medium", medium_fare))
	return int(fares.get("long", long_fare))


func _crosses_street(from_id: String, to_id: String) -> bool:
	return str(WorldGraph.segment_for(from_id).get("id", "")) != str(WorldGraph.segment_for(to_id).get("id", ""))


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
			var edge_minutes := int(edge.get("minutes",0))
			for shortcut in transport.get("shortcuts",[]):
				if [current,neighbor].has(str(shortcut.from)) and [current,neighbor].has(str(shortcut.to)) and KnowledgeSystem.facts().any(func(f: Dictionary)->bool:return str(f.get("id",""))==str(shortcut.fact)):
					edge_minutes=mini(edge_minutes,int(shortcut.minutes))
			var candidate := best + edge_minutes
			if candidate < int(distances.get(neighbor, 1 << 30)):
				distances[neighbor] = candidate
	return -1

func _walk_keepsake(from_id: String, to_id: String) -> void:
	var key := "walk_keep_%s_%d" % [GameState.current_role,GameState.current_day]
	if GameState.has_event(key) or GameState.current_location==from_id: return
	if to_id not in ["port","produce_stall","park"]: return
	GameState.mark_event(key)
	var words := "沿海路走来，风把一张小镇旧地图压在石阶上。背面有人写着：海边的光总会晚一点。"
	GameState.add_artifact("collage_materials",{"id":key,"kind":"paper","title":"路上拾到的旧地图角","day":GameState.current_day,"location":to_id,"source":"步行 · "+location_name(from_id)+"至"+location_name(to_id),"text":words},false)
	GameState.add_journal_entry({"id":key,"kind":"discovery","text":words})
	MetaExperience.queue_important("v3_environment_detail",{"text":words,"location_id":to_id})
	GameState.message_posted.emit("路上拾到一角旧地图，已收进素材本。")

func arrival_for(location: String) -> Dictionary:
	var segment := WorldGraph.segment_for(location)
	var offset := float(segment.get("offset",0))
	var width: float = (float(segment.width)-offset)/segment.locations.size()
	var point: Dictionary = arrivals.get(location,{"local_x":300,"facing":1})
	return {"route":segment.id,"x":offset+segment.locations.find(location)*width+float(point.local_x)*width/1600.0,"facing":float(point.get("facing",1))}
