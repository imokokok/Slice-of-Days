extends SceneTree
## GPU evidence for the shared raw/cooked/browned/burnt surface renderer.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU capture requires a rendering display")
		quit(1)
		return
	root.size = Vector2i(1000, 540)
	root.content_scale_size = Vector2i(1000, 540)
	var background := ColorRect.new()
	background.color = Color("fff2d4")
	background.size = Vector2(1000, 540)
	root.add_child(background)
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://modules/restaurant/data/ingredients.json"))
	var ids := ["chicken", "broccoli", "noodles"]
	for row in range(3):
		var definition: Dictionary = {}
		for item in catalog:
			if item.id == ids[row]: definition = item
		for column in range(4):
			var art = preload("res://modules/restaurant/assets/food_art.gd").new()
			art.definition = definition
			art.heat = [0.0, 6.0, 14.0, 32.0][column]
			art.softness = 0.85 if row == 2 and column > 0 else 0.0
			art.position = Vector2(135 + column * 240, 115 + row * 165)
			art.scale = Vector2.ONE * 1.7
			root.add_child(art)
	for column in range(4):
		var label := Label.new()
		label.text = ["RAW", "COOKED", "BROWNED", "BURNT"][column]
		label.position = Vector2(88 + column * 240, 18)
		label.add_theme_color_override("font_color", Color("46392e"))
		root.add_child(label)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var args := OS.get_cmdline_user_args()
	var result := image.save_png(args[0] if not args.is_empty() else "user://cooking_states.png")
	var changed := true
	for row in range(3):
		for column in range(3):
			var a := image.get_region(Rect2i(85 + column * 240, 65 + row * 165, 100, 100)).get_data()
			var b := image.get_region(Rect2i(85 + (column + 1) * 240, 65 + row * 165, 100, 100)).get_data()
			changed = changed and a != b
	print("%s: GPU cooking states, 9 adjacent state comparisons" % ["PASS" if changed and result == OK else "FAIL"])
	quit(0 if changed and result == OK else 1)
