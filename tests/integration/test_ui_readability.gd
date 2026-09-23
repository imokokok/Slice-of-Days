extends SceneTree
const Assets=preload("res://scripts/ui/production_assets.gd")
const Spectrum=preload("res://scripts/town_sound/audio/SignalSpectrum.gd")
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func settle() -> void:
	await process_frame; await process_frame; await create_timer(.26).timeout
func contrast(a: Color,b: Color) -> float:
	var x:=a.srgb_to_linear().get_luminance(); var y:=b.srgb_to_linear().get_luminance()
	return (maxf(x,y)+.05)/(minf(x,y)+.05)
func paper_color(style: StyleBox) -> Color:
	return style.modulate_color if style is StyleBoxTexture else style.bg_color
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.size=Vector2i(1280,720); root.content_scale_size=Vector2i(1600,900); root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var host:=Control.new(); root.add_child(host); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for variant in ["quiet","outlined","paper","tab","archive","goods","choice","pause","camera","guidance"]:
		var button=load("res://scripts/ui/components/solmere_button.gd").new()
		button.variant=variant; button.text="保存并返回"; button.size=Vector2(270,54); host.add_child(button); await settle()
		for selected in [false,true]:
			button.selected=selected
			for state in ["normal","hover","pressed","disabled"]:
				var ink: Color=button.get_theme_color("font_color" if state=="normal" else "font_"+state+"_color")
				var bg:=paper_color(button.get_theme_stylebox(state))
				check(ink.a==1 and bg.a==1 and contrast(ink,bg)>=4.5,"Readable %s/%s, selected=%s"%[variant,state,selected])
		button.queue_free(); await settle()
	var confirmed:=[0]
	var confirm=load("res://scripts/ui/components/confirm_sheet.gd").new()
	confirm.heading="保存这次在小镇留下的经历"; confirm.description="一段很长的说明，应该留在纸页中。".repeat(85)+"\n最后一行仍然能够读到。"
	host.add_child(confirm); confirm.accepted.connect(func():confirmed[0]+=1); await settle()
	var paper_rect: Rect2=confirm.paper.get_global_rect()
	check(paper_rect.encloses(confirm.body_scroll.get_global_rect()),"Long confirmation stays inside its paper")
	check(confirm.body_label.size.x<=confirm.body_scroll.size.x,"Long body wraps without horizontal overflow")
	check(confirm.body_label.size.y>confirm.body_scroll.size.y,"Long body remains present in scrollable content")
	confirm.body_scroll.scroll_vertical=100000; await settle()
	check(confirm.body_scroll.scroll_vertical>0 and confirm.body_label.get_global_rect().end.y<=confirm.body_scroll.get_global_rect().end.y+2,"Last confirmation line can be reached")
	var buttons=confirm.paper.get_children().filter(func(n):return n is Button)
	check(buttons.size()==2 and buttons.all(func(b):return paper_rect.encloses(b.get_global_rect()) and not b.get_global_rect().intersects(confirm.body_scroll.get_global_rect())),"Actions stay inside paper and below reading area")
	buttons[1].pressed.emit(); buttons[1].pressed.emit(); check(confirmed[0]==1,"Confirm commits once even on double activation")
	confirm.queue_free(); await settle()
	for caption in ["面包","已经空了的彩绘罐头","A little tin with a very long handwritten name"]:
		var item=load("res://scripts/ui/components/handmade_item.gd").new(); item.size=Vector2(176,132); item.item_id="bread"; item.caption=caption; host.add_child(item); await settle()
		check(item.caption_back.get_global_rect().encloses(item.label.get_global_rect()),"Product text stays on its solid label: "+caption)
		check(item.label.get_visible_line_count()<=2 and item.tooltip_text==caption,"Long product keeps readable two-line caption and complete accessible name")
		item.disabled=true; item.queue_redraw(); await settle()
		check(item.modulate.a==1 and item.label.get_theme_color("font_color").a==1,"Unavailable merchandise retains readable name")
		item.queue_free(); await settle()
	host.queue_free(); await settle()
	var gs=root.get_node("GameState"); root.get_node("ChapterSystem").start_new_game(); gs.switch_to_role("B",2,true); gs.current_location="night_market"; gs.current_minute=660
	change_scene_to_file("res://scenes/town_day.tscn"); await settle()
	var shell=current_scene.get_node("GameplayShell")
	shell.open_paper("notebook"); await settle()
	var close=shell.overlay.find_child("CloseCarriedObject",true,false)
	check(close!=null and contrast(close.get_theme_color("font_color"),paper_color(close.get_theme_stylebox("normal")))>=4.5,"Notebook close symbol contrasts with its paper")
	shell.overlay.close(); await settle(); shell.open_paper("day_schedule"); await settle()
	var planner=shell.overlay.find_child("DayFivePlanner",true,false)
	check(planner!=null and planner.get_children().any(func(n):return n is Label and n.text.contains("23:59")),"Early-day schedule provides visible home deadline")
	check(not planner.has_node("Choose_A") and not planner.has_node("Choose_B"),"Reading early schedule never unlocks role switching")
	shell.overlay.close(); await settle()
	# Street events and translated/long dialogue share a fixed reading area.
	current_scene._show_line("居民","这段话需要完整地读完，不能被底部的继续按钮盖住。".repeat(24)); await settle()
	var card=current_scene.event_panel; var bounds: Rect2=card.get_global_rect()
	check(bounds.encloses(card.body_scroll.get_global_rect()),"Event dialogue reading area stays inside its fixed backing")
	check(card.text_label.size.y>card.body_scroll.size.y,"Long event text remains available for scrolling")
	card.body_scroll.scroll_vertical=100000; await settle()
	check(card.text_label.get_global_rect().end.y<=card.body_scroll.get_global_rect().end.y+2,"Final line of a long event can be read")
	current_scene._show_line("居民","短句。"); await settle()
	check(card.size==bounds.size and card.body_scroll.scroll_vertical==0,"A short reply keeps the same frame and resets reading position")
	current_scene.event_overlay.hide(); await settle()
	var first:=FieldRecorder.new(); var second:=FieldRecorder.new(); var before:=AudioServer.bus_count
	root.add_child(first); root.add_child(second); await settle()
	var first_name:=first.microphone_bus; var second_name:=second.microphone_bus
	check(first_name!=second_name and AudioServer.bus_count==before+2,"Recorder instances own independent microphone buses")
	first.queue_free(); await settle()
	check(AudioServer.get_bus_index(first_name)==-1 and AudioServer.get_bus_index(second_name)>=0,"Closing one recorder cannot remove the other's bus")
	second.queue_free(); await settle(); check(AudioServer.bus_count==before,"Repeated recorder use releases owned buses")
	var wav:=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate=48000; wav.stereo=true
	var pcm:=PackedByteArray(); pcm.resize(4096)
	for i in 1024: pcm.encode_s16(i*4+2,int(sin(TAU*3873*i/48000.0)*16000))
	wav.data=pcm
	check(Spectrum.from_wav(wav,0)[4]>.5,"Right-channel audio also drives the saved-recording picture")
	check(Spectrum.from_wav(wav,-1)==Spectrum.from_wav(wav,0),"Negative seek is clamped to the beginning")
	check(Spectrum.from_wav(wav,INF)==PackedFloat32Array([0,0,0,0,0,0]),"Invalid seek cannot read outside saved audio")
	print("UI_READABILITY: ",checks," checks, ",failures," failures"); quit(failures)
