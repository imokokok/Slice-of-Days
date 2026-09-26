extends SceneTree
var failures:=0
func check(ok:bool, why:String)->void:
	if not ok:failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func capture(name:String)->void:
	await process_frame;await RenderingServer.frame_post_draw
	var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
	if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run()->void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=false;game.conversation_open=false;game.build_ui()
	var cord=game.desk.get_node("BlindCord")
	var down:=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
	cord.gui_input.emit(down)
	var origin:float=game.desk.blind_origin
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(1025,origin-150);game.desk._input(motion)
	check(is_zero_approx(game.blinds_open),"Pull cord closes slats")
	await capture("office-blind-closed")
	motion.position.y=origin+150;game.desk._input(motion)
	check(is_equal_approx(game.blinds_open,1.0),"Pull cord opens street and sea view")
	down.pressed=false;game.desk._input(down)
	game.blinds_open=0;game.load_game(true);game.smoke=true
	check(is_equal_approx(game.blinds_open,1.0),"Blind position persists after release")
	game.conversation_open=false;game.shelf_open=true;game.drawer_group="纸张";game.drawer_page=0;game.build_ui()
	await capture("material-book-open")
	game.desk.shelf.get_node("BookNext").pressed.emit()
	check(game.drawer_page==1,"Next leaf changes page")
	check(game.desk.shelf.has_node("TurningLeaf"),"Page leaf animation exists")
	check(game.audio.last_clip=="paper","Page turn uses paper recording")
	await create_timer(0.20).timeout
	var leaf=game.desk.shelf.get_node("TurningLeaf")
	check(leaf.progress>0.1 and leaf.progress<0.95,"Leaf is animated, not a static page swap")
	await capture("material-book-turn")
	await create_timer(0.40).timeout
	check(not game.desk.shelf.has_node("TurningLeaf"),"Leaf retires so the new material can be taken")
	game.desk.shelf.get_node("BookPrevious").pressed.emit();await create_timer(0.6).timeout
	check(game.drawer_page==0,"Previous leaf returns to the preceding materials")
	game.set_tool("write");await process_frame
	check(game.desk.writing.has_focus(),"Writing starts on the letter, with a live caret")
	game.audio.shutdown();game.queue_free();await process_frame
	print("OFFICE_BOOK_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures);quit(failures)
