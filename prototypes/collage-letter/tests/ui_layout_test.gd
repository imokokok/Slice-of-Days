extends SceneTree
var failures:=0
func check(ok:bool, why:String)->void:
	if not ok: failures+=1;push_error(why)
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://Main.tscn").instantiate();root.add_child(game)
	while not game.ready_done:await process_frame
	game.smoke=true
	for index in 8:
		var tab=game.ui.get_node("Category_"+str(index))
		tab.pressed.emit()
		await process_frame
		check(game.material_ids().has(game.primary),"Category tab loads its material group")
		check(game.ui.get_node("Category_"+str(index)).tooltip_text.contains(str(game.material_ids().size())),"Tab exposes the current group count")
	game.set_tool("tape")
	var before: int=game.pieces_root.get_child_count()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=Vector2(600,350) if pressed else Vector2(760,390)
		game._unhandled_input(event)
	check(game.pieces_root.get_child_count()==before+1,"Queued drag retains event positions")
	check(game.selected.position.is_equal_approx(Vector2(680,370)),"Tape lands between press and release positions")
	game.take_letter(626,Vector2(650,350))
	for locale in ["zh","en"]:
		if game.L.language!=locale:game.switch_language()
		for dimensions in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1440,900)]:
			DisplayServer.window_set_size(dimensions)
			for tool in ["move","tape","pen","rect","free"]:
				game.set_tool(tool)
				await process_frame;await process_frame
				var buttons:Array=[]
				for node in game.ui.get_children():
					if node is Button:
						buttons.append(node)
						check(Rect2(Vector2.ZERO,Vector2(1440,900)).encloses(node.get_rect()),"Button stays inside canvas: "+node.text)
						if node.has_meta("layout_rect"):check(node.size.is_equal_approx(node.get_meta("layout_rect").size),"Actual button respects allocated height: "+node.text)
				for a in buttons.size():
					for b in range(a+1,buttons.size()):check(not buttons[a].get_rect().intersects(buttons[b].get_rect()),"Controls overlap: "+buttons[a].text+" / "+buttons[b].text)
				if dimensions==Vector2i(1280,800):
					await RenderingServer.frame_post_draw
					var folder:=OS.get_environment("COLLAGE_TEST_OUTPUT")
					if not folder.is_empty():root.get_texture().get_image().save_png(folder.path_join("ui-"+locale+"-"+tool+".png"))
	game.queue_free();await process_frame;await process_frame
	print("UI_LAYOUT_TEST: ","PASS" if failures==0 else "FAIL"," failures=",failures," locales=2 window_sizes=3 tools=5")
	quit(failures)
