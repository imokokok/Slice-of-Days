extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := root.get_node("GameState")
	root.get_node("ChapterSystem").start_new_game()
	game.current_location="cafe"; game.current_minute=600; game.money=600
	var film=root.get_node("FilmSystem")
	check(film.acquire_camera(false).ok,"Acquire camera through the grocery counter")
	game.current_location = "residence"
	var town = load("res://scenes/town_day.tscn").instantiate()
	root.add_child(town)
	await process_frame
	await process_frame
	town._open_record_store()
	check(not is_instance_valid(town.pocket_panel), "Studio allowed away from record store")
	var forbidden_studio = load("res://scripts/town_sound/studio/StudioScreen.gd").new()
	town.add_child(forbidden_studio)
	await process_frame
	check(not is_instance_valid(forbidden_studio), "Direct Studio construction bypassed location guard")
	var global=root.get_node("GlobalRecorder")
	town._open_pocket_recorder(); var view=global.view
	check(is_instance_valid(view),"Global recorder opened from town")
	check(view.source_picker.selected==0,"Game sound remains the default")
	var first_id:int=view.get_instance_id()
	town._open_pocket_recorder()
	check(global.view.get_instance_id()==first_id,"Repeated entry reuses one recorder view")
	view.put_away(); await process_frame; await process_frame
	check(not is_instance_valid(global.view),"Pocketing releases the view")
	check(not auto_accept_quit,"Global close handler protects audio through the full journey")
	game.current_location = "record_store"
	town.queue_free()
	await process_frame
	town = load("res://scenes/town_day.tscn").instantiate()
	root.add_child(town)
	await process_frame
	town._open_record_store()
	check(town.pocket_panel.can_edit_here(), "Shop actions unavailable at record store")
	town.pocket_panel.queue_free()
	await process_frame
	await town._open_pocket_camera()
	var camera = town.pocket_panel
	check(camera.source != null and not camera.source.is_empty(), "Camera did not capture game scene")
	var photo_library := PhotoLibrary.new()
	photo_library.root_path = "user://tests/photos_" + Crypto.new().generate_random_bytes(8).hex_encode()
	camera.library = photo_library
	await create_timer(.4).timeout
	camera.take_photo(); camera.take_photo()
	check(int(film.active_roll().exposures_used)==1,"Repeated shutter does not duplicate an exposure")
	await create_timer(.5).timeout
	camera._set_zoom(2); camera.take_photo()
	check(int(film.active_roll().exposures_used)==2,"A new crop creates a second exposure")
	var roll_id:String=str(film.active_roll().id)
	game.current_location="cafe"
	check(film.dropoff(roll_id,"rush").ok,"Send physical film for processing")
	game.use_free_time(int(film.config.processing.rush.minutes)); film.update_processing()
	var pickup:Dictionary=await film.pickup(roll_id)
	check(pickup.ok,"Pick up developed pictures")
	check(photo_library.list_photos().size()==2,"Developed photos enter the local album once")
	var stored:=photo_library.list_photos()[0]
	var original:=photo_library.load_photo(str(stored.photo_id))
	check(original!=null and original.get_width()>0,"Photo survives reload")
	check(photo_library.load_photo("../../outside")==null,"Untrusted photo path rejected")
	camera.queue_free()
	await process_frame
	var album = load("res://scripts/town_sound/PhotoAlbum.gd").new()
	album.library = photo_library
	album.selection_mode = true
	town._show_pocket_panel(album)
	await process_frame
	check(album.get_child_count() > 0, "Album did not render")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://tests/screenshots")
		root.get_texture().get_image().save_png("user://tests/screenshots/local-album.png")
	album.queue_free()
	await process_frame
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://tests/screenshots/pocket-toolbar.png")
	town.queue_free()
	await process_frame
	print("POCKET_MEDIA_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)
