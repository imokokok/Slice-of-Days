extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1; push_error(label)
func settle() -> void: await process_frame; await process_frame; await create_timer(.2).timeout
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game()
	var gs=root.get_node("GameState"); var router=root.get_node("SceneRouter")
	var session=root.get_node("RecordingSession"); var global=root.get_node("GlobalRecorder"); var world=root.get_node("WorldSound")
	gs.current_location="residence"; gs.current_minute=600
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	check(global.available() and global.pocket.visible,"Recorder exists in main town")
	var view=global.open_recorder(); await settle()
	check(view.source_picker.selected==0,"Gameplay capture is default; microphone is explicit")
	view.toggle_recording(); await create_timer(1).timeout
	check(session.recorder.capturing and view.live_screen.energy>0,"Actual game audio drives live MV")
	var device:int=session.recorder.get_instance_id(); var frames:int=session.recorder.frame_count
	view.put_away(); await settle()
	check(not global.focused() and global.thumbnail.visible,"Pocketed recorder keeps a visible live picture")
	router.enter_space("home_a"); await create_timer(1.2).timeout
	check(current_scene.scene_file_path.ends_with("interactive_space.tscn"),"Real door route enters home")
	check(global.available() and session.recorder.get_instance_id()==device and session.recorder.frame_count>frames,"Capture and device survive an actual scene transition")
	world.play_kind("paper",-14,.5); world.play_kind("wood",-15,.5)
	check(world.world_pool.busy_players.size()>=2,"Overlapping physical sounds do not cut each other off")
	await create_timer(.7).timeout
	check(world.world_pool.busy_players.is_empty(),"Audio pool recycles finished players")
	session.stop(); await settle()
	var item:Dictionary=session.last_sample.duplicate(true)
	check(session.saved and float(item.get("signal_peak",0))>.0001,"Stop auto-saves non-silent real PCM")
	check(item.get("mv_events",[]).any(func(e): return str(e.kind)=="paper"),"Saved MV retains actual physical sound events")
	check(session.rename_sample(item,"回家路上的纸声"),"Rename commits through shared collection service")
	global.open_library(); await settle()
	check(global.collection.selected.name=="回家路上的纸声","Global collection reads the same saved audio and title")
	global.collection._play(); await create_timer(.4).timeout
	check(global.collection.player.playing and global.collection.picture.time>0,"Library plays audio and synchronized pixel MV")
	global.collection._close(); await settle()
	# No preview or interface sound may bleed into the next world recording.
	world.set_active(false); await create_timer(.3).timeout
	session.start("game"); session.playback.play(); world.play_ui("record_start")
	await create_timer(1).timeout; session.stop(); session.playback.stop()
	check(float(session.last_sample.get("signal_peak",1))<.0001,"Music preview and recorder UI are excluded from world capture")
	# Simulate a crash after file write but before state commit, then recover from disk.
	world.set_active(true); session.start("game"); await create_timer(1.2).timeout
	var saves=root.get_node("SaveManager"); var original=saves.get_script(); var fail:=GDScript.new()
	fail.source_code="extends \"res://scripts/core/save_manager.gd\"\nfunc save_or_report(_context := \"\") -> bool:\n\treturn false\n"
	check(fail.reload()==OK,"Storage failure fixture compiles")
	saves.set_script(fail); session.stop()
	var pending_id:String=str(session.pending_sample.get("id",""))
	check(session.pending_wav!=null and not pending_id.is_empty(),"Save failure preserves both PCM and stable identity")
	session.pending_wav=null; session.pending_sample={}; session.context={}; session.playback.stream=null
	check(session.recover_pending() and session.playback.stream.get_length()>1,"Restart recovery loads a real disk checkpoint")
	saves.set_script(original); check(session.save_pending(),"Recovered recording retries successfully")
	check(str(session.last_sample.id)==pending_id,"Recovery reuses the original file, never duplicates")
	check(gs.artifacts.samples.filter(func(row):return str(row.id)==pending_id).size()==1,"Recovered audio has exactly one collection entry")
	# Atomic rename/delete must roll back when state persistence fails.
	item=session.last_sample.duplicate(true); saves.set_script(fail)
	check(not session.rename_sample(item,"uncommitted"),"Rename reports a failed state write")
	check(SampleStore.new().list_samples().filter(func(row):return str(row.id)==str(item.id))[0].name==item.name,"Failed rename restores metadata")
	check(not session.delete_sample(item) and FileAccess.file_exists(item.file_path),"Failed delete restores original audio")
	saves.set_script(original)
	# Runtime capacity must allow more than the old 20-entry demo cap.
	var store:=SampleStore.new("user://tests/global_capacity_"+str(Time.get_ticks_msec()))
	var short:=AudioStreamWAV.new(); short.mix_rate=22050; short.format=AudioStreamWAV.FORMAT_16_BITS; short.data=PackedByteArray([0,0,1,0])
	for i in 21: store.save_sample(short,str(i))
	check(store.list_samples().size()==21,"Collection supports more than twenty samples")
	# Native activity and extensions share the same physical bus and HUD.
	for script in ["res://scripts/ui/native_module_game.gd","res://scripts/ui/components/cooking_board.gd","res://extensions/collage_letter/scripts/audio_manager.gd","res://extensions/observatory/scripts/audio_manager.gd","res://extensions/myriorama_tarot/scripts/sound.gd"]:
		check(load(script)!=null,"Integrated script compiles: "+script.get_file())
	gs.begin_new_game("A"); gs.switch_to_role("A",5,true); gs.shared_state["journey_id"]=Crypto.new().generate_random_bytes(12).hex_encode(); gs.current_location="night_market"; gs.current_minute=690
	root.get_node("ChapterSystem").story().reveal_completed=true
	await settle()
	check(router.gameplay_module("cooking","global_audio_test"),"Enter a real cooking session")
	await create_timer(1).timeout
	var kitchen=current_scene
	check(global.available(),"Global recording pocket is present inside cooking")
	var device_view=global.open_recorder(); await settle()
	check(is_instance_valid(device_view) and device_view.live_screen!=null,"A keeps the real recorder during a Day 5 cooking session")
	device_view.put_away(); await settle()
	session.start("game")
	for token in ["lemon","bread","cheese"]: kitchen._toggle_token(token)
	kitchen._perform_primary_action()
	for prep in 3:
		kitchen._choose_prep_option(1)
		while not kitchen.prep_board.target_id.is_empty(): kitchen.prep_board.pressed.emit()
	for token in kitchen.selected_tokens:
		kitchen.value_slider.value=.65; kitchen._toggle_token(token); kitchen._perform_primary_action()
	await create_timer(1.3).timeout
	check(is_instance_valid(kitchen.fire_player) and kitchen.fire_player.playing,"Working pan produces real recordable fire sound")
	session.stop(); var kitchen_sample:Dictionary=session.last_sample.duplicate(true)
	check(kitchen_sample.mv_events.any(func(e):return str(e.kind)=="fire"),"Kitchen recording contains timed fire imagery")
	var model:=Arrangement.new(); model.add_sample(kitchen_sample,0,0)
	check(load("res://scripts/town_sound/data/SoundAtlas.gd").audible_kinds(model).has("fire"),"Real audible event types qualify for record-shop commissions")
	kitchen._return_or_cancel(); await create_timer(1).timeout
	check(SampleStore.new().list_samples().any(func(row):return str(row.id)==str(kitchen_sample.id)),"Leaving an unfinished activity preserves independent field recordings")
	check(not world.world_pool.busy_players.size()>12,"World sound polyphony stays bounded")
	if OS.get_cmdline_user_args().has("--manual"):
		root.mode=Window.MODE_WINDOWED; root.size=Vector2i(1280,720); root.position=Vector2i(90,90); root.title="Solmere - Global Sound QA"
		router.town_day(.1); await create_timer(.6).timeout
		global.open_recorder(); print("GLOBAL_SOUND_MANUAL_READY checks=",checks," failures=",failures); return
	world.set_active(false); print("GLOBAL_SOUND: ",checks," checks / ",failures," failures"); quit(failures)
