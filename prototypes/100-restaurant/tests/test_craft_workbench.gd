extends SceneTree
var game
var checks := 0
var failures: Array[String] = []
var output := ""
var pointer := Vector2.ZERO
func _initialize() -> void:
	root.size=Vector2i(1440,851)
	Engine.max_fps=120
	if OS.get_cmdline_user_args().size()>0: output=OS.get_cmdline_user_args()[0]
	call_deferred("run")
func expect(value: bool, description: String) -> void:
	checks+=1
	if not value: failures.append(description)
func settle() -> void:
	for i in 4: await process_frame
func mouse(point: Vector2, pressed: bool, double := false) -> void:
	pointer=point
	var event=InputEventMouseButton.new()
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.double_click=double
	Input.parse_input_event(event)
func motion(point: Vector2) -> void:
	var event=InputEventMouseMotion.new()
	event.position=root.get_final_transform()*point
	event.global_position=event.position
	event.relative=root.get_final_transform().basis_xform(point-pointer)
	pointer=point
	event.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
func click(point: Vector2) -> void:
	mouse(point,true); await process_frame; mouse(point,false); await settle()
func key(code: int, unicode_value := 0, ctrl := false) -> void:
	var event=InputEventKey.new(); event.keycode=code; event.unicode=unicode_value; event.pressed=true; event.ctrl_pressed=ctrl; Input.parse_input_event(event)
func capture(suffix: String) -> void:
	if output.is_empty(): return
	await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+suffix+".png")
