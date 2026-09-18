extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void: await create_timer(0.85).timeout
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await process_frame
	event.pressed = false
	root.push_input(event)
func shot(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--screenshots"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TEMP") + "/solmere-polish-review/route-" + label + ".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(1); return
	var state = root.get_node("GameState")
	var graph = root.get_node("WorldGraph")
	var router = root.get_node("SceneRouter")
	state.begin_new_game("A")
	state.current_location = "bus_stop"
	state.current_minute = 540
	change_scene_to_file("res://scenes/town_day.tscn")
	await settle()
	check(current_scene.segment_id == "main_street" and state.current_location == "bus_stop" and current_scene.street.player_x >= 80, "Start at the configured bus-stop arrival on main street")
	var all_places: Array = []
	for route in graph.config.segments:
		for id in route.locations:
			check(not all_places.has(id), "Each approved place belongs to one route")
			all_places.append(id)
	check(all_places.size() == 15, "Exactly fifteen approved places across four routes")
	# W/S and physical street edges no longer change regions. Cross-region travel
	# goes through TravelSystem and the paper map only.
	var original_segment: String = current_scene.segment_id
	var original_location: String = state.current_location
	await key(KEY_W)
	await key(KEY_S)
	await process_frame
	check(current_scene.segment_id == original_segment and state.current_location == original_location, "W/S cannot switch regions")
	check(not current_scene.has_method("_check_route_boundary") and not current_scene.has_method("_change_route"), "Legacy edge and direction-key route switching is removed")
	for trip in [["residence","residential",4800],["record_store","cultural_street",8000],["park","lookout_route",4800]]:
		var result: Dictionary = router.travel_to(str(trip[0]),"walk")
		check(bool(result.get("ok",false)), "Paper-map route can reach "+str(trip[0]))
		await settle()
		check(current_scene.segment_id == str(trip[1]) and current_scene.street.world_width == float(trip[2]), "Destination loads its configured route and screen width")
		check(absf(current_scene.street.player_x-float(root.get_node("TravelSystem").arrival_for(str(trip[0])).x)) < 1.0, "Destination uses the configured arrival point")
	state.current_minute = 1259
	current_scene._refresh()
	check(current_scene.street.walk_limit == 4260, "Lookout gate is at the final screen and still closed at 20:59")
	state.current_minute = 1260
	current_scene._refresh()
	check(not is_finite(current_scene.street.walk_limit), "Gate opens at 21:00")
	check(graph.walking_distance("record_store","dorm") > absf(graph.location_x("record_store")-graph.location_x("dorm")), "Commute estimate includes the branch return journey")
	# A pre-branch save restores its named destination, not an obsolete coast x.
	state.current_location = "record_store"
	state.shared_state.street_layout_version = 5
	state.shared_state.street_positions = {"A_1_coast":23200}
	router.town_day()
	await settle()
	check(current_scene.segment_id == "cultural_street" and state.current_location == "record_store", "Old continuous-coast saves migrate to the correct branch")
	print("ROUTE LAYOUT PASS" if failures == 0 else "ROUTE LAYOUT FAIL")
	quit(failures)
