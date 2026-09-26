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
	var film=root.get_node("FilmSystem")
	game.current_location="cafe"; game.current_minute=660
	film.notice_camera(); check(film.acquire_camera(false).ok,"Camera is obtained through the actual shop transaction")
	await town._open_pocket_camera()
	await process_frame; await process_frame
	var camera = town.pocket_panel
	check(camera.source != null and not camera.source.is_empty(), "Camera did not capture game scene")
	var photo_library := PhotoLibrary.new()
	photo_library.root_path = "user://tests/photos_" + Crypto.new().generate_random_bytes(8).hex_encode()
	camera.library = photo_library
	camera.take_photo(); camera.take_photo()
	await create_timer(.5).timeout
	check(film.active_roll().exposures_used==1,"A repeated shutter during capture consumes only one exposure")
	check(photo_library.list_photos().is_empty(),"Unprocessed film does not pretend to be developed photos")
	camera._set_zoom(1.6); await camera.take_photo(); await create_timer(.4).timeout
	check(film.active_roll().exposures_used==2,"A second cropped exposure is retained")
	var roll_id: String=film.active_roll().id
	game.current_minute=690
	check(film.dropoff(roll_id,"rush").ok,"Real grocery drop-off starts processing")
	game.spend_time(180)
	check((await film.pickup(roll_id)).ok,"Photos become available only after processing and collection")
	var stored_photos: Array=photo_library.list_photos()
	check(stored_photos.size()==2,"Both developed photographs are present in the local library")
	if stored_photos.is_empty(): quit(1); return
	var restored:=PhotoLibrary.new(); restored.root_path=photo_library.root_path
	var original: Image=restored.load_photo(str(stored_photos[0].photo_id))
	check(original!=null and original.get_width()>0,"Developed photograph survives a new library instance")
	check(restored.load_photo("../../outside")==null,"Untrusted photo path is rejected")
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
