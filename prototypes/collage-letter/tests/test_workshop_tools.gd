extends SceneTree

var failures := 0
var w: Node2D

func check(ok: bool, message: String) -> void:
	if not ok: failures+=1;push_error(message)

func _initialize() -> void: call_deferred("run")

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	root.push_input(event,true)

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)

func sheet() -> Node2D:
	var image := Image.create(300,180,false,Image.FORMAT_RGBA8)
	image.fill(Color.BEIGE)
	var paper=w.create_paper(image,Vector2(205,685),"刻刀测试纸")
	w.select_paper(paper)
	return paper

func run() -> void:
	if not OS.get_cmdline_user_args().has("--workshop-test"): quit(2);return
	w=load("res://workshop/Workshop.tscn").instantiate()
	root.add_child(w)
	while not w.ready_done: await process_frame
	var mat_position: Vector2=w.mat_tool.position
	var mat_bounds: Rect2=w.mat_tool.bounds
	w.use_tool("mat")
	for i in 3: await process_frame
	check(w.mat_tool.is_visible_in_tree() and w.main_paper.visible,"Selecting mat must keep the desk visible")
	check(w.mat_tool.position==mat_position and w.mat_tool.bounds==mat_bounds,"Mat must stay in its original place")
	w.mat_tool.set_hover(true);w.mat_tool._process(1)
	check(w.mat_tool.lift==0,"Mat must not lift on hover")
	var paper=sheet()
	w.take_knife()
	check(w.mode==w.Mode.KNIFE_CUTTING,"Knife must accept paper on the actual desk mat")
	check(paper.position==Vector2(205,685) and paper.scale==Vector2.ONE,"Knife must not move or zoom the paper")
	var count: int=w.papers.get_child_count()
	# A fast edge-to-edge stroke has only press and release, both outside.
	mouse(Vector2(5,685),true)
	mouse(Vector2(430,685),false)
	check(w.papers.get_child_count()==count+1,"Fast outside-to-outside stroke must split the paper")
	check(w.mode==w.Mode.DESK,"A completed cut must return both pieces to the desk")
	paper=sheet();w.use_tool("mat");w.take_knife()
	count=w.papers.get_child_count()
	mouse(Vector2(105,635),true)
	for point in [Vector2(205,635),Vector2(205,705),Vector2(105,705)]: motion(point)
	mouse(Vector2(105,635),false)
	check(w.papers.get_child_count()==count+1,"Closed mouse stroke must create a cutout and remainder")
	check(w.active.image.get_pixel(90,70).a==0,"Closed cut must leave a real hole")
	var before: Vector2=w.scissors_tool.position
	var from: Vector2=w.scissors_tool.bounds.get_center()+before
	mouse(from,true);motion(from+Vector2(440,-350));mouse(from+Vector2(440,-350),false)
	check(w.scissors_tool.position.distance_to(before+Vector2(440,-350))<1,"Scissors must follow a drag and stay where dropped")
	check(w.dragged_tool==null,"Releasing scissors must end the drag")
	w.audio.shutdown();w.queue_free();await process_frame
	print("WORKSHOP_TOOLS_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(failures)
