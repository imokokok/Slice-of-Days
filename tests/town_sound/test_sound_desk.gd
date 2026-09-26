extends SceneTree
var failures:=0
var host: Control
var desk: Control
func _initialize() -> void: call_deferred("run")
func check(ok:bool,message:String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1; push_error(message)
func shot(name:String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests/sound_desk")
	root.get_texture().get_image().save_png("user://tests/sound_desk/"+name+".png")
func mouse(target:Control,at:Vector2,pressed:bool) -> void:
	var event:=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=at
	target._gui_input(event)
func motion(target:Control,at:Vector2) -> void:
	var event:=InputEventMouseMotion.new(); event.position=at; event.button_mask=MOUSE_BUTTON_MASK_LEFT; target._gui_input(event)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game()
	var gs=root.get_node("GameState"); gs.current_location="park"; gs.current_minute=545; gs.combine_flexible_time()
	var world=root.get_node("WorldSound"); world.set_location("park"); world.set_active(true)
	var recorder=load("res://scripts/residency/recorder_lite.gd").new(); root.add_child(recorder); await process_frame
	recorder.toggle_recording(); await create_timer(3).timeout
	check(recorder.live_screen.energy>0,"Visible recorder MV receives real captured audio")
	await shot("01_recording")
	recorder.toggle_recording(); check(recorder.saved,"Stopping retains sample and visual recipe")
	recorder.free(); await process_frame
	gs.current_location="record_store"
	host=load("res://scenes/town_sound/Recorder.tscn").instantiate(); host.shop_mode=true; root.add_child(host); await process_frame
	host._open_studio(); await process_frame
	for child in host.get_children():
		if child.get_script()==load("res://scripts/town_sound/studio/StudioScreen.gd"): desk=child
	check(desk!=null,"Actual shop path opens scrapbook desk")
	if desk==null: quit(1); return
	check(desk.model.clips.is_empty(),"Fresh journey starts with contextual empty guidance")
	var items:=SampleStore.new().list_samples()
	desk.selected=desk.model.add_sample(items[0],0,0); desk.timeline.selected=desk.selected; desk.changed()
	await process_frame
	check(desk.timeline.view_seconds==12,"Short sounds get a legible adaptive paper scale")
	check(desk.mv.is_visible_in_tree() and desk.mv.size.x>500,"MV is always beside editing, never a hidden settings page")
	check(desk.mute_controls.is_empty(),"No track mute UI remains")
	var original:Array=desk.model.clips.duplicate(true)
	desk.timeline.selection_mode=true
	var scale_x:float=desk.timeline.size.x/desk.timeline.view_seconds
	mouse(desk.timeline,Vector2(.6*scale_x,57),true)
	# A fast OS drag can coalesce motion events. The release still owns the endpoint.
	mouse(desk.timeline,Vector2(1.2*scale_x,57),false)
	check(is_equal_approx(desk.region_end-desk.region_start,.6),"Fast drag uses release coordinates even without a motion event")
	check(not desk.cut_control.disabled,"Mouse range enables contextual scissors")
	desk.edit_region(false)
	check(desk.model.clips.size()==2,"Cutting the middle preserves two audible sides")
	desk._undo_edit(); check(desk.model.clips==original,"Undo restores source ranges exactly")
	desk.timeline.selection_mode=false; desk.selected=0; desk.timeline.selected=0; desk.build_inspector(); desk._guide()
	var volume: HSlider
	var speed: OptionButton
	for child in desk.inspector.get_children():
		if child is HSlider: volume=child
		if child is OptionButton: speed=child
	volume.value=.55; volume.drag_ended.emit(true)
	check(is_equal_approx(float(desk.model.clips[0].volume),.55),"Volume changes actual clip gain")
	var before:float=desk.model.clips[0].length
	speed.item_selected.emit(1)
	check(is_equal_approx(float(desk.model.clips[0].length),before/.75),"Speed changes actual playback duration")
	await desk.play(); await create_timer(.7).timeout
	check(desk.player.playing and desk.mv.audio==desk.mixdown,"MV analyzes the exact audible edited mix")
	check(desk.mv.time>0 and desk.has_listened,"MV playhead and onboarding advance with listening")
	await shot("02_desk")
	print("GUIDE_METRICS ",desk.tutorial.size," ",desk.tutorial.get_line_count()," ",var_to_str(desk.tutorial.text))
	desk.pause()
	root.size=Vector2i(1280,720); await process_frame; await process_frame
	check(desk.desk.get_global_rect().end.x<=root.get_visible_rect().end.x+1,"Desk fits 1280 wide without horizontal scrolling")
	await shot("03_small_window")
	root.size=Vector2i(1600,900); await process_frame
	if OS.get_cmdline_user_args().has("--manual"):
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(1280,720)
		root.position=Vector2i(90,90)
		root.title="Town Sound - sound scrapbook check"
		print("SOUND_DESK_UI: PASS failures=",failures,"; manual desk ready")
		return
	await desk.open_visual(); await process_frame
	var room:Control
	for child in host.get_children():
		if child.get_script()==load("res://scripts/town_sound/visual/VisualRoom.gd"): room=child
	check(room!=null,"A single short recording can start free record creation")
	if room!=null:
		await room.submit()
		check(room.pressing!=null,"One recording reaches the physical pressing table")
		await shot("04_pressing")
	host.free(); world.set_active(false)
	await process_frame
	print("SOUND_DESK_UI: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
