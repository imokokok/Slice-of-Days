extends SceneTree
const Atlas=preload("res://scripts/town_sound/data/SoundAtlas.gd")
var failures:=0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://tests/music_release")
	root.get_texture().get_image().save_png("user://tests/music_release/"+name+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	create_timer(90).timeout.connect(func(): push_error("Music journey timeout"); quit(3))
	root.get_node("ChapterSystem").start_new_game()
	var gs=root.get_node("GameState")
	var world=root.get_node("WorldSound")
	var items: Array[Dictionary]=[]
	for place in ["night_market","park"]:
		gs.current_location=place
		world.set_location(place); world.set_active(true)
		var recorder=load("res://scripts/residency/recorder_lite.gd").new()
		root.add_child(recorder)
		await process_frame
		recorder.sound_kind="fire" if place=="night_market" else "wind"
		recorder.toggle_recording()
		await create_timer(1.3).timeout
		check(recorder.recorder.frame_count>0,"Main-game pocket tool captures PCM: "+place)
		check(not recorder.recorder.microphone.playing,"Game recording does not activate microphone")
		await capture("recording_"+place)
		recorder.toggle_recording()
		check(recorder.saved,"Stop actually saves the sound")
		var listed:=SampleStore.new().list_samples()
		check(not listed.is_empty(),"Recording appears in the current journey library")
		if not listed.is_empty(): items.append(listed[-1])
		recorder.free()
		await process_frame
	check(items.size()==2 and items[0].sound_kind=="fire" and items[1].sound_kind=="wind","Source identity survives local save")
	check(items.size()==2 and not items[0].mv_events.is_empty(),"Synchronous MV event recipe is saved")
	gs.current_location="record_store"
	world.set_location("record_store")
	var shop=load("res://scripts/town_sound/record_shop/RecordShop.gd").new()
	root.add_child(shop); await process_frame
	check(shop.samples.size()>=2,"Real shop sees the collected recordings")
	await capture("record_shop")
	shop.open_recorder(true); await process_frame
	var host=shop.modal
	var studio: Control
	for child in host.get_children():
		if child.get_script()==load("res://scripts/town_sound/studio/StudioScreen.gd"): studio=child
	check(studio!=null,"Shop opens real Studio, not the narrative prototype")
	if studio==null: quit(1); return
	studio.model.clips.clear(); studio.build_starter()
	check(studio.model.clips.size()>=2 and is_equal_approx(studio.model.length(),16),"Starter uses owned recordings to make an editable arrangement")
	var wav: AudioStreamWAV=studio.model.mix()
	check(wav!=null and not wav.data.is_empty(),"Arrangement renders to actual WAV")
	if wav==null: quit(1); return
	check(Atlas.audible_kinds(studio.model).size()>=2,"Only audible tracks qualify for collection commissions")
	studio.model.muted[0]=true; studio.model.muted[1]=true
	check(Atlas.audible_kinds(studio.model).is_empty(),"Muted tracks cannot qualify for commissions")
	studio.model.muted[0]=false; studio.model.muted[1]=false
	await capture("studio")
	var viewport:=SubViewport.new(); viewport.size=Vector2i(960,540); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var visual:=VisualCanvas.new(); visual.size=Vector2(960,540); visual.model=studio.model; visual.configure(wav,"像素",73); viewport.add_child(visual)
	visual.time=.5; visual.queue_redraw(); await RenderingServer.frame_post_draw
	var fire_image:=viewport.get_texture().get_image()
	fire_image.save_png("user://tests/music_release/mv_fire.png")
	visual.time=3; visual.queue_redraw(); await RenderingServer.frame_post_draw
	var wind_image:=viewport.get_texture().get_image()
	wind_image.save_png("user://tests/music_release/mv_wind.png")
	check(fire_image.get_data()!=wind_image.get_data(),"Timeline changes switch pixel imagery with the sources")
	var library:=LocalRecordLibrary.new(); library.root_path="user://tests/music_records_"+str(Time.get_ticks_msec())
	var record:=library.save_record({"title":"Fire and Wind","artist":"Test","duration":wav.get_length(),"sound_kinds":Atlas.kinds_in(studio.model.clips),"mv_clips":studio.model.clips.duplicate(true)},wav,wind_image)
	check(not record.is_empty() and Atlas.meets(Atlas.QUESTS[1],record),"Completed work qualifies for the fire/wind commission")
	check(not Atlas.meets(Atlas.QUESTS[2],record),"Unmet commission cannot be faked by pressing a button")
	check(library.list_records().size()==1,"Record and its MV recipe survive disk reload")
	viewport.free(); shop.free(); world.set_active(false)
	await process_frame
	print("MUSIC_JOURNEY failures=",failures)
	quit(failures)
