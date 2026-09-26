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
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game()
	root.get_node("GameState").current_location = "record_store"
	var gs=root.get_node("GameState")
	gs.current_minute=545
	check(gs.combine_flexible_time(),"Player can combine adjacent private time before pressing")
	check(root.get_node("GameplayModuleSystem").entry_check("sound_sampling",60).ok,"Delivery fixture has a real free hour during opening hours")
	var host = load("res://scenes/town_sound/Recorder.tscn").instantiate()
	root.add_child(host)
	await process_frame
	var studio = load("res://scripts/town_sound/studio/StudioScreen.gd").new()
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
	var room = load("res://scripts/town_sound/visual/VisualRoom.gd").new()
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
	var table = load("res://scripts/town_sound/record_shop/PressingTable.gd").new()
	table.room = room
	table.model = model
	table.audio = wav
	table.profile = room.canvas.profile
	table.library.root_path = "user://tests/records_" + Crypto.new().generate_random_bytes(8).hex_encode()
	room.page.add_child(table)
	room.column.hide()
	await process_frame
	table.title_input.text = "潮汐来信"
	table.artist_input.text = "Solmere"
	table.advance()
	if OS.get_cmdline_user_args().has("--photo-cover"):
		var photo_library := PhotoLibrary.new()
		photo_library.root_path = "user://tests/cover_photos_" + Crypto.new().generate_random_bytes(8).hex_encode()
		var photo := Image.create(640, 360, false, Image.FORMAT_RGB8)
		photo.fill(Color("1d7682"))
		var metadata := photo_library.save_photo(photo, {"title": "Cover test"})
		table.use_photo_cover(photo_library.load_photo(metadata.photo_id), metadata)
	await create_timer(0.25).timeout
	await table.advance()
	check(table.cover != null and table.cover.get_width() == 512, "Cover capture failed")
	var album_art=load("res://scripts/town_sound/record_shop/AlbumCover.gd")
	var blank:=Image.create(512,512,false,Image.FORMAT_RGB8); blank.fill(Color("1d7682"))
	var named: Image=await album_art.bake(table,blank,"午后的风 / Afternoon Wind","Solmere",1)
	var unnamed: Image=await album_art.bake(table,blank,"","Solmere",1)
	check(named.get_region(Rect2i(32,45,448,107)).get_data()!=unnamed.get_region(Rect2i(32,45,448,107)).get_data(),"Player title must be printed into the saved image pixels")
	var long_title: Image=await album_art.bake(table,blank,"给今天听见的风和街道写一封很长很长的信".repeat(3).left(60),"一位走过街道收集声音的旅人".repeat(3).left(40),1)
	check(long_title.get_pixel(256,256).is_equal_approx(Color("1d7682")),"Long names preserve the artwork panel")
	DirAccess.make_dir_recursive_absolute("user://tests/screenshots")
	named.save_png("user://tests/screenshots/sleeve-latin.png")
	long_title.save_png("user://tests/screenshots/sleeve-long-title.png")
	table.cover.save_png("user://tests/screenshots/sleeve-chinese.png")
	for stage in range(2, 11):
		check(table.step == stage, "Unexpected packaging stage")
		if OS.get_cmdline_user_args().has("--screenshots"):
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("user://tests/screenshots")
			root.get_texture().get_image().save_png("user://tests/screenshots/pressing-%02d.png" % stage)
		if stage == 10 and OS.get_cmdline_user_args().has("--save-retry"):
			var good_path: String = table.library.root_path
			DirAccess.make_dir_recursive_absolute("user://tests")
			var blocked_path := "user://tests/blocked_record_output"
			var blocker := FileAccess.open(blocked_path, FileAccess.WRITE)
			blocker.store_string("test-only directory blocker")
			blocker.close()
			table.library.root_path = blocked_path
			await table.complete_action()
			check(table.step == 10 and not table.locked and not table.next_button.disabled, "Failed record save cannot be retried")
			table.library.root_path = good_path
			DirAccess.remove_absolute(blocked_path)
		if stage==10:
			var down:=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; down.position=table.source_rect().get_center()
			table._gui_input(down)
			var drop:=InputEventMouseButton.new(); drop.button_index=MOUSE_BUTTON_LEFT; drop.position=table.target_rect().get_center()
			table._gui_input(drop)
			check(table.locked,"Dropping the packed sleeve onto the tray starts the handover")
			await create_timer(1.75).timeout
			if OS.get_cmdline_user_args().has("--screenshots"):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("user://tests/screenshots/pressing-turn.png")
			await create_timer(2.0).timeout
		else: await table.complete_action()
	check(table.step == 11, "Packaging did not finish: step=%d %s" % [table.step,table.instructions.text])
	check(not table.saved_record.is_empty(), "Final record not saved")
	check(int(table.saved_record.get("packaging_version",0))==2,"Physical packaging version persisted")
	check(table.saved_record.get("packaging_layers",[]).size()==3,"Inner sleeve, jacket and plastic outer sleeve are separate saved layers")
	check(table.saved_record.get("spine_title","")=="潮汐来信" and table.saved_record.get("spine_artist","")=="Solmere","Title and artist survive the handover")
	check(table.saved_record.get("shelf_orientation","")=="upright_spine","Record is stored upright with its spine facing out")
	var artwork=load("res://scripts/town_sound/record_shop/PackagingArtwork.gd")
	var resting: Dictionary=artwork.shelf_pose(1,Vector2(330,602))
	var stored_rect: Rect2=resting.spine
	check(is_equal_approx(stored_rect.size.y,121) and is_equal_approx(stored_rect.end.y,501),"Player record matches the neighboring sleeves' height and shelf baseline")
	check(resting.face_scale.x<.001 and stored_rect.size.x<stored_rect.size.y*.2,"Final pose shows a narrow upright spine instead of a shrunken front cover")
	check(table.next_button.visible and not table.next_button.disabled,"Player can leave after shelving")
	var restored := LocalRecordLibrary.new()
	restored.root_path = table.library.root_path
	check(restored.list_records().size() == 1, "Saved record not reloaded")
	check(restored.money() >= 60 and restored.money() <= 180, "Payment outside bounds")
	check(FileAccess.file_exists(table.saved_record.final_audio_path), "Final WAV missing")
	check(FileAccess.file_exists(table.saved_record.cover_path), "Cover PNG missing")
	var saved_cover:=Image.load_from_file(table.saved_record.cover_path)
	check(saved_cover.get_data()==table.cover.get_data(),"Reloaded cover retains the printed title and photograph")
	if OS.get_cmdline_user_args().has("--photo-cover"):
		check(table.saved_record.cover_source == "photo", "Photo cover source not saved")
		var cover_image := Image.load_from_file(table.saved_record.cover_path)
		check(cover_image.get_pixel(256, 256).is_equal_approx(Color("1d7682")), "Photo cover pixels differ from selected photo")
	var online := OnlineRecordLibrary.new()
	check(not online.can_upload(), "Unconfigured backend allowed upload")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://tests/screenshots/pressing-11.png")
	var look:=InputEventMouseButton.new(); look.button_index=MOUSE_BUTTON_LEFT; look.pressed=true; look.position=artwork.shelf_hit_rect().get_center()
	table._gui_input(look)
	check(table.inspecting_record,"Clicking the player's spine reveals its actual cover")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://tests/screenshots/pressing-inspect.png")
	table._gui_input(look)
	check(not table.inspecting_record and table.library.list_records().size()==1,"Closing inspection does not duplicate the saved record")
	var shelf=load("res://scripts/town_sound/record_shop/RecordShelf.gd").new(); shelf.host=host; shelf.library.root_path=table.library.root_path; root.add_child(shelf)
	await process_frame; shelf.listen(table.saved_record); await create_timer(.4).timeout
	check(shelf.player.playing and shelf.visual.time>0,"Saved record plays its WAV and MV on the real shelf")
	check(shelf.visual.get_global_rect().end.y<=root.get_visible_rect().end.y,"Shelf MV remains visible beside the record list")
	shelf._toggle(); var paused:float=shelf.visual.time; await create_timer(.1).timeout
	check(is_equal_approx(paused,shelf.visual.time),"Pausing the record also pauses its MV")
	if OS.get_cmdline_user_args().has("--manual-shelf") and failures==0:
		print("FULL_LOCAL_FLOW: PASS failures=0")
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1280,720); root.position=Vector2i(90,90)
		root.title="Town Sound - Record Shelf QA"
		return
	shelf.free(); await process_frame
	print("FULL_LOCAL_FLOW: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	if OS.get_cmdline_user_args().has("--manual-sleeve") and failures==0:
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1280,720); root.position=Vector2i(90,90)
		root.title="Town Sound named sleeve - main check"
		return
	quit(failures)
