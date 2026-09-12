extends SceneTree
## Run with a real renderer: cover capture requires a rendered viewport.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var host = load("res://scenes/Main.tscn").instantiate()
	root.add_child(host)
	await process_frame
	var studio = load("res://scripts/studio/StudioScreen.gd").new()
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(studio)
	await process_frame
	var model := Arrangement.new()
	var pcm := PackedFloat32Array()
	pcm.resize(22050 * 8)
	for i in pcm.size(): pcm[i] = sin(float(i) / 22050 * TAU * 220) * 0.1
	model.cache["test_a"] = {"pcm": pcm, "rate": 22050}
	model.cache["test_b"] = {"pcm": pcm, "rate": 22050}
	model.add_sample({"id": "test_a", "name": "TEST A", "duration": 8.0}, 0, 0)
	model.add_sample({"id": "test_b", "name": "TEST B", "duration": 8.0}, 1, 0)
	studio.model = model
	studio.timeline.arrangement = model
	var wav := model.mix()
	check(wav != null, "Mix failed")
	var room = load("res://scripts/visual/VisualRoom.gd").new()
	room.studio = studio
	room.model = model
	room.audio = wav
	host.add_child(room)
	await process_frame
	check(VisualCanvas.parse_prompt("黑红尖锐快密集", 42).palette == "red", "Chinese parsing failed")
	check(VisualCanvas.parse_prompt("blue calm slow", 42).speed == 0.3, "English parsing failed")
	var first_shapes: Array = room.canvas.shapes.duplicate(true)
	room.canvas.configure(wav, model.prompt, model.seed_value)
	check(first_shapes == room.canvas.shapes, "Seed changed shape generation")
	room.canvas.time = 1.0
	room.canvas.analyze()
	check(room.canvas.features[0] > 0.05, "RMS not audio-driven")
	var table = load("res://scripts/record_shop/PressingTable.gd").new()
	table.room = room
	table.model = model
	table.audio = wav
	table.profile = room.canvas.profile
	table.library.root_path = "user://tests/records_" + Crypto.new().generate_random_bytes(8).hex_encode()
	room.add_child(table)
	await process_frame
	table.title_input.text = "Integration Test"
	table.artist_input.text = "Test Runner"
	table.advance()
	await create_timer(0.25).timeout
	await table.advance()
	check(table.cover != null and table.cover.get_width() == 512, "Cover capture failed")
	for stage in range(2, 11):
		check(table.step == stage, "Unexpected packaging stage")
		if OS.get_cmdline_user_args().has("--screenshots"):
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("user://tests/screenshots")
			root.get_texture().get_image().save_png("user://tests/screenshots/pressing-%02d.png" % stage)
		await table.complete_action()
	check(table.step == 11, "Packaging did not finish")
	check(not table.saved_record.is_empty(), "Final record not saved")
	var restored := LocalRecordLibrary.new()
	restored.root_path = table.library.root_path
	check(restored.list_records().size() == 1, "Saved record not reloaded")
	check(restored.money() >= 60 and restored.money() <= 180, "Payment outside bounds")
	check(FileAccess.file_exists(table.saved_record.final_audio_path), "Final WAV missing")
	check(FileAccess.file_exists(table.saved_record.cover_path), "Cover PNG missing")
	var online := OnlineRecordLibrary.new()
	check(not online.can_upload(), "Unconfigured backend allowed upload")
	print("FULL_LOCAL_FLOW: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(failures)
