extends SceneTree

var failures := 0
var w: Node2D

func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("WORKSHOP_CAPTURE_DIR")
	if not folder.is_empty(): root.get_texture().get_image().save_png(folder+"/"+label+".png")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--workshop-test") or DisplayServer.get_name()=="headless":
		push_error("Run with a rendering display and -- --workshop-test --fresh")
		quit(2);return
	w=load("res://Main.tscn").instantiate()
	root.add_child(w)
	for frame in 600:
		if w.ready_done: break
		await process_frame
	check(w.ready_done,"Workshop should load")
	check(w.material_images.size()>=33,"Existing varied material library must remain")
	check(w.sprites.size()==15,"All independent vector tools must load")
	await capture("workshop-desk")
	w.open_browser()
	w.browse(25)
	check(w.browser_index==25,"Browser should turn pages")
	await capture("workshop-materials")
	w.take_material()
	check(w.papers.get_child_count()==2,"Taking a material creates a real paper")
	w.pointer=w.active.position
	w._press()
	var release:=InputEventMouseButton.new()
	release.position=Vector2(1450,45);release.global_position=release.position
	release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
	root.push_input(release,true)
	check(w.dragged==null,"Releasing over a GUI button must end the paper drag")
	var original=w.active
	original.position=Vector2(200,650)
	w.use_tool("knife")
	check(w.mode==w.Mode.DESK,"Knife must not work without cutting mat")
	w.use_tool("scissors")
	await create_timer(0.35).timeout
	await capture("workshop-scissors")
	w._split_focused(PackedVector2Array([Vector2(0,0),Vector2(150,0),Vector2(150,240),Vector2(0,240)]),"scissors")
	check(w.papers.get_child_count()==3,"Scissors must preserve both pieces")
	w.undo()
	check(w.papers.get_child_count()==2,"Undo restores the uncut paper")
	w.redo()
	check(w.papers.get_child_count()==3,"Redo restores both halves")
	w.select_paper(w.papers.get_child(1))
	w.use_tool("mat")
	w.active.position=Vector2(180,650)
	w.take_knife()
	check(w.mode==w.Mode.CUTTING_MAT,"Knife must wait until paper is physically placed on mat")
	w.dragged=w.active
	w.active.position=Vector2(760,687)
	w._release()
	w.take_knife()
	await create_timer(0.35).timeout
	var before_count:int=w.papers.get_child_count()
	w._split_focused(PackedVector2Array([Vector2(30,30),Vector2(90,30),Vector2(90,90),Vector2(30,90)]),"knife")
	check(w.papers.get_child_count()==before_count+1,"Closed knife cut creates cutout and holed remainder")
	var remainder=w.papers.get_child(w.papers.get_child_count()-1)
	check(remainder.image.get_pixel(50,50).a==0,"Remainder must contain a transparent hole")
	w.use_tool("tape")
	w.pointer=Vector2(700,550);w._press()
	w.pointer=Vector2(820,560);w.tape_end=w.pointer;w._release()
	var count_before_tape:int=w.papers.get_child_count()
	check(w.tape_pending,"Releasing must leave tape attached to roll")
	check(w.papers.get_child_count()==count_before_tape,"Tape must not become a piece before cutting")
	w.finish_tape()
	check(w.active.paper_kind=="tape","Scissors must produce a movable tape object")
	w.use_tool("pen")
	w.pointer=w.main_paper.position+Vector2(170,90);w._press()
	w.previous_pointer=w.pointer;w.pointer+=Vector2(30,15)
	w._motion(InputEventMouseMotion.new());w._release()
	check(not w.main_paper.drawing_layer.is_empty(),"Pen must draw on real letter layer")
	w.return_desk()
	w.use_tool("typewriter")
	var key:=InputEventKey.new()
	key.keycode=KEY_H;key.unicode=72;key.pressed=true
	w._unhandled_input(key)
	w._advance_typewriter(0.1)
	check(w.typed_text=="H","Physical keyboard should type")
	check(w.papers.get_child_count()==count_before_tape+1,"Typing must not alter desk objects")
	w.typed_text="Good words find a way.\nSee you by the sea."
	w.type_ink.queue_redraw()
	await capture("workshop-typewriter")
	await w.save_typed_paper()
	check(w.active.paper_kind=="typed" and w.active.is_cuttable,"Typewriter output must become cuttable paper")
	w.active.position=w.main_paper.position
	w.active.scale=Vector2.ONE*0.7
	await capture("workshop-collage")
	await w.begin_folding()
	check(w.mode==w.Mode.FOLDING,"Completed collage should start physical folding")
	check(w.letter_preview.get_size()==Vector2(500,290),"Capture must exclude desk and UI")
	await capture("workshop-folding")
	for i in 2:
		w.fold_drag=true;w.fold_amount=0.8;w._release()
	check(w.mode==w.Mode.ENVELOPE,"Two folds should form trifold letter")
	w.packing_drag="letter";w.pointer=Vector2(1000,450);w._release()
	check(w.envelope_inserted,"Folded letter should fit envelope")
	w.packing_drag="flap";w.envelope_flap=0.9;w._release()
	check(w.mode==w.Mode.WAX_SEALING,"Closed envelope requires wax")
	w.send_letter()
	check(w.stage!="END","Unsealed letter must not send")
	w.wax_drag="match";w.match_lit=true;w.pointer=Vector2(509,382);w._process_wax(0.6)
	check(w.candle_lit and w.wax_step==1,"Burning match lights wick")
	w.wax_drag="spoon";w.pointer=Vector2(390,330);w._wax_release()
	check(w.spoon_filled and w.wax_step==2,"Spoon collects pellets")
	w.wax_drag="spoon";w.pointer=Vector2(509,350)
	w._process_wax(3)
	check(w.wax_step==2,"Wax cannot melt instantly")
	w._process_wax(3)
	check(w.wax_step==3,"Wax should melt after six seconds")
	w.pointer=Vector2(1000,455);w._process_wax(2)
	check(w.wax_step==4,"Molten wax forms pool")
	w.wax_drag="stamp";w.pointer=Vector2(1000,477);w._process_wax(1.1);w._wax_release()
	check(w.stamp_imprint and w.wax_step==5,"One second stamp press leaves mark")
	w._process_wax(2.6)
	check(w.wax_step==6,"Wax must cool before sending")
	await capture("workshop-wax")
	var state:Dictionary=w.snapshot()
	w.restore_snapshot(state)
	check(w.wax_step==6 and w.letter_preview!=null,"Draft reload preserves completed seal and artwork")
	w.send_letter()
	check(w.stage=="END","Sealed NPC letter should send")
	w.return_desk()
	await w.begin_folding()
	check(not w.envelope_inserted and not w.candle_lit and not w.spoon_filled,"Refolding must start with a fresh envelope and sealing sequence")
	w.audio.shutdown()
	w.queue_free()
	await process_frame
	print("LETTER_WORKSHOP_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
