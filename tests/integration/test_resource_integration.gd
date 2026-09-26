extends SceneTree
const Assets=preload("res://scripts/ui/production_assets.gd")
var Motion
const Spectrum=preload("res://scripts/town_sound/audio/SignalSpectrum.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle() -> void: await process_frame; await process_frame
func tone(frequency: float, seconds:=.6) -> AudioStreamWAV:
	var wav:=AudioStreamWAV.new(); wav.mix_rate=48000; wav.format=AudioStreamWAV.FORMAT_16_BITS
	var data:=PackedByteArray(); data.resize(int(48000*seconds)*2)
	for i in data.size()/2: data.encode_s16(i*2,int(sin(TAU*frequency*i/48000.0)*12000))
	wav.data=data; return wav
func strongest(values: PackedFloat32Array) -> int:
	var result:=0
	for i in values.size():
		if values[i]>values[result]: result=i
	return result
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	Motion=load("res://scripts/ui/solmere_motion.gd")
	check(Assets.manifest().assets.size()==84,"All 84 selected official assets installed")
	for key in Assets.manifest().assets:
		var item: Dictionary=Assets.manifest().assets[key]
		check(Assets.available(key),"Resource resolves: "+key)
		if item.category=="audio":
			var wav:=Assets.sound(key)
			check(wav!=null and wav.get_length()>.01 and wav.data.size()>100,"Real audio data: "+key)
			if item.loop: check(wav.loop_mode==AudioStreamWAV.LOOP_FORWARD and wav.loop_end>0,"Loop bounds: "+key)
		else:
			var tex:=Assets.texture(key)
			check(tex!=null and tex.get_width()>8 and tex.get_height()>8,"Imported artwork: "+key)
	check(Assets.paper() is StyleBoxTexture,"Paper uses installed art")
	check(Assets.icon("icon_check").get_width()==24,"UI icon has bounded layout size")
	var button:=Button.new(); button.size=Vector2(220,60); button.position=Vector2(70,90); root.add_child(button)
	var original:=button.get_rect()
	Motion.attach(button); Motion.press(button,true); await create_timer(.03).timeout; Motion.press(button,false)
	await create_timer(.15).timeout
	check(button.get_rect()==original and button.offset_transform_scale.is_equal_approx(Vector2.ONE),"Interrupted button press restores drawing and hit area")
	button.scale=Vector2(.8,.8); Motion.paper_open(button); await create_timer(.05).timeout; Motion.paper_open(button)
	await create_timer(.28).timeout
	check(button.scale.is_equal_approx(Vector2(.8,.8)) and is_equal_approx(button.modulate.a,1),"Reopening never shrinks a paper cumulatively")
	Motion.press(button,true,true); await create_timer(.03).timeout
	check(button.offset_transform_scale.is_equal_approx(Vector2.ONE),"Reduced motion avoids animated scale")
	button.queue_free(); await settle()
	var transient_ids: Array[int]=[]
	for i in 25:
		var transient:=Button.new(); root.add_child(transient); transient_ids.append(transient.get_instance_id()); transient.free()
	await settle()
	check(transient_ids.all(func(id: int): return not is_instance_id_valid(id)),"Motion binding does not retain disposed controls; logs must also be error-free")
	check(strongest(Spectrum.from_wav(tone(80),.1))==0,"Saved low tone drives low imagery")
	check(strongest(Spectrum.from_wav(tone(3873),.1))==4,"Saved high tone drives high imagery")
	check(Spectrum.from_wav(tone(0),.1)==PackedFloat32Array([0,0,0,0,0,0]),"Silence does not invent visual energy")
	check(Spectrum.from_wav(tone(80),20)==PackedFloat32Array([0,0,0,0,0,0]),"End of audio has no out-of-bounds read")
	var world=root.get_node("WorldSound"); var gs=root.get_node("GameState")
	world.set_active(true); world.set_indoor(false); gs.current_minute=660; world._refresh_nature()
	check(world.natural.stream==Assets.sound("ambience_day"),"Daytime selects actual outdoor recording")
	gs.current_minute=1080; world._refresh_nature(); check(world.natural.stream==Assets.sound("ambience_wind"),"Dusk selects wind")
	gs.current_minute=1260; world._refresh_nature(); check(world.natural.stream==Assets.sound("ambience_night"),"Night selects nocturnal ambience")
	world.set_weather("rain"); world.set_indoor(true)
	check(world.weather_player.stream==Assets.sound("ambience_indoor_rain"),"Indoor rain is a different recording")
	check(world.natural.stream==Assets.sound("ambience_room"),"Interior selects room tone")
	check(world.steps.bus=="TownWorldSoundEffects" and world.ui.bus=="SoundEffects","Foley and UI stay on distinct buses")
	world.set_active(false)
	if AudioServer.get_driver_name()!="Dummy":
		var recorder:=FieldRecorder.new(); root.add_child(recorder)
		var player:=AudioStreamPlayer.new(); player.bus="TownWorld"; player.stream=tone(250,2); root.add_child(player)
		var bus:=AudioServer.get_bus_index("TownWorld"); var effects:=AudioServer.get_bus_effect_count(bus)
		check(recorder.start("","game"),"Actual audio capture starts")
		player.play(); await create_timer(.7).timeout
		check(recorder.frame_count>100 and recorder.largest_peak>.05,"Real driver captures nonzero PCM")
		check(strongest(recorder.spectrum_levels())==1,"Live spectrum responds to actual 250 Hz output")
		recorder.stop(); player.stop()
		check(AudioServer.get_bus_effect_count(bus)==effects,"Capture and analyzer both detach")
		recorder.queue_free(); player.queue_free(); await settle()
	else: check(false,"Run with --audio-driver WASAPI to verify live spectrum")
	change_scene_to_file("res://scenes/main_menu.tscn"); await settle()
	var menu=current_scene
	var cover=menu.get_node("CoastalCover"); var navigation=menu.get_node("JourneyNavigation")
	check(cover.texture!=null and cover.mouse_filter==Control.MOUSE_FILTER_IGNORE and menu.get_children().find(cover)<menu.get_children().find(navigation),"Coastal illustration stays behind working menu controls")
	menu._show_credits(); await settle(); check(menu.modal_overlay.visible,"Real credits entry opens")
	menu._hide_modal(); check(not menu.modal_overlay.visible,"Credits dismisses cleanly")
	root.get_node("ChapterSystem").start_new_game(); gs.switch_to_role("B",2,true); gs.current_location="night_market"; gs.current_minute=660
	gs.inventory={"lemon":2,"bread":2,"cheese":2}
	check(root.get_node("GameplayModuleSystem").begin_session("cooking","resource_test"),"Existing kitchen route remains usable")
	change_scene_to_file("res://scenes/native_module_game.tscn"); await settle()
	var kitchen=current_scene
	check(is_instance_valid(kitchen.illustrated_pot),"Adapted pot is instantiated in real kitchen")
	for id in ["lemon","bread","cheese"]: kitchen._toggle_token(id)
	# Keep this walkthrough self-contained so it can test the exported PCK,
	# which deliberately excludes test fixtures.
	kitchen.primary_button.pressed.emit()
	for i in 3:
		kitchen.prep_option_buttons[0].pressed.emit()
		while not kitchen.prep_board.target_id.is_empty(): kitchen.prep_board.pressed.emit()
	for id in ["lemon","bread","cheese"]:
		kitchen.value_slider.value=.58
		kitchen.token_buttons[id].pressed.emit()
		kitchen.illustrated_pot.pressed.emit()
	kitchen.value_slider.value=.58
	for i in 2: kitchen.stir_buttons.fold.pressed.emit()
	kitchen.primary_button.pressed.emit()
	kitchen.seasoning_buttons.salt.pressed.emit()
	kitchen.primary_button.pressed.emit() # Finish tasting before choosing the actual plating.
	kitchen.plating_buttons.share.pressed.emit(); await settle()
	check(kitchen.stage_ready and kitchen.illustrated_pot.ingredients.size()==3,"Pot clicks add real ingredients through the complete cooking workflow")
	check(kitchen.illustrated_pot.stir_tween!=null,"Accepted cooking input animates the spoon")
	kitchen._complete_choice("careful_menu")
	check(kitchen.completed and gs.inventory.cheese==1,"Serving consumes inventory exactly once")
	check(root.get_node("SaveManager").save_game() and root.get_node("SaveManager").load_game() and gs.inventory.cheese==1,"Actual cooking result persists")
	print("RESOURCE_INTEGRATION: ",checks," checks, ",failures," failures")
	quit(failures)
