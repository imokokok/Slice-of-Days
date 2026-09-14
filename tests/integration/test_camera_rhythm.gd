extends SceneTree

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var state = root.get_node("GameState")
	state.begin_new_game("A")
	var a_schedule: Dictionary = state.schedule_for("A", 1)
	var b_schedule: Dictionary = state.schedule_for("B", 1)
	check(int(a_schedule.get("wake", 0)) == 420 and int(b_schedule.get("start", 0)) == 420, "Both roles should wake at 07:00 while B can act immediately")
	check(int(a_schedule.get("start", 0)) == 480, "A's morning run should consume 07:00-08:00 before free exploration")
	state.current_minute = 1140
	state.current_role = "A"
	state.completed_commitments.clear()
	state.shared_state.erase("pending_commitment")
	state.advance_to_next_free_block()
	check(state.current_minute == 1200, "A's reserved night run should consume 19:00-20:00")
	check(state.completed_commitments.any(func(token: String) -> bool: return token.contains("a_night_run")), "Night run should be recorded as a completed routine")

	state.begin_new_game("A")
	state.current_minute = 500
	state.current_location = "town_entrance"
	state.commit_active_role_state()
	change_scene_to_file("res://scenes/town_day.tscn")
	await create_timer(0.9).timeout
	var camera = load("res://scripts/town_sound/PocketCamera.gd").new()
	var test_frame := Image.load_from_file(ProjectSettings.globalize_path("res://art/scene_atlas/01.jpg"))
	if test_frame == null or test_frame.is_empty():
		test_frame = Image.create(1600, 900, false, Image.FORMAT_RGBA8)
		test_frame.fill(Color("718f96"))
	camera.source = test_frame
	camera.context = {"location":"town_entrance", "title":"小镇街道公共区域", "day":1, "role":"A", "game_minute":500}
	current_scene._show_pocket_panel(camera)
	await process_frame
	check(is_instance_valid(camera), "Pocket camera should open from the street")
	if not is_instance_valid(camera):
		quit(1)
		return
	camera.library.root_path = "user://tests/camera_rhythm_photos_" + Crypto.new().generate_random_bytes(6).hex_encode()
	check(camera.subjects.size() >= 2 and not camera.current_subject.is_empty(), "Camera should expose authored scenery and focus the centered discovery")
	check(camera.find_children("*", "HSlider", true, false).is_empty(), "Camera should no longer look like a three-slider utility form")
	camera.take_photo()
	await create_timer(0.55).timeout
	check(camera.capture_card.visible, "A successful shot should create an immediate photo card")
	check((state.artifacts.get("photo_subjects", []) as Array).size() == 1, "Recognized scenery should enter the persistent field guide")
	var saved: Array[Dictionary] = camera.library.list_photos()
	check(saved.size() == 1 and str(saved[0].get("subject_name", "")).is_empty() == false, "Photo metadata should retain the recognized subject")
	if OS.get_cmdline_user_args().has("--screenshots") and root.get_texture() != null:
		await process_frame
		root.get_texture().get_image().save_png("/private/tmp/solmere-camera-redesign.png")
		var album = load("res://scripts/town_sound/PhotoAlbum.gd").new()
		album.library = camera.library
		camera.queue_free()
		await process_frame
		await process_frame
		current_scene._show_pocket_panel(album)
		await process_frame
		root.get_texture().get_image().save_png("/private/tmp/solmere-album-redesign.png")
	print("CAMERA + RHYTHM: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)
