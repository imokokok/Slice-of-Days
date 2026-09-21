extends SceneTree
var failures := 0
var notices: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, why: String) -> void:
	if not value: failures+=1; push_error(why)
func settle() -> void:
	await process_frame
	await process_frame
func capture(tag: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://native_"+tag+".png")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	var state = root.get_node("GameState")
	var save = root.get_node("SaveManager")
	var guidance = root.get_node("GuidanceSystem")
	var residency = root.get_node("ResidencySystem")
	if OS.get_cmdline_user_args().has("--load-only"):
		check(save.load_game("user://native_ui_roundtrip.json"),"Load saved UI in a fresh process")
		var pieces: Array=residency.state().free_pages.day_1
		check(pieces.size()==2 and pieces[0].id!=pieces[1].id,"Distinct placed IDs survive process restart")
		check(pieces[0].rotation>0 and pieces[0].scale>1 and pieces[0].page=="day_1","Transform and page survive process restart")
		check(guidance.state().tracked_lead=="cici_record_store","Tracked lead survives process restart")
		check(residency.state().private_note=="明天继续听海","Private plan survives process restart")
		print("NATIVE UI RELOAD failures=",failures); quit(failures); return
	root.get_node("ChapterSystem").start_new_game("A")
	root.get_node("SceneRouter").town_day(.01)
	await create_timer(.7).timeout
	state.shared_state.typewriter=false
	var shell = current_scene.get_node("GameplayShell")
	guidance.refresh(); guidance.notification.connect(func(kind: String, message: String) -> void: notices.append([kind,message]))
	for day in [1,2,3]:
		state.current_day=day
		var objectives: Array=guidance.must_objectives()
		check(objectives.size()>=2 and objectives.size()<=3,"Day 1–3 have bounded real objectives")
		for row in objectives: check(not str(row.text).is_empty() and row.has("action"),"Objectives explain actionable next steps")
	state.current_day=1; guidance.refresh()
	var talk = load("res://scripts/ui/conversation_panel.gd").new(); talk.npc="wu_wu"; current_scene.add_child(talk)
	await settle(); talk._advance()
	check(is_instance_valid(talk.vendor_choices) and talk.vendor_choices.get_child_count()>=3,"Cici has real choices")
	talk.vendor_choices.get_child(1).pressed.emit()
	check(talk.text_label.text.contains("手放低"),"Touch choice produces its own dialogue branch")
	await capture("dialogue")
	for i in 12:
		if not is_instance_valid(talk) or talk.is_queued_for_deletion(): break
		talk._advance()
	await settle(); guidance.refresh()
	check(guidance.leads().any(func(row: Dictionary) -> bool: return row.id=="cici_record_store"),"Completed encounter creates a sourced actionable lead")
	check(notices.any(func(row: Array) -> bool: return row[0]=="HEARD"),"Real new lead creates transient feedback")
	guidance.track("cici_record_store")
	shell.open_paper("notebook"); await settle()
	var paper = shell.overlay
	check(paper.task_checks.size()==3,"Notebook shows live daily objectives")
	state.current_location="print_shop"; state.current_minute=660; root.get_node("SceneRouter").active_space_id="print_studio"
	residency.collect_packet()
	root.get_node("SceneRouter").active_space_id=""
	for id in ["cafe","produce_stall","print_shop"]: residency.visit(id)
	state.state_changed.emit(); await settle()
	check(paper.task_checks[0].button_pressed,"Checkbox updates from gameplay without reopening")
	await capture("notebook")
	paper.notebook_section="heard"; paper.build(); await capture("heard")
	paper.notebook_section="personal"; paper.build()
	var note: TextEdit=paper.body.find_child("PrivateNotebookText",true,false); note.text="明天继续听海"; note.text_changed.emit()
	paper.mode="map"; paper.build(); await settle()
	check(paper.map_board.get_child_count()==15,"Map consists of independent real location controls")
	var marker: Button=paper.map_board.get_node("Destination_record_store")
	check(marker.modulate.a==1 and marker.selected,"Tracked location is visible and selected")
	marker.pressed.emit(); check(paper.map_selected=="record_store","Map selection opens actual route details")
	await capture("map")
	paper.mode="dossier"; paper.archive_tab="overview"; paper.build()
	check(paper.body.find_children("ArchiveSection_*","Button",true,false).size()==6,"Six native archive section buttons")
	await capture("archive")
	paper.archive_tab="days"; paper.day=1; paper.build()
	paper.canvas.add_piece({"kind":"text","text":"海风吹过车站"},Vector2(210,130))
	paper.canvas.transform_selected("rotate_right"); paper.canvas.transform_selected("larger")
	paper.canvas.add_piece({"kind":"text","text":"明天去唱片店"},Vector2(610,200))
	check(paper.canvas.get_child_count()==2,"Placed pieces are independent native controls")
	var first_id: String=paper.canvas.pieces[0].id
	paper.canvas.select_id(first_id); paper.canvas.move_selected(Vector2(20,10))
	check(paper.canvas.pieces[0].x==230,"Keyboard movement changes saved coordinates")
	paper.day=2; paper.build(); check(paper.canvas.pieces.is_empty(),"Second day is independent")
	paper.day=1; paper.build(); check(paper.canvas.pieces[0].id==first_id,"Stable IDs across page switching")
	await capture("portfolio")
	paper.mode="pause"; paper.build(); check(paused,"Pause pauses the scene tree")
	await capture("pause")
	paper.mode="settings"; paper.build()
	var slider: HSlider=paper.body.find_child("master_volume",true,false); slider.value=37
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0),.37),"Master slider changes real bus immediately")
	root.get_node("SettingsSystem").load_settings(); check(root.get_node("SettingsSystem").master_volume()==37,"Audio setting is persisted")
	await capture("settings")
	root.get_node("SettingsSystem").set_master_volume(80)
	paper.close(); await settle(); check(not paused,"Closing menu resumes gameplay")
	# Ordinary repeated chat cannot earn a signature.
	var relationship=root.get_node("RelationshipSystem")
	for i in 5: relationship.record_encounter("grocery","chat_%d" % i)
	var recognition: Dictionary=relationship.request_confirmation("grocery")
	check(str(recognition.get("status",""))!="granted","Five greetings do not automatically grant recognition")
	if DisplayServer.get_name()!="headless": await media_checks(shell)
	check(save.save_game("user://native_ui_roundtrip.json"),"Persist UI through existing SaveManager")
	print("NATIVE GUIDANCE UI failures=",failures)
	quit(failures)
