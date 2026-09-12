extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := root.get_node("GameState")
	game.begin_vertical_slice("A")
	game.current_location = "residence"
	var town = load("res://scenes/town_day.tscn").instantiate()
	root.add_child(town)
	await process_frame
	await process_frame
	if is_instance_valid(town.opening_overlay): town.opening_overlay.hide()
	town._open_record_store()
	check(not is_instance_valid(town.pocket_panel), "Studio allowed away from record store")
	var forbidden_studio = load("res://scripts/town_sound/studio/StudioScreen.gd").new()
	town.add_child(forbidden_studio)
	await process_frame
	check(not is_instance_valid(forbidden_studio), "Direct Studio construction bypassed location guard")
	town._open_pocket_recorder()
	check(is_instance_valid(town.pocket_panel), "Recorder did not open")
	check(not town.pocket_panel.can_edit_here(), "Pocket recorder exposed shop actions")
	check(town.pocket_panel.source_picker.selected == 0, "Game sound is not the default source")
	check(not town.pocket_panel.device_row.visible, "Microphone has priority in game capture UI")
	town.pocket_panel.set_compact(true)
	check(town.pocket_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Compact recorder blocks town interactions")
	check(not town.pocket_panel.page_scroll.visible and town.pocket_panel.compact_bar.visible, "Compact recorder layout failed")
	town.pocket_panel.set_compact(false)
	town.pocket_panel.draft = AudioStreamWAV.new()
	check(town._guard_pocket_audio(), "Unsaved compact recording can be lost on scene transition")
	town.pocket_panel.draft = null
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://tests/screenshots")
		root.get_texture().get_image().save_png("user://tests/screenshots/game-recorder.png")
	var first_id: int = town.pocket_panel.get_instance_id()
	town._open_pocket_recorder()
	check(town.pocket_panel.get_instance_id() == first_id, "Duplicate recorder opened")
	town.pocket_panel.queue_free()
	await process_frame
	check(auto_accept_quit, "Closing recorder did not restore main window close behavior")
	game.current_location = "record_store"
	town.selected_location = "record_store"
	town._refresh()
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
	camera.take_photo()
	camera.take_photo()
	check(photo_library.list_photos().size() == 1, "Duplicate shutter saved duplicate image")
	var stored := photo_library.list_photos()[0]
	var restored := PhotoLibrary.new()
	restored.root_path = photo_library.root_path
	var original := restored.load_photo(stored.photo_id)
	check(original != null and original.get_width() > 0, "Photo did not survive reload")
	check(restored.load_photo("../../outside") == null, "Untrusted photo path accepted")
	camera.zoom.value = 2
	camera.take_photo()
	check(photo_library.list_photos().size() == 2, "New crop not saved")
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