func run() -> void:
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://craft_%s/book.json"%Crypto.new().generate_random_bytes(16).hex_encode(),"display_name":"小满"})
	root.add_child(game); await settle(); game._start_shift(); game.world.audio.muted=true
	await settle()
	expect(game._order_paper.body.get_theme_font("font")==preload("res://modules/restaurant/ui/paper_ink.gd").font(),"order uses licensed handwriting font")
	var long_order={"name":"林阿姨","quote":"今天想要一碗暖暖的南瓜汤，清淡一点，不要太油。\n也想尝一点你拿手的味道。","mood_before":65,"preferences_known":true,"likes":["comfort"],"dislikes":["spicy"],"habit":"少盐，慢慢吃。"}
	game.session.current_customer=long_order
	await settle(); await capture("-order")
	await click(game._order_paper.get_global_rect().get_center())
	expect(game._modal_kind=="order_paper" and not game.world.controls_enabled,"physical order opens readable complete paper and pauses kitchen")
	expect(game._order_paper.full_text.contains(long_order.quote),"order retains full original request")
	await capture("-order-open")
	game._close_modal()
	game._last_dish={"ingredients":[{"id":"tomato","cut":true,"heat":8},{"id":"mushroom","cut":true,"heat":6}],"water_ml":120}
	game._show_recipe_editor(); await settle()
	var canvas=game._recipe_canvas
	expect(not canvas.has_content(),"new page is empty")
	expect(game.modal_panel.get_global_rect().end.y<=946,"workbench fits game viewport")
	expect(game._title_input.get_global_rect().position.x < canvas.get_global_rect().end.x,"title lives on paper")
	var before=game._last_dish.duplicate(true)
	var token=game.modal_body.find_child("UsedIngredient_tomato",true,false)
	var start=token.get_global_rect().get_center()
	var target=canvas.global_position+Vector2(205,207)
	mouse(start,true); await process_frame
	for p in [start+Vector2(18,0),start+Vector2(35,-15)]: motion(p); await process_frame
	motion(target); mouse(target,false); await settle()
	expect(canvas.stickers.size()==1,"real drag from ingredient tray creates exactly one editable layer")
	if canvas.stickers.size()>0:
		expect(canvas.stickers[0].id=="tomato" and canvas.stickers[0].cut,"drag keeps actual ingredient identity and cooking state")
		if DisplayServer.get_name()=="headless":
			expect(canvas._pixel(canvas.stickers[0].position).distance_to(Vector2(205,207))<10,"native material drop lands at pointer release")
		else:
			# Windows native drag resolves drop coordinates from the OS pointer, not
			# injected event coordinates. Never warp the user's pointer for a test.
			# Headless above exercises the gesture; GPU verifies the production drop
			# endpoint with explicit local coordinates for deterministic visual proof.
			canvas.undo()
			var payload: Dictionary=token.payload.duplicate(); payload.source="kitchen-collage"
			canvas._drop_data(Vector2(205,207),payload)
			expect(canvas._pixel(canvas.stickers[0].position).distance_to(Vector2(205,207))<0.1,"production drop endpoint maps explicit paper coordinates on GPU")
	expect(game._last_dish==before,"paper collage does not consume actual cooking ingredients")
	canvas.place_material({"type":"sticker","kind":"tape"},Vector2(230,190))
	canvas.place_material({"type":"ingredient","definition":game._definition("mushroom")},Vector2(380,232))
	canvas.mode="write"
	await click(canvas.global_position+Vector2(468,131))
	expect(canvas._text_edit_index>=0,"write tool opens native input at clicked paper position")
	if canvas._text_edit_index>=0:
		var editor=canvas._text_editor
		expect(editor.has_focus(),"paper input has keyboard focus")
		var first_line_position=editor.get_global_transform_with_canvas().origin
		for character in "番茄与蘑菇\n让这一餐暖一点":
			if character=="\n": key(KEY_ENTER)
			else: key(0,character.unicode_at(0))
			await process_frame
		await settle()
		expect(editor.text=="番茄与蘑菇\n让这一餐暖一点","native keyboard path keeps Chinese and newlines")
		expect(editor.get_global_transform_with_canvas().origin.distance_to(first_line_position)<0.1,"adding a line keeps existing handwriting anchored")
		var transform=editor.get_global_transform_with_canvas()
		var text=editor.text
		await capture("-writing")
		canvas.finish_text(); await settle()
		var visual=canvas._layer_nodes[canvas.selected_index].get_child(0)
		expect(visual.editor.text==text,"finished lettering matches input text")
		expect(visual.editor.get_global_transform_with_canvas().is_equal_approx(transform),"editing and resting text use identical position and scale")
		canvas.begin_text(Vector2.ZERO,canvas.selected_index)
		canvas._text_editor.insert_text_at_caret("，不要着急")
		await settle()
		expect(canvas._text_edit_index>=0 and canvas._text_editor.has_focus(),"previous editor focus event cannot end the new editor")
		canvas.finish_text(); canvas.undo()
		expect(canvas.stickers.back().text==text,"one canvas undo restores entire text edit gesture")
		canvas.redo()
		expect(canvas.stickers.back().text==text+"，不要着急","redo restores completed text edit")
		canvas.undo()
		canvas.mode="select"
		var text_index=canvas.stickers.size()-1
		var text_point=canvas.global_position+canvas._pixel(canvas.stickers[text_index].position)
		mouse(text_point,true,true); await process_frame; mouse(text_point,false); await settle()
		expect(canvas._text_edit_index==text_index,"double-click reopens text directly on paper")
		if canvas._text_edit_index>=0:
			canvas._text_editor.insert_text_at_caret("这段不要")
			key(KEY_ESCAPE); await settle()
			expect(canvas._text_edit_index<0 and canvas.stickers[text_index].text==text,"Escape cancels text change without closing workbench")
		var layer_count=canvas.stickers.size()
		canvas.begin_text(Vector2(90,70)); canvas.delete_selected(); await settle()
		expect(canvas.stickers.size()==layer_count,"deleting untouched blank text never removes another material")
		canvas.begin_text(Vector2.ZERO,text_index)
		canvas._text_editor.select_all(); key(KEY_BACKSPACE); await settle(); canvas.finish_text()
		expect(canvas.stickers.size()==layer_count-1,"erasing all native text removes the empty layer")
		canvas.undo()
		expect(canvas.stickers.back().text==text,"undo restores a fully erased text layer")
	canvas.mode="draw"; canvas.brush_width=3; canvas.brush_kind="pencil"
	var origin=canvas.global_position+Vector2(445,285)
	mouse(origin,true); await process_frame
	for offset in [Vector2(18,-12),Vector2(35,-8),Vector2(52,9),Vector2(75,13)]: motion(origin+offset); await process_frame
	mouse(origin+Vector2(75,13),false); await settle()
	expect(canvas.strokes.size()==1 and canvas.strokes[0].points.size()>2,"paper takes an actual continuous pencil stroke")
	game._title_input.text="太阳落下之前的番茄汤"
	game._notes_input.text="小火慢煮，最后撒一点盐。\n给忙了一天的人，留一点热气。"
	var snapshot=canvas.export_data()
	expect(snapshot.strokes[0].brush=="pencil","authored stroke records its pencil medium")
	game._close_modal(); game._show_recipe_editor(); await settle()
	canvas=game._recipe_canvas
	expect(canvas.export_data()==snapshot and game._title_input.text=="太阳落下之前的番茄汤","putting paper away and reopening resumes unsaved layers and writing")
	expect(game.repository.load_recipes().is_empty(),"temporary draft does not publish or write a finished recipe")
	if DisplayServer.get_name()!="headless":
		# Photograph actual food with the production plating renderer, not a stock dish.
		game._close_modal()
		expect(game.world.spawn_ingredient(game._definition("tomato")),"photo fixture adds physical ingredient")
		game.world.drop_into_pan()
		for i in 100:
			await physics_frame
			if not game.session.dish.is_empty(): break
		game._show_plating(); await settle()
		game._plate_bodies(game.world._foods.get_children()); await settle()
		expect(game._plating_canvas._visuals.size()>0,"actual enrolled ingredient is present on the photographed plate")
		await game._photograph_plating()
		expect(not game._photo.is_empty() and game._photo_is_plating,"production renderer captures an actual dish photo")
		game._show_recipe_editor(); await settle(); canvas=game._recipe_canvas
		game._add_dish_photo(canvas); await settle()
		expect(canvas.stickers.back().kind=="photo" and not game._recipe_photo.is_empty(),"actual captured dish can join the existing paper")
		game._close_modal(); game._show_recipe_editor(); await settle(); canvas=game._recipe_canvas
		var photo_token=game.modal_body.find_child("RecordedDishPhoto",true,false)
		expect(photo_token!=null,"captured photo appears as a physical draggable material")
		if photo_token!=null:
			var count=canvas.stickers.size()
			var p=photo_token.get_global_rect().get_center()
			var destination=canvas.global_position+Vector2(165,342)
			mouse(p,true); await process_frame
			motion(p+Vector2(-32,0)); await process_frame
			motion(destination); mouse(destination,false); await settle()
			expect(canvas.stickers.size()==count+1 and canvas.stickers.back().kind=="photo","actual photo token drags onto paper exactly once")
			canvas.undo()
		canvas.stickers.back().position=[0.22,0.69]
		canvas._layout_layers()
		snapshot=canvas.export_data()
	canvas.selected_index=-1; canvas.mode="select"; await settle(); await capture("-desk")
	game._save_recipe(); await settle()
	var saved=game.repository.load_recipes()
	expect(saved.size()==1,"handmade page saves one recipe")
	if saved.size()==1:
		expect(JSON.stringify(saved[0].poster)==JSON.stringify(snapshot),"save preserves editable ink and collage data")
		game._show_recipe_editor(saved[0]); await settle()
		expect(game._title_input.text=="太阳落下之前的番茄汤","paper title round-trips")
		expect(game._recipe_canvas.stickers.size()==snapshot.stickers.size(),"reopen retains all individual layers")
		game._view_recipe(saved[0]); await settle(); await capture("-reader")
		var readonly=game._recipe_stand.page._collage
		expect(readonly.export_data()==snapshot and not readonly.editable,"displayed recipe uses the exact same editable paper data")
		game._show_recipe_editor(saved[0]); await settle()
		game._title_input.text="尚未收进书的修改"
		game._close_modal(); game._show_recipe_editor(); await settle()
		expect(game._title_input.text.is_empty() and not game._recipe_canvas.has_content(),"another recipe draft never leaks into a new paper")
		game._close_modal(); game._show_recipe_editor(saved[0]); await settle()
		expect(game._title_input.text=="尚未收进书的修改","existing-recipe draft remains attached to its own id")
	# Written notes on the sheet count as DIY; a title alone still does not.
	var notes_book=preload("res://modules/restaurant/storage/recipe_repository.gd").new("user://craft_notes_%s/book.json"%Crypto.new().generate_random_bytes(16).hex_encode())
	var notes_record={"title":"只写一页做法","author":"小满","notes":"把番茄切小块，轻轻翻炒。","dish":{"ingredients":[]}}
	expect(notes_book.save_recipe(notes_record),"writing instructions directly on paper can save without decorative filler")
	expect(notes_book.load_recipes()[0].dish.ingredients.is_empty(),"written recipe does not invent a cooked meal")
	var invalid_record=notes_record.duplicate(true)
	invalid_record.poster={"version":1,"stickers":[],"strokes":[{"points":[[0.1,0.1],[0.2,0.2]],"width":0.003,"color":"345638","brush":"unknown-medium"}]}
	expect(not notes_book.save_recipe(invalid_record),"repository rejects unknown brush types")
	game._close_modal(); game.queue_free(); await settle()
	for failure in failures: push_error(failure)
	print("%s: immersive paper craft, %d checks"%["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
