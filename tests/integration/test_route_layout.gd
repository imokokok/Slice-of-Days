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
	root.get_node("ChapterSystem").start_new_game()
	change_scene_to_file("res://scenes/town_day.tscn")
	await settle()
	check(current_scene.segment_id == "main_street" and state.current_location == "bus_stop" and current_scene.street.player_x == 150, "Start at the far-left bus stop")
	var all_places: Array = []
	for route in graph.config.segments:
		for id in route.locations:
			check(not all_places.has(id), "Each approved place belongs to one route")
			all_places.append(id)
	check(all_places.size() == 15, "Exactly fifteen approved places across four routes")
	await shot("start")
	# Enter both branches with actual viewport keyboard input, then walk back.
	for branch in [[KEY_W,"residential",["residence","dorm","port"],4800], [KEY_S,"cultural_street",["handcraft_shop","library","record_store","chess_stall","tarot_stall"],8000]]:
		current_scene.street.player_x = graph.JUNCTION_X
		current_scene.street.move_player(0,0)
		current_scene._on_walk(graph.JUNCTION_X)
		await shot("junction")
		await key(branch[0])
		await settle()
		check(current_scene.segment_id == branch[1], "Direction key enters the correct branch")
		check(current_scene.street_order == branch[2] and current_scene.street.world_width == branch[3], "Branch order and screen count match the diagram")
		await shot(str(branch[1]))
		current_scene.street.player_x = 80
		current_scene._check_route_boundary(-1)
		await settle()
		check(current_scene.segment_id == "main_street" and is_equal_approx(current_scene.street.player_x, graph.JUNCTION_X), "Walking left returns to the main-street junction")
		check(current_scene.street.facing == -1, "Returning player faces the direction of walking")
	current_scene.street.player_x = 7920
	current_scene._check_route_boundary(1)
	await settle()
	check(current_scene.segment_id == "lookout_route" and current_scene.street.world_width == 4800, "Main-street right edge connects to the three-screen lookout route")
	check(current_scene.street.player_x < 200, "Arrive at the start of the lookout approach")
	await shot("approach")
	state.current_minute = 1259
	current_scene._refresh()
	check(current_scene.street.walk_limit == 4260, "Lookout gate is at the final screen and still closed at 20:59")
	state.current_minute = 1260
	current_scene._refresh()
	check(not is_finite(current_scene.street.walk_limit), "Gate opens at 21:00")
	current_scene.street.player_x = 4400
	current_scene.street.move_player(0,0)
	await shot("lookout")
	current_scene.street.player_x = 80
	current_scene._check_route_boundary(-1)
	await settle()
	check(current_scene.segment_id == "main_street" and state.current_location == "print_shop", "Lookout return arrives beside the community center")
	check(graph.walking_distance("record_store","dorm") > absf(graph.location_x("record_store")-graph.location_x("dorm")), "Commute estimate includes the branch return journey")
	current_scene._open_map()
	await settle()
	await shot("map")
	current_scene._select("dorm")
	check(current_scene.info.get_child_count() > 3, "Map offers route directions without a travel menu")
	router.return_from_gameplay()
	await settle()
	check(current_scene.segment_id == "main_street", "Closing the map restores the same route")
	# A pre-branch save restores its named destination, not an obsolete coast x.
	state.current_location = "record_store"
	state.shared_state.street_layout_version = 5
	state.shared_state.street_positions = {"A_1_coast":23200}
	router.town_day()
	await settle()
	check(current_scene.segment_id == "cultural_street" and state.current_location == "record_store", "Old continuous-coast saves migrate to the correct branch")
	print("ROUTE LAYOUT PASS" if failures == 0 else "ROUTE LAYOUT FAIL")
	quit(failures)
