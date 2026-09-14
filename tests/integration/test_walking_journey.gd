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

func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"):
		push_error("Run with -- --isolated-save to protect real journeys")
		quit(1)
		return
	var state = root.get_node("GameState")
	var chapters = root.get_node("ChapterSystem")
	var router = root.get_node("SceneRouter")
	var saves = root.get_node("SaveManager")
	var gameplay = root.get_node("GameplayModuleSystem")
	chapters.start_new_game("B")
	check(state.current_role == "A", "Authored opening must always start with A")
	var sequence: Array = chapters.chapter_sequence()
	check(sequence.size() == 7 and sequence[1].role == "B" and sequence[1].day == 2, "The authored journey must contain seven days and switch to B on Day 2")
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
	await settle()
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
	check(not town.street.hotspots.any(func(h: Dictionary) -> bool: return str(h.kind) == "roads"), "Walking must never require a map travel menu")
	town.street.hotspots.clear()
	town.street.hotspots.append({"x":town.street.player_x + 200, "kind":"door"})
	check(town.street.nearest().is_empty(), "Distant interactions must be inaccessible")
	# Enter the home by proximity, then walk to the bed.
	state.current_location = "residence"
	router.town_day()
	await settle()
	town = current_scene
	var residence_index: int = town.street_order.find("residence")
	town.street.player_x = residence_index * town.BLOCK_WIDTH + 300.0
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
	home._select_object(1)
	home._open_selected()
	check(not state.shared_state.get("sleep_pending", false), "Bed cannot be used from across the room")
	home.stage.player_x = home._hotspot_x(1)
	home._open_selected()
	await settle(4.4)
	check(state.current_role == "B" and state.current_day == 2, "Sleeping must automatically switch to B on Day 2")
	check(state.current_location == "dorm", "B must wake at B's own home")
	check(not state.shared_state.has("sleep_pending"), "Sleep transition must commit exactly once")
	check(current_scene.scene_file_path.ends_with("town_day.tscn"), "Sleep must return to playable street without alignment")
	# Enter a room and test a real gameplay round-trip from an object.
	router.enter_space("print_studio")
	state.current_location = "print_shop"
	state.current_minute = 1080
	await settle()
	var room = current_scene
	room._select_object(0)
	room.stage.player_x = room._hotspot_x(0)
	room._open_selected()
	await settle()
	check(not current_scene.scene_file_path.ends_with("interactive_space.tscn"), "Nearby object must launch its existing game")
	gameplay.cancel_session()
	router.return_from_gameplay()
	await settle()
	check(current_scene.scene_file_path.ends_with("interactive_space.tscn"), "Mini-game return must restore the same room")
	check(router.active_space_id == "print_studio", "Return must preserve the room identity")
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
