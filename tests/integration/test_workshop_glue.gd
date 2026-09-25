extends SceneTree

var failures := 0
var w: Node2D
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)
func _initialize() -> void: call_deferred("run")

func mouse(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
	root.push_input(e,true)
func move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position=at;e.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(e,true)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--workshop-test"): quit(2);return
	w=load("res://extensions/collage_letter/workshop/Workshop.tscn").instantiate()
	root.add_child(w)
	while not w.ready_done: await process_frame
	check(w.materials.size()==67,"All 67 curated assets must render")
	var ids: Dictionary={}
	for material in w.materials:
		check(not ids.has(material.title),"No duplicate material titles")
		ids[material.title]=true
	var paper=w.create_paper(w._blank_paper(Vector2i(220,140)),Vector2(765,670),"背胶试纸")
	w.select_paper(paper)
	w.press_active()
	check(not paper.attached,"Unglued paper cannot attach")
	w.use_tool("glue")
	check(paper.flipped and w.mode==w.Mode.GLUE,"Glue must expose the actual back of selected paper")
	for y in [635,667,699]:
		mouse(Vector2(690,y),true)
		for x in range(700,846,12): move(Vector2(x,y))
		mouse(Vector2(846,y),false)
	check(paper.glue_coverage()>0.4,"Mouse strokes must coat substantial back area")
	check(paper.image.get_pixel(100,60).g>0.8,"Back glue must not alter the artwork on front")
	await process_frame
	await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("WORKSHOP_CAPTURE_DIR")
	if not folder.is_empty(): root.get_texture().get_image().save_png(folder+"/office-glue-back.png")
	var coating: float=paper.glue_coverage()
	w.flip_active();w.press_active()
	check(paper.attached and not paper.flipped,"Coated face-up paper must attach on the letter")
	mouse(paper.position,true);move(paper.position+Vector2(60,0));mouse(paper.position,false)
	check(paper.position==Vector2(765,670) and w.dragged==null,"Attached paper must resist dragging")
	var state: Dictionary=w.snapshot()
	w.restore_snapshot(state)
	paper=w.papers.get_child(1);w.select_paper(paper)
	check(paper.attached and is_equal_approx(paper.glue_coverage(),coating),"Save roundtrip must retain coating and attachment")
	w.press_active()
	check(not paper.attached and paper.glue_coverage()==0,"Peeling must detach and consume the adhesive")
	w.undo();paper=w.papers.get_child(1)
	check(paper.attached and paper.glue_coverage()>0.4,"Undo must restore the adhesive and attachment")
	w.redo();paper=w.papers.get_child(1)
	check(not paper.attached and paper.glue_coverage()==0,"Redo must peel again")
	w.select_paper(paper);w.use_tool("glue")
	# A captured release over a GUI control must never keep spreading glue.
	mouse(paper.position,true);move(Vector2(1500,45));mouse(Vector2(1500,45),false)
	check(w.ink_target==null,"Release over settings must end a glue stroke")
	w.return_desk()
	for id in ["pen","pencil","marker"]:
		w.use_tool(id);check(w.tool==id,"Each pen must select its own profile");w.return_desk()
	check(w.audio.pool.size()==10,"Audio voice count must be bounded")
	w.audio.shutdown();w.queue_free();await process_frame
	print("WORKSHOP_GLUE_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