func media_checks(shell: Control) -> void:
	var state=root.get_node("GameState")
	var film=root.get_node("FilmSystem")
	state.current_location="cafe"; state.current_minute=660; state.money=2000
	film.notice_camera(); check(film.acquire_camera(false).ok,"Acquire real camera through existing film system")
	shell.open_tool("camera"); await settle()
	var camera=shell.tool
	await camera.enter_viewfinder()
	check(camera.shutter.visible,"Shutter is a real visible button")
	camera.shutter.pressed.emit(); await create_timer(.5).timeout
	var roll: Dictionary=film.active_roll()
	check(roll.exposures_used==1 and FileAccess.file_exists(str(roll.captures[0].capture_path)),"Shutter captures and persists the live scene")
	await capture("camera")
	camera.queue_free(); await settle()
	check(film.dropoff(str(roll.id),"rush").ok,"Existing film development remains functional")
	state.current_day=int(roll.ready_day); state.current_minute=int(roll.ready_minute)
	var pickup: Dictionary=await film.pickup(str(roll.id)); check(pickup.ok,"Actual developed photos enter gallery")
	shell.open_paper("gallery"); await settle()
	var browser=shell.overlay.body.get_child(shell.overlay.body.get_child_count()-1)
	check(browser.entries.size()>0,"Gallery is generated from real captured photos")
	browser.show_entry(0); await capture("gallery")
	shell.overlay.close(); await settle()
	shell.open_tool("recorder"); await settle()
	var recorder=shell.tool
	recorder.toggle_recording(); await create_timer(.75).timeout
	check(recorder.recorder.capturing,"Recorder captures the actual TownWorld bus")
	recorder.mark_recording(); recorder.toggle_recording(); await settle()
	check(recorder.saved and recorder.pending_wav==null,"Captured audio saved as reusable sample")
	await capture("recorder")
	recorder.finish_for_exit(); await settle()
	shell.open_paper("sound_library"); await settle()
	browser=shell.overlay.body.get_child(shell.overlay.body.get_child_count()-1)
	check(browser.entries.size()>0,"Recording list comes from saved samples")
	browser.show_entry(0); await settle()
	var play: Button
	for child in browser.get_children():
		if child is Button and child.text=="播放 / 暂停": play=child
	check(play!=null,"Recording has a native play control")
	play.pressed.emit(); await create_timer(.15).timeout
	check(browser.player.playing and browser.progress.value>0,"Audio progress follows real playback")
	play.pressed.emit(); check(browser.player.stream_paused,"Play toggles pause")
	play.pressed.emit(); check(not browser.player.stream_paused,"Play resumes")
	await capture("audio_library")
	shell.overlay.close(); await settle()
