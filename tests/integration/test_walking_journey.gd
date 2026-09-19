extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle(seconds := 0.8) -> void:
	await create_timer(seconds).timeout
	for i in 50:
		if not root.get_node("SceneRouter").transitioning: break
		await create_timer(.1).timeout

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		push_error("Run with -- --isolated-save to protect real journeys")
		quit(1)
		return
	var state = root.get_node("GameState")
	var chapters = root.get_node("ChapterSystem")
	var router = root.get_node("SceneRouter")
	var saves = root.get_node("SaveManager")
	chapters.start_new_game("B")
	check(state.current_role == "A", "Authored opening must always start with A")
	var sequence: Array = chapters.chapter_sequence()
	check(sequence.size() == 14 and sequence[1].role == "B" and sequence[1].day == 1 and sequence[2].role == "B", "Each protagonist receives seven days; the authored Day 2 opening remains B")
	check(not chapters.sleep_at_home(), "Sleeping outside one's home must be rejected")
	var places: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/locations.json")).locations
	var indoors: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/interactive_spaces.json")).spaces
	check(places.size() == 15 and indoors.size() == 9, "Scene scope must stay at 15 locations / 9 interiors")
	check(str(places[-1].id) == "park" and str(places[-1].kind) == "lookout", "The rightmost scene must be the sea lookout")
	var known: Array = []
	for place in places: known.append(str(place.id))
	for space in indoors:
		check(known.has(str(space.location_id)), "Every interior must belong to an approved location")
		router.active_space_id = str(space.id)
		state.current_location = str(space.location_id)
		var room = load("res://scenes/interactive_space.tscn").instantiate()
		root.add_child(room)
		await process_frame
		check(room.stage != null, "Every interior must expose a walkable stage")
		check(room.objects.size() > 0, "Every interior must expose nearby interactions")
		room.queue_free()
		await process_frame
	chapters.start_new_game()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await process_frame
	await process_frame
	current_scene._on_new_game_pressed()
	await settle(1.4)
	check(current_scene.scene_file_path.ends_with("town_day.tscn"), "New game must enter the world directly")
	var town = current_scene
	check(town.street.player_x == 150.0 and state.current_location == "bus_stop", "A new journey must begin at the far-left bus stop")
	check(town.street != null and not town.event_overlay.visible, "No role, empty-slot or opening-page gate")
	town.street.enabled = true
	var before: float = town.street.player_x
	town.street.move_player(1, 0.2)
	check(town.street.player_x > before, "Movement must be continuous, not hotspot selection")
	town.street.player_x = town.street.world_width - 80.0
	town._on_walk(town.street.player_x)
	town._refresh()
	check(town.street_order.size() == 6 and town.street_order[-1] == "print_shop", "Main street ends at the community center and connects to the lookout route")
	check(not town.street.hotspots.any(func(h: Dictionary) -> bool: return str(h.kind) == "roads"), "Street walking has no obsolete road sign")
	town.street.hotspots.clear()
	town.street.hotspots.append({"x":town.street.player_x + 200, "kind":"door"})
	check(town.street.nearest().is_empty(), "Distant interactions must be inaccessible")
	# Enter the home by proximity, then walk to the bed.
	town.street.velocity = 0
	router.travel_to("residence","walk")
	await settle()
	town = current_scene
	var residence_index: int = town.street_order.find("residence")
	town.street.player_x = town._world_x(residence_index, 300.0)
	town._on_walk(town.street.player_x)
	town._refresh()
	var home_hotspots: Array = town.street.hotspots.filter(func(item): return str(item.get("kind", "")) == "home")
	check(not home_hotspots.is_empty(), "A's home should expose a proximity hotspot")
	if not home_hotspots.is_empty(): town.street.player_x = float(home_hotspots[0].x)
	town._interact()
	await settle()
	check(router.active_space_id == "home_a", "A must enter A's own home")
	var home = current_scene
	check(home.scene_file_path.ends_with("interactive_space.tscn"), "Door must enter a real interior")
	if not home.scene_file_path.ends_with("interactive_space.tscn"):
		quit(1)
		return
	var bed_index := -1
	for index in home.objects.size():
		if str(home.objects[index].get("kind",""))=="sleep": bed_index=index
	check(bed_index>=0,"Home has an actual bed")
	home._select_object(bed_index)
	home._open_selected()
	check(not state.shared_state.get("sleep_pending", false), "Bed cannot be used from across the room")
	home.stage.player_x = home._hotspot_x(bed_index)
	home._open_selected()
	await settle(4.4)
	check(state.current_role == "B" and state.current_day == 1, "Sleeping switches to B's first day")
	check(state.current_location == "dorm", "B must wake at B's own home")
	check(not state.shared_state.has("sleep_pending"), "Sleep transition must commit exactly once")
	check(current_scene.scene_file_path.ends_with("town_day.tscn"), "Sleep must return to playable street without alignment")
	# The community center clock opens in place, pays once when correctly set,
	# and no longer routes through the former photography workbench.
	router.enter_space("print_studio")
	state.current_location = "print_shop"
	state.current_minute = 1080
	await settle()
	var room = current_scene
	check(room.objects.size() == 1 and str(room.objects[0].get("kind", "")) == "clock_repair", "Community center replaces its photography workbench with the clock interaction")
	room._select_object(0)
	room.stage.player_x = room._hotspot_x(0)
	room._open_selected()
	await process_frame
	check(room.pocket_panel != null and room.pocket_panel.get_script().resource_path.ends_with("clock_repair.gd"), "Nearby clock must open the hand-setting interaction in place")
	var before_clock_pay: int = state.money
	room.pocket_panel.hour_value = room.pocket_panel.target_hour
	room.pocket_panel.minute_value = room.pocket_panel.target_minute
	room.pocket_panel._submit()
	check(state.money == before_clock_pay + 20, "Correct clock time pays 20 yuan")
	room.pocket_panel._submit()
	check(state.money == before_clock_pay + 20, "Clock reward cannot be collected twice")
	room.pocket_panel.queue_free()
	await process_frame
	check(current_scene.scene_file_path.ends_with("interactive_space.tscn") and router.active_space_id == "print_studio", "Closing the clock keeps the player in the community center")
	# Book notes and all supported scene scripts must load.
	router.enter_space("public_archive")
	state.current_location = "library"
	await settle()
	current_scene._show_book_notes()
	check(current_scene.notes_overlay != null, "Bookstore note wall must open")
	saves.save_game()
	check(saves.load_latest(), "Continue must automatically load the latest valid journey")
	check(state.current_role == "B", "Continue must retain authored role")
	print("WALKING_JOURNEY_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)
