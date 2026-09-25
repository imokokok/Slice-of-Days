extends SceneTree
## Real recording -> preview -> saved library -> reopen, plus mail and folio routes.
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle(): await process_frame; await process_frame; await create_timer(.3).timeout
func run():
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var gs=root.get_node("GameState"); root.get_node("ChapterSystem").start_new_game(); gs.current_location="record_store"; gs.current_minute=660
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	var global=root.get_node("GlobalRecorder"); var session=root.get_node("RecordingSession")
	var screen=global.open_recorder(); await settle()
	var old_count: int=SampleStore.new().list_samples().size()
	check(not screen.record_button.disabled,"Recorder exposes a working record action")
	screen.record_button.pressed.emit(); root.get_node("WorldSound").play_detail(); await create_timer(1.7).timeout
	check(screen.recorder.capturing and screen.levels.size()>0,"Record action receives real audio frames")
	check(screen.live_screen.frames_seen>0 and screen.live_screen.energy>0,"Live picture reflects actual audio")
	check(screen.source_picker.disabled,"Recording locks source selection")
	screen.put_away(); await settle(); check(not is_instance_valid(global.view) and session.recorder.capturing,"Pocketing preserves the recording")
	global.stop_button.pressed.emit(); await settle()
	check(session.saved and session.playback.stream.get_length()>.2,"Stop saves an actual playable WAV")
	screen=global.open_recorder(); screen.play_button.pressed.emit(); await settle(); check(session.playback.playing,"Saved preview plays actual audio")
	screen.name_input.text="海风采样 · UI复查"; screen.rename_button.pressed.emit(); await settle()
	check(SampleStore.new().list_samples().size()==old_count+1,"Rename does not duplicate the recorded file")
	var item: Dictionary=SampleStore.new().list_samples().back(); check(not bool(item.missing),"Saved recording has a file")
	screen.put_away(); session.playback.stop(); await settle(); check(not global.focused(),"Recorder closes without leaving a modal behind")
	var shell=current_scene.get_node("GameplayShell")
	shell.open_paper("sound_library"); await settle()
	var browser=shell.overlay.find_children("*","Control",true,false).filter(func(n):return n.get_script()!=null and n.get_script().resource_path.ends_with("media_browser.gd"))[0]
	check(browser.entries.size()==old_count+1,"Sound collection uses the same saved recordings")
	browser._toggle_play(); await settle(); check(browser.player.playing,"Saved collection can play the recording")
	shell.overlay.close(); await settle()
	shell.open_paper("dossier"); await settle(); shell.overlay.find_child("ArchiveSection_days",true,false).pressed.emit(); await settle()
	check(shell.overlay.has_node("CarriedObjectFrame/AddCollageMaterial"),"Illustrated archive still opens the real collage material entry")
	shell.overlay.close(); await settle()
	var home=load("res://scripts/ui/components/household_panel.gd").new(); current_scene.add_child(home); await settle()
	check(home.find_child("EnterPrivateRoom",true,false)!=null,"Mailbox retains its real private-room entrance")
	var progress=home.find_children("*","Button",true,false).filter(func(n):return n.text=="查看申请进度")[0]
	progress.pressed.emit(); await settle()
	check(home.status.text.split("\n").size()==12,"Application progress keeps all twelve residents in the reading area")
	var scroll: ScrollContainer=home.status.get_parent(); scroll.scroll_vertical=100000; await settle()
	check(home.status.get_global_rect().end.y<=scroll.get_global_rect().end.y+2,"Long application content can be read through its last line")
	home.queue_free(); await settle()
	print("UI_REFERENCE_REVIEW: ",checks," checks, ",failures," failures"); quit(failures)
