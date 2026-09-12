extends SceneTree
var game
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	root.size=Vector2i(1600,900)
	Engine.max_fps=120
	call_deferred("run")
func run() -> void:
	game=preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://workstation_%d/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game._start_shift()
	game.world.spawn_ingredient(game._definition("tomato"))
	var tomato: RigidBody2D=game.world._held
	game.world.chop_held()
	var parts: Array=game.world.split_food(tomato,Vector2.RIGHT,Vector2(1219,735),4)
	expect(parts.size()==2,"inline off-center cut creates physical pieces")
	var body: RigidBody2D=parts[0]
	expect(absf(parts[0].mass-parts[1].mass)>0.01,"off-center cut produces unequal mass")
	game.world._pickup(body)
	game.world.drop_into_pan()
	await create_timer(0.9).timeout
	expect(game.session.dish.size()==1,"cut piece enrolls once")
	game._show_plating()
	await process_frame
	await process_frame
	var canvas=game._plating_canvas
	expect(canvas._visuals.is_empty(),"opening plating does not automatically arrange food")
	canvas.add_to_plate(body)
	await process_frame
	var canvas_pos: Vector2=canvas.global_position
	var art_pos: Vector2=canvas._visuals[body.get_instance_id()].art.position
	mouse(canvas_pos+art_pos,true)
	await process_frame
	motion(canvas_pos+canvas.center()+Vector2(120,30))
	await process_frame
	mouse(Vector2(1490,110),false)
	await process_frame
	expect(not canvas.dragging and body.position.x>1120,"plating moves the real piece and mouseup outside stops dragging")
	expect(game.session.dish[0].has("plate_position"),"plate layout saved on actual dish entry")
	canvas.mode="sauce"
	mouse(canvas_pos+canvas.center()+Vector2(-130,70),true)
	await create_timer(0.1).timeout
	motion(canvas_pos+canvas.center()+Vector2(130,70))
	await create_timer(0.1).timeout
	mouse(Vector2(1490,120),false)
	var amount:float=game.session.garnishes[0].amount_ml if not game.session.garnishes.is_empty() else 0.0
	expect(amount>0 and game.session.presentation.get("strokes",[]).size()==1,"pointer drizzle creates measured edible sauce and a plate stroke")
	await create_timer(0.1).timeout
	expect(not canvas.drawing and game.world.audio.ui_dispense_mode.is_empty() and is_equal_approx(game.session.garnishes[0].amount_ml,amount),"release stops sauce quantity and looping sound")
	expect(game.session.plate().ingredients.size()==2,"dish snapshot includes actual garnish")
	var bounds:Rect2=game.modal_panel.get_global_rect()
	expect(bounds.end.y<=900 and bounds.end.x<=1600,"plating editor fits viewport")
	if DisplayServer.get_name()!="headless":
		await game._photograph_plating()
		var img:=Image.new()
		expect(img.load_png_from_buffer(Marshalls.base64_to_raw(game._photo))==OK and img.get_size()==Vector2i(640,357),"optional photograph is a valid plate-only PNG")
		img.save_png("res://../摆盘照片.png")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../厨房_放大摆盘.png")
	game._show_recipe_editor()
	await process_frame
	expect(game._recipe_canvas.stickers.is_empty() and game._recipe_canvas.strokes.is_empty(),"DIY paper remains blank after plating and photography")
	if DisplayServer.get_name()!="headless":
		await game._add_dish_photo(game._recipe_canvas)
		expect(game._recipe_canvas.stickers.size()==1,"player explicitly adds plate photograph to DIY recipe")
	game._title_input.text="放大摆盘测试"
	game._save_recipe()
	var stored: Array=game.repository.load_recipes()
	expect(stored.size()==1,"recipe including garnish and layout saves successfully: "+game.repository.last_error)
	if stored.size()==1:
		expect(stored[0].dish.presentation.strokes.size()==1 and stored[0].dish.ingredients[0].has("plate_position"),"saved recipe retains drizzle and placement")
		var reloaded=game.Repository.new(game.repository.storage_path).load_recipes()
		expect(reloaded.size()==1 and reloaded[0].dish.ingredients.size()==2,"fresh JSON reload retains food and garnish")
	game._close_modal()
	await process_frame
	expect(body.freeze and body.get_meta("plated"),"plated food remains fixed after closing modal")
	var relative: Vector2=body.position-game.world.plate.center
	var old_center: Vector2=game.world.plate.center
	mouse(old_center,true)
	motion(old_center+Vector2(-90,35))
	mouse(old_center+Vector2(-90,35),false)
	await physics_frame
	await process_frame
	expect(body.position.distance_to(game.world.plate.center+relative)<0.1,"dragging the real plate carries plated food without changing arrangement")
	expect(game.session.presentation.strokes.size()==1,"plate movement preserves edible drizzle")
	game.world.audio.muted=true
	await create_timer(0.16).timeout
	game.queue_free()
	await process_frame
	for f in failures: push_error(f)
	print("%s workstations %d checks" % ["PASS" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
func expect(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures.append(message)
func mouse(p:Vector2,down:bool)->void:
	var e:=InputEventMouseButton.new()
	e.position=root.get_final_transform()*p
	e.global_position=e.position
	e.button_index=MOUSE_BUTTON_LEFT
	e.pressed=down
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)
func motion(p:Vector2)->void:
	var e:=InputEventMouseMotion.new()
	e.position=root.get_final_transform()*p
	e.global_position=e.position
	e.button_mask=MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
