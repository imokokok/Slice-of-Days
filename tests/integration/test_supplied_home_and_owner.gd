extends SceneTree
## Run with --isolated-save. Exercises the authored home entrances and the
## existing record-shop resident through actual E/W input and room transitions.
const Cutout = preload("res://scripts/ui/authored_jpeg.gd")
const Composition = preload("res://scripts/ui/street_composition.gd")
var checks := 0
var failures := 0
var gs
var router
var dialogue

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("PASS ", message)
func settle() -> void:
	await process_frame
	while router.transitioning: await process_frame
	await process_frame
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code; event.physical_keycode = code; event.pressed = true
	root.push_input(event); await process_frame
	event.pressed = false; root.push_input(event); await settle()
func capture(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("SOLMERE_QA_CAPTURE_DIR")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://.runtime/supplied-art")
	var error := DirAccess.make_dir_recursive_absolute(output)
	if error == OK: error = root.get_texture().get_image().save_png(output.path_join(id + ".png"))
	if error != OK: check(false, "Could not save capture " + id + ": " + error_string(error))
func arrive(place: String) -> void:
	gs.current_location = place; gs.shared_state.map_arrival = place
	router.town_day(.01); await settle()
	current_scene.set_process(false)
	current_scene.street.set_process(false)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(1600,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	gs = root.get_node("GameState"); router = root.get_node("SceneRouter"); dialogue = root.get_node("DialogueSystem")
	root.get_node("ChapterSystem").start_new_game()
	var start := Time.get_ticks_msec()
	var source: Texture2D = load("res://art/user_scenes/xanni_supplied.jpg")
	var portrait := Cutout.cutout(source, true)
	var elapsed := Time.get_ticks_msec() - start
	print("PORTRAIT_INITIAL_MASK_MS ", elapsed)
	check(portrait == Cutout.cutout(source, true), "Re-entering the shop reuses the prepared portrait")
	check(portrait.get_width() < 750 and portrait.get_height() > 1600, "Portrait trims paper padding and keeps the full figure")
	var pixels := portrait.get_image()
	check(pixels.get_pixel(0,0).a == 0, "Paper outside the portrait is transparent")
	var white_toes := 0
	for y in range(int(pixels.get_height()*.88), pixels.get_height()):
		for x in pixels.get_width():
			var p := pixels.get_pixel(x,y)
			if p.a > .99 and minf(p.r,minf(p.g,p.b)) > .95: white_toes += 1
	check(white_toes > 1000, "White sneaker panels remain opaque rather than becoming holes")
	var home_source: Texture2D = load("res://art/user_scenes/shared_home_supplied.jpg")
	var home := Cutout.cutout(home_source, false, Composition.SHARED_HOME_PAPER_OPENINGS)
	check(home.get_size() == Composition.SHARED_HOME_CANVAS, "Home anchors use the supplied image coordinates")
	check(home.get_image().get_pixel(0,0).a == 0, "House has no rectangular white backdrop")
	check(home.get_image().get_pixel(275,1000).a == 0 and home.get_image().get_pixel(525,660).a == 0, "Sky remains visible through the stair and balcony railing openings")
	check(home.get_image().get_pixel(700,300).is_equal_approx(home_source.get_image().get_pixel(700,300)), "Orange roof colors are unchanged in the source composite")
	var rect := Composition.cutout_rect("residence",home.get_size(),820)
	check(absf(rect.position.y + 1205*rect.size.y/1280 - Composition.CURB)<.01, "Building contact line coincides with the shared ground line")
	for role in ["A","B"]:
		gs.switch_to_role(role,1 if role == "A" else 2,true); gs.current_minute = 720
		await arrive("residence")
		var town = current_scene
		var entrances: Array = town.street.hotspots.filter(func(h): return str(h.kind) == "home")
		check(entrances.size() == 1, role + " has one reachable home entry")
		if entrances.is_empty(): quit(1); return
		var entry: float = entrances[0].x
		check(absf(entry-town._place_center()-Composition.home_entry_offset(role))<.01, role + " prompt aligns with the painted stairs/door")
		town.street.player_x = entry; town.street.camera_x = 0; town.street.queue_redraw()
		check(str(town.street.nearest_interactable().get("kind","")) == "home", role + " can interact at the visible entrance")
		await capture("home-" + role)
		await key(KEY_E)
		check(is_instance_valid(town.pocket_panel), role + " E opens the shared mailbox landing")
		town.pocket_panel.find_child("EnterPrivateRoom",true,false).pressed.emit(); await settle()
		check(router.active_space_id == "home_" + role.to_lower(), role + " keeps the existing private interior")
		current_scene.stage.set_process(false); await capture("room-" + role)
		current_scene.stage.player_x = 145 if role == "A" else 90
		await key(KEY_E)
		check(router.active_space_id.is_empty(), role + " can return to the street")
	gs.current_minute = 720
	await arrive("record_store")
	check(not current_scene.street.presented_residents().any(func(h): return str(h.id) == "xanni"), "Indoor owner is not cloned outside the store")
	var doors: Array = current_scene.street.hotspots.filter(func(h): return str(h.kind) == "door" and str(h.id) == "record_shop")
	check(doors.size() == 1, "Record store retains its real entrance")
	current_scene.street.player_x = doors[0].x; await key(KEY_E)
	var room = current_scene
	room.set_process(false); room.stage.set_process(false)
	var owners: Array = room.stage.presented_residents().filter(func(h): return str(h.id) == "xanni")
	check(owners.size() == 1, "Exactly one Xanni occupies her existing scheduled shop position")
	check(str(root.get_node("ScheduleSystem").residents.xanni.display_name) == "Xanni", "Existing owner name is preserved")
	var at: float = dialogue.resident_placement("xanni").x
	room.stage.player_x = at-166.4; room.stage.queue_redraw(); room.stage.player_display.queue_redraw()
	check(str(room.stage.nearest_of(["person"]).get("id","")) == "xanni", "Owner can be addressed from a comfortable distance without touching sprites")
	await capture("record-owner")
	room.stage.player_x = at-60; await key(KEY_W)
	check(is_instance_valid(room.conversation), "W beside the supplied owner opens the existing conversation")
	await create_timer(.4).timeout
	check(absf(room.stage.player_x-at) >= 166 and is_equal_approx(float(dialogue.resident_placement("xanni").x),at), "Close conversation gently separates the player while keeping the owner fixed")
	await key(KEY_SPACE)
	check(not room.conversation.text_label.text.is_empty() and room.conversation.text_label.visible_characters == -1, "The owner's dialogue text can be fully revealed")
	await capture("record-conversation")
	await key(KEY_ESCAPE)
	check(not is_instance_valid(room.conversation), "Closing dialogue restores the store")
	room.stage.player_x = 90; await key(KEY_E)
	current_scene.street.player_x = current_scene.street.hotspots.filter(func(h): return str(h.kind)=="door" and str(h.id)=="record_shop")[0].x
	await key(KEY_E)
	check(current_scene.stage.presented_residents().filter(func(h): return str(h.id)=="xanni").size()==1 and is_equal_approx(float(dialogue.resident_placement("xanni").x),at), "Re-entry preserves the same single owner and position")
	print("SUPPLIED_HOME_AND_OWNER: ",checks," checks / ",failures," failures")
	if failures == 0 and OS.get_cmdline_user_args().has("--keep-open"):
		current_scene.stage.player_x = at-60
		current_scene.stage.queue_redraw()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
		DisplayServer.window_set_position(Vector2i(120,80))
		DisplayServer.window_set_title("Solmere · 唱片店老板与住处")
		await key(KEY_W)
		await key(KEY_SPACE)
		return
	quit(failures)
