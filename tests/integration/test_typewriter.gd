extends SceneTree

var failures:=0
var w: Node2D

func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("WORKSHOP_CAPTURE_DIR")
	if not folder.is_empty(): root.get_texture().get_image().save_png(folder+"/"+name+".png")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--workshop-test") or DisplayServer.get_name()=="headless":
		quit(2);return
	w=load("res://extensions/collage_letter/workshop/Workshop.tscn").instantiate()
	root.add_child(w)
	for i in 600:
		if w.ready_done: break
		await process_frame
	if not w.ready_done: check(false,"Workshop must load");quit(1);return
	w.set_process(false)
	w.use_tool("typewriter")
	w.focus_amount=1
	w._queue_type_text("Hello 海边")
	check(w.typed_text.is_empty(),"A burst must queue, not appear all at once")
	w._advance_typewriter(0)
	check(w.typed_text=="H","First strike must print exactly one character")
	await capture("typewriter-first-character")
	w._advance_typewriter(0.02)
	check(w.typed_text=="H","Characters need a visible interval")
	w._advance_typewriter(10)
	check(w.typed_text=="He","A slow frame must not flush the whole queue")
	while not w.type_queue.is_empty(): w._advance_typewriter(0.4)
	check(w.typed_text=="Hello 海边","Queued Chinese and English must retain their order")
	w._queue_type_text("\b\n再见")
	while not w.type_queue.is_empty(): w._advance_typewriter(0.4)
	check(w.typed_text=="Hello 海\n再见","Backspace and return must execute in queue order")
	var echo:=InputEventKey.new()
	echo.pressed=true;echo.echo=true;echo.keycode=KEY_H;echo.unicode=72
	w._type_key(echo)
	check(w.type_queue.is_empty(),"OS key echo must not duplicate a physical strike")
	var layout=w.TypeLayout.arrange("海边中文，Hello world!",w.mono)
	var right:=0.0
	for glyph in layout.glyphs:
		check(glyph.position.x>=right,"Fallback glyphs must not overlap")
		right=glyph.position.x+w.mono.get_string_size(glyph.text,HORIZONTAL_ALIGNMENT_LEFT,-1,w.TypeLayout.FONT_SIZE).x
	check(w._type_fits("一\n二\n三\n四\n五\n六\n七"),"Seven lines must fit")
	check(not w._type_fits("一\n二\n三\n四\n五\n六\n七\n八"),"Overflow must be refused before printing")
	w.typed_text=""
	w._queue_type_text("海风慢慢吹过窗边。\nGood words find a way.\n一封信，一个字。\nSpace  Backspace  Enter\n每个字都留在纸上。\n直到我们再次见面。\nSee you by the sea.")
	var complete_text:String=w._pending_type_text()
	check(w.snapshot().type_draft==complete_text,"Save must retain unprinted queued input")
	while not w.type_queue.is_empty(): w._advance_typewriter(0.4)
	w.type_key="";w.key_age=1
	await capture("typewriter-seven-lines")
	var live_ink:Image=w.type_viewport.get_texture().get_image()
	var used:=live_ink.get_used_rect()
	check(used.position.x>=24 and used.end.x<=437 and used.position.y>10 and used.end.y<285,"Ink must remain inside paper margins")
	w._queue_type_text("!")
	await w.save_typed_paper()
	check(w.type_save_requested and w.papers.get_child_count()==1,"SAVE must wait for remaining strikes")
	w._advance_typewriter(0.4)
	check(w.typed_text==complete_text+"!","Last queued character must be printed before extraction")
	await RenderingServer.frame_post_draw
	var final_ink:Image=w.type_viewport.get_texture().get_image()
	w._advance_typewriter(0.4)
	var deadline:=Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline:
		if not w.busy and w.mode==w.Mode.DESK: break
		await process_frame
	check(w.mode==w.Mode.DESK and w.active.paper_kind=="typed","Extraction must finish with a cuttable paper")
	var lost:=0
	for y in final_ink.get_height():
		for x in final_ink.get_width():
			var ink:Color=final_ink.get_pixel(x,y)
			if ink.a>0.7 and w.active.image.get_pixel(x,y).v>0.8: lost+=1
	check(lost==0,"Every preview ink pixel must survive on the extracted paper")
	var folder:=OS.get_environment("WORKSHOP_CAPTURE_DIR")
	if not folder.is_empty(): w.active.image.save_png(folder+"/typewriter-extracted-paper.png")
	w.audio.shutdown();w.queue_free()
	await process_frame
	print("TYPEWRITER_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
