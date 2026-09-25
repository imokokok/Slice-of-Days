extends SceneTree
## Run with a real renderer: cover capture requires a rendered viewport.
var failures := 0
var table_capture: Control
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
	room.add_child(table)
	await process_frame

	table_capture=table
	table.title_input.text="潮汐来信"
	table.artist_input.text="Solmere"
	table.advance()
	await table.advance()
	# A stationary click is not a press; pull the handle before the dwell starts.
	if not OS.get_cmdline_user_args().has("--manual"):
		table.step=4
		var down:=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; down.position=Vector2(813,513)
		table._gui_input(down)
		await create_timer(1.1).timeout
		check(table.step==4 and not table.locked,"Holding without pulling must not operate the press")
		var pull:=InputEventMouseMotion.new(); pull.position=Vector2(813,633); pull.button_mask=MOUSE_BUTTON_MASK_LEFT
		table._gui_input(pull)
		await create_timer(.7).timeout
		check(table.locked,"Pulling and holding activates the physical press")
		await create_timer(4.6).timeout
		check(table.step==5,"Press completes before sleeve packing")
	# Continue at the physical packing stage after the earlier full-flow test.
	table.step=5
	table.instructions.text=table.STEPS[5]+"\n"+table.HINTS[5]
	table.next_button.text="辅助操作：滑入内袋"
	table.queue_redraw()
	if OS.get_cmdline_user_args().has("--manual"):
		root.title="Town Sound packaging - main check"
		return
	create_timer(45).timeout.connect(func(): push_error("Packaging gesture timeout"); quit(2))
	var down:=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true
	down.position=table.source_rect().get_center()+Vector2(65,0)
	table._gui_input(down)
	check(not table.dragging,"Groove area cannot be grabbed")
	down.position=table.source_rect().get_center()+Vector2(103,0)
	table._gui_input(down)
	check(table.drag_position.is_equal_approx(table.source_rect().get_center()),"Rim grab preserves center without a jump")
	var up:=InputEventMouseButton.new(); up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false; up.position=Vector2(200,500)
	table._gui_input(up)
	check(table.step==5 and not table.locked and not table.dragging,"Wrong drop returns the record without advancing")
	for stage in range(5,10):
		check(table.step==stage,"Physical stage order")
		var offset:=Vector2(103,0) if stage==5 else Vector2(15,5)
		down.position=table.source_rect().get_center()+offset; table._gui_input(down)
		check(table.dragging,"Object has a matching visible hit area at stage %d"%stage)
		var motion:=InputEventMouseMotion.new(); motion.position=table.target_rect().get_center()+offset
		table._gui_input(motion)
		up.position=motion.position; table._gui_input(up)
		check(table.locked,"Aligned drop starts insertion at stage %d"%stage)
		await create_timer(.8 if stage<8 else .4).timeout
		await capture("during_%d"%stage)
		await create_timer(1.6 if stage<8 else 1.0).timeout
		check(table.step==stage+1,"Physical operation completes at stage %d"%stage)
		await capture("after_%d"%stage)
	print("PACKAGING_GESTURES: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests/packaging_v2")
	var frame:=root.get_texture().get_image()
	frame.save_png("user://tests/packaging_v2/"+id+".png")
	var scale_factor:=Vector2(frame.get_size())/table_capture.size
	if id=="during_5":
		var point:=Vector2(760,520)*scale_factor
		var pixel:=frame.get_pixel(int(point.x),int(point.y))
		check(pixel.is_equal_approx(Color("eee8d8")),"Paper front occludes the entering disc below the mouth")
	if id=="after_5":
		var point:=Vector2(760,630)*scale_factor
		var pixel:=frame.get_pixel(int(point.x),int(point.y))
		check(pixel!=Color("eee8d8"),"Circular window preserves the disc label after insertion")
