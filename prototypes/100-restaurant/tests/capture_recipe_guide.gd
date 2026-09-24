extends SceneTree
var game
func _initialize() -> void:
	root.size = Vector2i(1600, 946)
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	game = preload("res://modules/restaurant/restaurant.tscn").instantiate()
	game.configure({"repository_path":"user://guide_capture_%s/book.json" % Time.get_ticks_usec()})
	root.add_child(game)
	await process_frame
	game.world.audio.muted = true
	game._show_cookbook()
	await capture("contents")
	game._view_recipe(game.RecipeMethod.starter())
	await capture("method")
	var scroll = game.modal_body.find_child("RecipeMethodScroll", true, false)
	scroll.scroll_vertical = 2000
	await capture("method-end")
	game._start_recipe_guide(game.RecipeMethod.starter())
	game._take_ingredient(game._definition("tomato"))
	game.world._held.position = game.world.cutting_board.rect().get_center()
	game.world.drop_held(false)
	game._update_recipe_guide()
	await capture("guide")
	var whole = game.world._foods.get_children()[0]
	var parts: Array = game.world.split_food(whole, Vector2.RIGHT, Vector2.INF, 4)
	await process_frame
	game.world._pickup(parts[0])
	game.world.begin_food_drag(parts[0].position)
	game.world._move_dragged_food(game.world.pan.point(Vector2(810, 560)))
	game.world._finish_food_drag()
	await create_timer(1.1).timeout
	game._take_ingredient(game._definition("noodles"))
	game.world.drop_into_pan()
	await create_timer(0.8).timeout
	game.world.pan.water_ml = 250
	game.world.pan.water_heat = 100
	game.session.water_ml = 250
	game.session.water_heat = 100
	game.session.set_heating(true)
	game.session.tick(20)
	game.world.set_dish(game.session.dish, game.session.ingredients)
	game._interact("plate")
	game._plate_bodies(game.world._foods.get_children())
	await game._photograph_plating()
	var photographed := {"id":"capture", "title":"第一次番茄面", "author":"主厨", "notes":"番茄切两片，和面一起慢慢煮。", "dish":game.session.plate(), "thumbnail":game._photo}
	game._view_recipe(photographed)
	await capture("actual-photo")
	game._settle()
	await capture("receipt")
	var long_recipe := {"title":"番茄面和主厨亲手写下的那些关于夏日午餐的小故事".repeat(3).left(60), "author":"主厨", "notes":"很长的手记。".repeat(200), "dish":{"ingredients":[]}}
	for i in range(48): long_recipe.dish.ingredients.append({"id":"tomato", "cut":true, "heat":6})
	game._view_recipe(long_recipe)
	await capture("long-title")
	root.size = Vector2i(1152, 681)
	root.content_scale_size = Vector2i(1600, 946)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game._view_recipe(game.RecipeMethod.starter())
	await capture("small-window")
	game.queue_free()
	await process_frame
	quit()
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "-" + label + ".png")
	print("CAPTURE ", label, " ", result)
