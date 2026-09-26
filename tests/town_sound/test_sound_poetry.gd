extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void: call_deferred("run")
func check(ok:bool,words:String) -> void:
	checks+=1; print("PASS " if ok else "FAIL ",words)
	if not ok: failures+=1; push_error(words)
func tone() -> AudioStreamWAV:
	var wav:=AudioStreamWAV.new(); wav.mix_rate=22050; wav.format=AudioStreamWAV.FORMAT_16_BITS
	var data:=PackedByteArray(); data.resize(22050*4)
	for i in 44100: data.encode_s16(i*2,int(5000*sin(i*TAU*200/22050.0)+1700*sin(i*TAU*1700/22050.0)))
	wav.data=data; return wav
func picture(canvas:VisualCanvas,viewport:SubViewport) -> Image:
	canvas.queue_redraw(); await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func run() -> void:
	if not OS.get_cmdline_user_args().has("--isolated-save"): quit(2); return
	root.get_node("ChapterSystem").start_new_game()
	root.mode=Window.MODE_WINDOWED
	root.title="Town Sound - Poetry QA"
	var wav:=tone()
	var viewport:=SubViewport.new(); viewport.size=Vector2i(384,216); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var canvas:=VisualCanvas.new(); canvas.size=Vector2(384,216); viewport.add_child(canvas); canvas.configure(wav,"像素",77); canvas.time=.5
	var gallery:=Image.create(384*5,246*2,false,Image.FORMAT_RGBA8); gallery.fill(Color("e8dfc8"))
	var seen:Array=[]
	for i in 10:
		canvas.force_kind=load("res://scripts/town_sound/data/SoundAtlas.gd").KINDS[i]
		var frame:Image=await picture(canvas,viewport)
		var hash:=frame.get_data().hex_encode().sha256_text()
		check(not seen.has(hash),"Distinct composition for "+canvas.force_kind); seen.append(hash)
		gallery.blit_rect(frame,Rect2i(0,0,384,216),Vector2i((i%5)*384,(i/5)*246))
	canvas.force_kind="wind"; var first:Image=await picture(canvas,viewport)
	canvas.time=1.4; var second:Image=await picture(canvas,viewport)
	check(first.get_data()!=second.get_data(),"Real playback time animates the picture")
	canvas.time=.5; var seek_back:Image=await picture(canvas,viewport)
	check(first.get_data()==seek_back.get_data(),"Seeking back reproduces the same frame exactly")
	canvas.configure(wav,"像素",94); canvas.time=.5
	var changed_seed:Image=await picture(canvas,viewport)
	check(first.get_data()!=changed_seed.get_data(),"Different recordings get different compositions")
	var silent:=tone(); var zeros:=silent.data; zeros.fill(0); silent.data=zeros
	canvas.configure(silent,"像素",77); canvas.time=.5
	var rest:Image=await picture(canvas,viewport); canvas.time=1.4
	check(rest.get_data()==(await picture(canvas,viewport)).get_data(),"Silence rests without fake sound-triggered motion")
	var stereo:=AudioStreamWAV.new(); stereo.mix_rate=wav.mix_rate; stereo.format=wav.format; stereo.stereo=true
	var stereo_data:=PackedByteArray(); stereo_data.resize(wav.data.size()*2)
	for i in wav.data.size()/2:
		var value:=wav.data.decode_s16(i*2); stereo_data.encode_s16(i*4,value); stereo_data.encode_s16(i*4+2,value)
	stereo.data=stereo_data
	var analyzer=load("res://scripts/town_sound/audio/SignalSpectrum.gd")
	check(analyzer.envelope(wav.data,22050,.5)==analyzer.envelope(stereo.data,22050,.5,true),"Mono and equivalent stereo use the same envelope")
	var model:=Arrangement.new(); var pcm:=PackedFloat32Array()
	for i in wav.data.size()/2: pcm.append(wav.data.decode_s16(i*2)/32768.0)
	model.cache["poetry"]={"pcm":pcm,"rate":22050}
	model.add_sample({"id":"poetry","name":"风过树林","duration":2.0,"sound_kind":"wind","mv_seed":77,"mv_events":[{"time":1.0,"kind":"bird"}]},0,0)
	canvas.model=model; canvas.configure(wav,"像素",902); canvas.time=1.2
	check(canvas.visual_context().seed==77 and canvas.visual_context().kind=="bird","Arrangement preserves recording seed and timed sound events")
	model.remove_range(.3,.8,0); canvas.time=1.2
	check(is_equal_approx(canvas.visual_context().time,1.2),"Cutting the middle preserves source picture time")
	model.clips[1].speed=2.0; model.clips[1].length=.6; canvas.time=.95
	check(is_equal_approx(canvas.visual_context().time,1.1) and canvas.visual_context().kind=="bird","Speed changes picture time and event timing with the audio")
	model.add_sample({"id":"poetry","name":"安静的另一层","duration":2.0,"sound_kind":"fire","mv_seed":22},1,0); model.clips[-1].volume=0
	check(canvas.visual_context().seed==77,"A zero-volume layer cannot replace the audible picture")
	model.clips.resize(1)
	check(load("res://scripts/town_sound/data/SoundAtlas.gd").audible_kinds(model)==["wind"],"A cut-away event cannot falsely complete a shop commission")
	DirAccess.make_dir_recursive_absolute("user://tests/sound_poetry")
	gallery.save_png("user://tests/sound_poetry/ten-sound-compositions.png")
	viewport.queue_free()
	root.get_node("GameState").current_location="record_store"
	var shop=load("res://scripts/town_sound/record_shop/RecordShop.gd").new(); root.add_child(shop)
	for width in [1600,1280,1024]:
		root.size=Vector2i(width,720); await process_frame; await process_frame; await process_frame
		check(shop.body.get_global_rect().end.x<=root.get_visible_rect().end.x+1,"Shop content fits "+str(width)+" px without horizontal clipping")
	print("SOUND_POETRY: ",checks," checks / ",failures," failures")
	if OS.get_cmdline_user_args().has("--manual"):
		root.size=Vector2i(1280,720); root.position=Vector2i(100,100); return
	shop.queue_free(); await process_frame; quit(failures)
